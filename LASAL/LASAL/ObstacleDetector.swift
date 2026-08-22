//
//  ObstacleDetector.swift
//  LASAL
//
//  From https://github.com/AtharvSP04/LASAL
//  Created by Arthur Cheng on 22/8/2026.
//
//  Double-tap in the swipe UI starts / stops this session.
//  Intensity 1…5 maps onto `volume` for haptic strength.

import ARKit
import AVFoundation
import Combine
import Foundation
import UIKit

final class ObstacleDetector: NSObject, ARSessionDelegate, ObservableObject {
    private var heatmapCounter = 0
    private var gridCounter = 0
    private var silent: AVAudioPlayer?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    /// 0…1 haptic scale. Set from the Intensity page (n / 5).
    @Published var volume: Float = 0.6
    @Published var running = false
    @Published var hasSceneDepth = false
    @Published var distance: Double = 1.8
    @Published var heatmap: UIImage?

    /// When set (e.g. from the debug 3×3 grid), haptic + distance follow this cell
    /// instead of the centre. Cleared when leaving the debug overlay.
    @Published var focusCell: (row: Int, col: Int)? = nil

    let session = ARSession()

    // 3x3 grid in the USER's frame: grid[row][col]
    // row 0 = top, col 0 = left. Value is nearest distance in metres.
    // .greatestFiniteMagnitude means "no confident reading" in that cell.
    @Published var grid: [[Float]] = Array(
        repeating: Array(repeating: .greatestFiniteMagnitude, count: 3),
        count: 3
    )

    override init() {
        super.init()
        session.delegate = self
        prepareSilentAudio()
    }

    // MARK: - Public interface for the UI/UX team
    //
    // Read any cell safely. row and col are 0...2 in the user's frame:
    //   (0,0) = top-left      (0,2) = top-right
    //   (2,0) = bottom-left   (2,2) = bottom-right
    // Returns metres, or .greatestFiniteMagnitude if there's no reading
    // (or if you pass an out-of-range index).
    func distance(row: Int, col: Int) -> Float {
        guard (0..<3).contains(row), (0..<3).contains(col) else {
            return .greatestFiniteMagnitude
        }
        return grid[row][col]
    }

    func setVolumeFromIntensity(_ intensity: Int) {
        volume = max(0.2, min(1.0, Float(intensity) / 5.0))
    }

    func start() {
        startSession()
    }

    func stop() {
        session.pause()
        silent?.pause()
        running = false
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        endBackground()
    }

    func startSession() {
        guard ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) else {
            print("No LiDAR/scene depth")
            hasSceneDepth = false
            // Still run world tracking so the 3x3 grid can fall back later.
            return
        }

