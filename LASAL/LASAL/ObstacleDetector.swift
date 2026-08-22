//
//  ObstacleDetector.swift
//  LASAL
//
//  Created by Arthur Cheng on 22/8/2026.
//

import Foundation
import ARKit
import Combine
import UIKit

class ObstacleDetector: NSObject, ARSessionDelegate, ObservableObject
{
    private var heatmapCounter = 0
    private var gridCounter = 0
    @Published var volume = 0.5
    @Published var cellNumber = 1 //1 by default
    
    let session = ARSession()

    // 3x3 grid in the USER's frame: grid[row][col]
    // row 0 = top, col 0 = left. Value is nearest distance in metres.
    // .greatestFiniteMagnitude means "no confident reading" in that cell.
    @Published var grid: [[Float]] = Array(
        repeating: Array(repeating: .greatestFiniteMagnitude, count: 3),
        count: 3
    )

    @Published var heatmap: UIImage?

    override init()
    {
        super.init()
        session.delegate = self
        startSession()
    }

    // MARK: - Public interface for the UI/UX team
    //
    // Read any cell safely. row and col are 0...2 in the user's frame:
    //   (0,0) = top-left      (0,2) = top-right
    //   (2,0) = bottom-left   (2,2) = bottom-right
    // Returns metres, or .greatestFiniteMagnitude if there's no reading
    // (or if you pass an out-of-range index).
    func distance(row: Int, col: Int) -> Float
    {
        guard (0..<3).contains(row), (0..<3).contains(col) else {
            return .greatestFiniteMagnitude
        }
        return grid[row][col]
    }

    func startSession()
    {
        guard ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) else {
            print("No LiDAR/scene depth")
            return
        }

        let config = ARWorldTrackingConfiguration()
        config.frameSemantics = ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) ? .smoothedSceneDepth : .sceneDepth
        session.run(config)
        print("Session has started")
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame)
    {
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

            let yBucket = y < height / 3 ? 0 : (y < 2 * height / 3 ? 1 : 2)
            let col = 2 - yBucket

            for x in 0..<width {
                let d = rowPtr[x]
                guard d > 0.1, d < 5.0 else { continue }

                let xBucket = x < width / 3 ? 0 : (x < 2 * width / 3 ? 1 : 2)
                let row = xBucket

                if d < g[row][col] { g[row][col] = d }
            }
        }

        // Heatmap update (~3x/sec assuming 60fps)
        heatmapCounter += 1
        if heatmapCounter % 20 == 0 {
            if let image = makeHeatmap(from: depthMap) {
                DispatchQueue.main.async {
                    self.heatmap = image
                }
            }
        }

        // Grid & Vibration update (~12x/sec)
        gridCounter += 1
        if gridCounter % 5 == 0 {
            let selectedCell = getCell(cell: cellNumber, g)
            
            DispatchQueue.main.async {
                self.grid = g
                self.vibrationReaction(depth: selectedCell)
            }
        }
    }
    func getCell(cell: Int, _ g: [[Float]]) -> Float {
        switch cell {
        case 1: return g[0][0]
        case 2: return g[0][1]
        case 3: return g[0][2]
        case 4: return g[1][0]
        case 5: return g[1][1]
        case 6: return g[1][2]
        case 7: return g[2][0]
        case 8: return g[2][1]
        case 9: return g[2][2]
        default:
            return Float.greatestFiniteMagnitude
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
        // Ensure intensity remains strictly within 0.0 ... 1.0
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
                rgba[i] = r; rgba[i+1] = g; rgba[i+2] = b; rgba[i+3] = 255
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
        default:(r, g, b) = (v, p, q)
        }
        return (UInt8(r * 255), UInt8(g * 255), UInt8(b * 255))
    }
}
