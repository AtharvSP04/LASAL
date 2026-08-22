//
//  LASALApp.swift
//  LASAL
//

import SwiftUI
import AVFoundation

@main
struct LASALApp: App {
    @StateObject private var store = AppStore()

    init() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.mixWithOthers, .duckOthers])
        try? session.setActive(true)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .persistentSystemOverlays(.hidden)
        }
    }
}
