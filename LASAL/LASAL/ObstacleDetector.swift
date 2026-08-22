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
    private var frameCount = 0
    
    let session = ARSession()
    @Published var distances: (left: Float, center: Float, right: Float) = (.greatestFiniteMagnitude, .greatestFiniteMagnitude, .greatestFiniteMagnitude)
    @Published var heatmap: UIImage?
    
    override init()
    {
        super.init()
        session.delegate = self
        startSession()
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
        defer {CVPixelBufferUnlockBaseAddress(depthMap, .readOnly)}
        
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        let rowBytes = CVPixelBufferGetBytesPerRow(depthMap)
        guard let base = CVPixelBufferGetBaseAddress(depthMap) else {return}
        
        var nearest: [Float] = [.greatestFiniteMagnitude, .greatestFiniteMagnitude, .greatestFiniteMagnitude]
        
        // sample the middle horizontal band, spilt into 3 vertical zones
        
        for y in (height / 3)..<(2 * height / 3) {
            let row = base.advanced(by: y * rowBytes).assumingMemoryBound(to: Float32.self)
            for x in 0..<width {
                let d = row[x]
                guard d > 0.1, d < 5.0 else {continue} //skip if it's junk or out of range
                let zone = x < width / 3 ? 0 : (x < 2 * width / 3 ? 1 : 2)
                nearest[zone] = min(nearest[zone], d)
            }
        }
        
        reactToObstacles(left: nearest[0], center: nearest[1], right: nearest[2])
        
        
        heatmapCounter += 1
        if heatmapCounter % 20 == 0 {
            if let image = makeHeatmap(from: depthMap) {
                DispatchQueue.main.async {
                    self.heatmap = image
                }
            }
        }
        
        //Vibration of Phone
        vibrationReaction(center: nearest[1])
    }
    func vibrationReaction(center: Float){
        if center <= 1{
            triggerHaptic(style: .heavy)
        }
        if center >= 1 && center < 3 {
            triggerHaptic(style: .medium)
        }
        if center > 3 {
            triggerHaptic(style: .light)
        }
    }
    
    func triggerHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle) {
            let generator = UIImpactFeedbackGenerator(style: style)
            generator.prepare()
            generator.impactOccurred()
        }
    
    func reactToObstacles(left: Float, center: Float, right: Float) {
        frameCount += 1
        guard frameCount % 30 == 0 else {return}
        DispatchQueue.main.async {
            self.distances = (left,center,right)
        }
                
        
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

