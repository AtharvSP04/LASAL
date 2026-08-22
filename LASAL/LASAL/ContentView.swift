//
//  ContentView.swift
//  LASAL
//
//  Created by Atharv Singh Panwar on 22/8/2026.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var detector = ObstacleDetector()
    @State private var selected: (row: Int, col: Int)? = nil

    private func fmt(_ v: Float) -> String {
        v == .greatestFiniteMagnitude ? "—" : String(format: "%.2f m", v)
    }

    // near = red, far = green, no reading = grey
    private func color(for v: Float) -> Color {
        guard v != .greatestFiniteMagnitude else { return .gray.opacity(0.3) }
        let t = min(max((v - 0.2) / (5.0 - 0.2), 0), 1)
        return Color(hue: Double(t) * 0.33, saturation: 0.9, brightness: 0.9)
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
                    .frame(maxHeight: 220)
            } else {
                Text("Starting…").frame(height: 200)
            }

            // Selected-cell readout
            if let s = selected {
                Text("Cell (\(s.row), \(s.col)):  \(fmt(detector.distance(row: s.row, col: s.col)))")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .monospacedDigit()
            } else {
                Text("Tap a cell to inspect it")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Interactive 3x3 grid
            VStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: 6) {
                        ForEach(0..<3, id: \.self) { col in
                            let v = detector.grid[row][col]
                            Button {
                                selected = (row, col)
                            } label: {
                                Text(fmt(v))
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                    .frame(maxWidth: .infinity, minHeight: 72)
                                    .background(color(for: v))
                                    .foregroundStyle(.white)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(.white, lineWidth:
                                                selected?.row == row && selected?.col == col ? 3 : 0)
                                    )
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding()
    }
}
