//
//  ContentView.swift
//  LASAL
//
//  Created by Atharv Singh Panwar on 22/8/2026.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var detector = ObstacleDetector()

    private func fmt(_ v: Float) -> String {
        v == .greatestFiniteMagnitude ? "—" : String(format: "%.2f m", v)
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("Depth heatmap")
                .font(.headline)
                .foregroundStyle(.secondary)

            if let img = detector.heatmap {
                Image(uiImage: img)
                    .resizable()
                    .interpolation(.medium)
                    .aspectRatio(contentMode: .fit)
                    .rotationEffect(.degrees(90))
                    .cornerRadius(12)
            } else {
                Text("Starting…").frame(height: 200)
            }

            HStack(spacing: 24) {
                zone("LEFT",   detector.distances.left)
                zone("CENTER", detector.distances.center)
                zone("RIGHT",  detector.distances.right)
            }
        }
        .padding()
    }

    private func zone(_ label: String, _ value: Float) -> some View {
        VStack(spacing: 8) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(fmt(value))
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }
}