        let config = ARWorldTrackingConfiguration()
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            config.frameSemantics = .smoothedSceneDepth
            hasSceneDepth = true
        } else if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            config.frameSemantics = .sceneDepth
            hasSceneDepth = true
        }
        session.run(config)
        silent?.play()
        running = true
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        print("ObstacleDetector session has started")
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard let depth = frame.smoothedSceneDepth ?? frame.sceneDepth else { return }
        let depthMap = depth.depthMap

        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        let rowBytes = CVPixelBufferGetBytesPerRow(depthMap)
        guard let base = CVPixelBufferGetBaseAddress(depthMap) else { return }

        // 3x3, indexed [row][col] in the user's frame
        var g = Array(repeating: Array(repeating: Float.greatestFiniteMagnitude, count: 3), count: 3)

        for y in 0..<height {
            let rowPtr = base.advanced(by: y * rowBytes)
                .assumingMemoryBound(to: Float32.self)

            // Buffer is landscape while the phone is held portrait, so the
            // buffer's y axis maps to the user's left/right.
            let yBucket = y < height / 3 ? 0 : (y < 2 * height / 3 ? 1 : 2)
            let col = 2 - yBucket            // flip baked in: high y = user's LEFT (col 0)

            for x in 0..<width {
                let d = rowPtr[x]
                guard d > 0.1, d < 5.0 else { continue }

                // Buffer's x axis maps to top/bottom.
                let xBucket = x < width / 3 ? 0 : (x < 2 * width / 3 ? 1 : 2)
                let row = xBucket           // if top/bottom come out inverted, use: 2 - xBucket

                if d < g[row][col] { g[row][col] = d }
            }
        }

        heatmapCounter += 1
        if heatmapCounter % 20 == 0 {
            if let image = makeHeatmap(from: depthMap) {
                DispatchQueue.main.async {
                    self.heatmap = image
                }
            }
        }

        gridCounter += 1
        if gridCounter % 5 == 0 {           // publish ~12x/sec
            DispatchQueue.main.async {
                self.grid = g
                self.hasSceneDepth = true
                // Prefer the cell the user selected in the debug grid; otherwise centre.
                let depthToUse: Float
                if let focus = self.focusCell,
                   (0..<3).contains(focus.row), (0..<3).contains(focus.col) {
                    depthToUse = g[focus.row][focus.col]
                } else {
                    depthToUse = g[1][1]
                }
                if depthToUse != .greatestFiniteMagnitude {
                    self.distance = Double(depthToUse)
                }
                self.vibrationReaction(depth: depthToUse, volume: self.volume)
            }
        }
    }

    func enterBackground() {
        guard running else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "LASAL-sensing") { [weak self] in
                self?.endBackground()
            }
            self.silent?.play()
        }
    }

    func vibrationReaction(depth: Float, volume: Float = 1.0) {
        guard depth != Float.greatestFiniteMagnitude else { return }

        let clampedDepth = max(0.1, min(depth, 5.0))
        let rawIntensity = (5.0 - clampedDepth) / 5.0

        // 1. Check distance threshold FIRST (e.g., object must be within range)
        guard rawIntensity > 0.05 else { return }

        // 2. Apply volume scale SECOND, with a minimum floor (e.g., 0.01) so it still vibrates
        let scaledIntensity = max(0.01, rawIntensity * volume)

        triggerCustomHaptic(intensity: CGFloat(scaledIntensity))
    }

    func triggerCustomHaptic(intensity: CGFloat) {
        let safeIntensity = max(0.0, min(intensity, 1.0))
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred(intensity: safeIntensity)
    }

    func makeHeatmap(from depthMap: CVPixelBuffer,
                     near: Float = 0.2, far: Float = 5.0) -> UIImage? {
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        let width    = CVPixelBufferGetWidth(depthMap)
        let height   = CVPixelBufferGetHeight(depthMap)
        let rowBytes = CVPixelBufferGetBytesPerRow(depthMap)
        guard let base = CVPixelBufferGetBaseAddress(depthMap) else { return nil }

        var rgba = [UInt8](repeating: 0, count: width * height * 4)

        for y in 0..<height {
            let row = base.advanced(by: y * rowBytes)
                .assumingMemoryBound(to: Float32.self)
            for x in 0..<width {
                let d = row[x]
                var t = (d - near) / (far - near)
                if !t.isFinite { t = 1 }          // no reading → treat as far
                t = min(max(t, 0), 1)
                let (r, g, b) = heatColor(t)
                let i = (y * width + x) * 4
                rgba[i] = r; rgba[i + 1] = g; rgba[i + 2] = b; rgba[i + 3] = 255
            }
        }

        let cs = CGColorSpaceCreateDeviceRGB()
        let info = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let ctx = CGContext(data: &rgba, width: width, height: height,
                                  bitsPerComponent: 8, bytesPerRow: width * 4,
                                  space: cs, bitmapInfo: info),
              let cg = ctx.makeImage() else { return nil }
        return UIImage(cgImage: cg)
    }

    // t = 0 (near) → red, t = 1 (far) → blue
    func heatColor(_ t: Float) -> (UInt8, UInt8, UInt8) {
        hsvToRGB(h: t * 0.66, s: 1, v: 1)
    }

    func hsvToRGB(h: Float, s: Float, v: Float) -> (UInt8, UInt8, UInt8) {
        let i = Int(h * 6)
        let f = h * 6 - Float(i)
        let p = v * (1 - s), q = v * (1 - f * s), tt = v * (1 - (1 - f) * s)
        let (r, g, b): (Float, Float, Float)
        switch i % 6 {
        case 0: (r, g, b) = (v, tt, p)
        case 1: (r, g, b) = (q, v, p)
        case 2: (r, g, b) = (p, v, tt)
        case 3: (r, g, b) = (p, q, v)
        case 4: (r, g, b) = (tt, p, v)
        default: (r, g, b) = (v, p, q)
        }
        return (UInt8(r * 255), UInt8(g * 255), UInt8(b * 255))
    }

    private func endBackground() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.backgroundTask != .invalid {
                UIApplication.shared.endBackgroundTask(self.backgroundTask)
                self.backgroundTask = .invalid
            }
        }
    }

    private func prepareSilentAudio() {
        let hz = 44100
        let samples = [Int16](repeating: 0, count: hz)
        let pcm = samples.withUnsafeBufferPointer { Data(buffer: $0) }
        var wav = Data()
        wav.append(contentsOf: Array("RIFF".utf8))
        wav.append(contentsOf: UInt32(36 + pcm.count).le)
        wav.append(contentsOf: Array("WAVEfmt ".utf8))
        wav.append(contentsOf: UInt32(16).le)
        wav.append(contentsOf: UInt16(1).le)
        wav.append(contentsOf: UInt16(1).le)
        wav.append(contentsOf: UInt32(44100).le)
        wav.append(contentsOf: UInt32(88200).le)
        wav.append(contentsOf: UInt16(2).le)
        wav.append(contentsOf: UInt16(16).le)
        wav.append(contentsOf: Array("data".utf8))
        wav.append(contentsOf: UInt32(pcm.count).le)
        wav.append(pcm)
        silent = try? AVAudioPlayer(data: wav)
        silent?.numberOfLoops = -1
        silent?.volume = 0.0
        silent?.prepareToPlay()
    }
}

private extension UInt16 {
    var le: [UInt8] { [UInt8(self & 0xff), UInt8(self >> 8)] }
}

private extension UInt32 {
    var le: [UInt8] {
        [
            UInt8(self & 0xff),
            UInt8((self >> 8) & 0xff),
            UInt8((self >> 16) & 0xff),
            UInt8((self >> 24) & 0xff)
        ]
    }
}
