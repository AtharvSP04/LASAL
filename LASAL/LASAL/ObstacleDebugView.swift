//
//  ObstacleDebugView.swift
//  LASAL
//
//  AtharvSP04/LASAL ContentView — heatmap + 3×3 depth grid.
//  Shown as the debug overlay (volume up + volume down for 2s).

import SwiftUI

struct ObstacleDebugView: View {
    @ObservedObject var detector: ObstacleDetector
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
        VStack(spacing: 20) {
            Text("LiDAR")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .tracking(3)
                .foregroundStyle(.secondary)

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
                    .frame(maxHeight: 200)
            } else {
                Text(detector.running ? "Starting…" : "Double tap to start")
                    .foregroundStyle(.secondary)
                    .frame(height: 160)
            }

            if let s = selected {
                Text("Cell (\(s.row), \(s.col)):  \(fmt(detector.distance(row: s.row, col: s.col)))")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .monospacedDigit()
            } else {
                Text("Tap a cell to inspect it")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: 6) {
                        ForEach(0..<3, id: \.self) { col in
                            let v = detector.grid[row][col]
                            Button {
                                selected = (row, col)
                                detector.focusCell = (row, col)
                            } label: {
                                Text(fmt(v))
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                    .frame(maxWidth: .infinity, minHeight: 64)
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

            Spacer(minLength: 0)
        }
        .padding()
        .padding(.top, 36)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.black.ignoresSafeArea())
        .foregroundStyle(.white)
        .onAppear {
            // Default to centre so haptic already matches the common case.
            if selected == nil {
                selected = (1, 1)
                detector.focusCell = (1, 1)
            } else if let s = selected {
                detector.focusCell = s
            }
        }
        .onDisappear {
            detector.focusCell = nil
        }
    }
}
