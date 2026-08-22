import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject var store: AppStore
    @StateObject private var detector = ObstacleDetector()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                (store.panel == .intensity || store.panel == .language ? Color.white : Color.black)
                    .ignoresSafeArea()

                tabStack(size: geo.size)

                if store.panel == .intensity {
                    IntensityWheel()
                        .transition(.move(edge: .trailing))
                }
                if store.panel == .language {
                    LanguageWheel()
                        .transition(.move(edge: .trailing))
                }
                if store.panel == .debug {
                    ObstacleDebugView(detector: detector)
                }

                VolumeRocker(onChord: toggleDebug)
            }
            .gesture(swipe(size: geo.size))
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.52)
                    .onEnded { _ in
                        if store.panel == .debug {
                            Announcer.stop()
                            return
                        }
                        Announcer.page(store.tab, panel: store.panel, intensity: store.intensity, language: store.language, hold: true)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
            )
            .onTapGesture(count: 2) { toggleSensing() }
            .onChange(of: store.tab) { _, _ in announce() }
            .onChange(of: store.panel) { _, _ in announce() }
            .onChange(of: store.intensity) { _, n in
                detector.setVolumeFromIntensity(n)
            }
            .onAppear {
                detector.setVolumeFromIntensity(store.intensity)
                announce()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                if store.sensing { detector.enterBackground() }
            }
        }
        .environmentObject(store)
    }

    private func announce() {
        // Entering debug (or any silent panel) must cut off the previous page reading.
        if store.panel == .debug {
            Announcer.stop()
            return
        }
        Announcer.page(store.tab, panel: store.panel, intensity: store.intensity, language: store.language)
    }

    @ViewBuilder
    private func tabStack(size: CGSize) -> some View {
        Group {
            switch store.tab {
            case .disclaimer:
                DisclaimerView()
            case .intensity:
                HubView(title: label(.intensity), value: numberLabel(store.intensity), primary: hintPrimary, secondary: hintSecondary)
            case .language:
                HubView(title: label(.language), value: langLabel(store.language), primary: hintPrimary, secondary: hintSecondary)
            }
        }
        .foregroundStyle(store.panel == .intensity || store.panel == .language ? Color.black : Color.white)
    }

    private func swipe(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                if abs(dy) > abs(dx) && store.panel == .stack {
                    if dy < -70 { store.nextTab(); UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
                    else if dy > 70 { store.prevTab(); UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
                } else if abs(dx) > abs(dy) {
                    if dx < -70 && store.panel == .stack && store.tab != .disclaimer { store.openPicker() }
                    if dx > 70 && (store.panel == .intensity || store.panel == .language) {
                        store.panel = .stack
                    }
                }
            }
    }

    private func toggleSensing() {
        store.sensing.toggle()
        if store.sensing {
            detector.setVolumeFromIntensity(store.intensity)
            detector.start()
        } else {
            detector.stop()
        }
        let text = store.sensing
            ? (store.language == .zh ? "传感已开启" : store.language == .hi ? "सेंसिंग चालू" : "Sensing on")
            : (store.language == .zh ? "传感已关闭" : store.language == .hi ? "सेंसिंग बंद" : "Sensing off")
        Announcer.speak(text, language: store.language)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    private func toggleDebug() {
        if store.panel == .debug {
            store.panel = .stack
            detector.focusCell = nil   // restore centre-cell haptics
        } else {
            store.panel = .debug
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func label(_ tab: AppTab) -> String {
        switch (tab, store.language) {
        case (.disclaimer, .en): return "Disclaimer"
        case (.disclaimer, .zh): return "免责声明"
        case (.disclaimer, .hi): return "अस्वीकरण"
        case (.intensity, .en): return "Intensity"
        case (.intensity, .zh): return "强度"
        case (.intensity, .hi): return "तीव्रता"
        case (.language, .en): return "Language"
        case (.language, .zh): return "语言"
        case (.language, .hi): return "भाषा"
        }
    }

    private func numberLabel(_ n: Int) -> String {
        Announcer.numberLabel(n, language: store.language)
    }

    private func langLabel(_ lang: AppLanguage) -> String {
        lang.nativeName
    }

    private var hintPrimary: String {
        switch (store.tab, store.language) {
        case (.disclaimer, .en): return "Swipe left for language settings"
        case (.disclaimer, .zh): return "向左滑动进入语言设置"
        case (.disclaimer, .hi): return "भाषा सेटिंग के लिए बाएँ स्वाइप करें"
        case (.language, .en): return "Swipe left for language selection"
        case (.language, .zh): return "向左滑动选择语言"
        case (.language, .hi): return "भाषा चुनने के लिए बाएँ स्वाइप करें"
        case (.intensity, .en): return "Swipe left for intensity selection"
        case (.intensity, .zh): return "向左滑动选择强度"
        case (.intensity, .hi): return "तीव्रता चुनने के लिए बाएँ स्वाइप करें"
        }
    }

    private var hintSecondary: String {
        switch (store.tab, store.language) {
        case (.disclaimer, .en): return "Swipe up for Language"
        case (.disclaimer, .zh): return "向上滑动进入语言"
        case (.disclaimer, .hi): return "भाषा के लिए ऊपर स्वाइप करें"
        case (.language, .en): return "Swipe up for Intensity"
        case (.language, .zh): return "向上滑动进入强度"
        case (.language, .hi): return "तीव्रता के लिए ऊपर स्वाइप करें"
        case (.intensity, .en): return "Swipe up for Disclaimer"
        case (.intensity, .zh): return "向上滑动进入免责声明"
        case (.intensity, .hi): return "अस्वीकरण के लिए ऊपर स्वाइप करें"
        }
    }
}

struct DisclaimerView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(Copy.brand)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .tracking(4)
                .foregroundStyle(.gray)
            Text(title)
                .font(.system(size: 56, weight: .semibold, design: .default))
                .tracking(-2)
                .textCase(.uppercase)
            Text(Copy.disclaimer(for: store.language))
                .font(.system(size: 13))
                .lineSpacing(5)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.18), lineWidth: 1))
                .allowsHitTesting(false)
            Spacer()
            HintFooter(secondary: secondary)
        }
        .padding(.horizontal, 28)
        .padding(.top, 72)
        .padding(.bottom, 36)
    }

    private var title: String {
        store.language == .zh ? "免责声明" : store.language == .hi ? "अस्वीकरण" : "Disclaimer"
    }
    private var secondary: String {
        store.language == .zh ? "向上滑动进入语言" : store.language == .hi ? "भाषा के लिए ऊपर स्वाइप करें" : "Swipe up for Language"
    }
}

struct HubView: View {
    var title: String
    var value: String
    var primary: String
    var secondary: String
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(Copy.brand)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .tracking(4)
                .foregroundStyle(.gray)
            Text(title)
                .font(.system(size: 56, weight: .semibold))
                .tracking(-2)
                .textCase(.uppercase)
            Text(value)
                .font(.system(size: 44, weight: .semibold))
            Spacer()
            HintFooter(primary: primary, secondary: secondary)
        }
        .padding(.horizontal, 28)
        .padding(.top, 72)
        .padding(.bottom, 36)
    }
}

struct HintFooter: View {
    var primary: String = ""
    var secondary: String
    var body: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "chevron.up")
                if !primary.isEmpty { Text(primary) }
                Text(secondary)
            }
            .font(.system(size: 11, weight: .medium))
            .tracking(1.4)
            .multilineTextAlignment(.center)
            .textCase(.uppercase)
            .foregroundStyle(.gray)
            Spacer()
        }
    }
}

struct IntensityWheel: View {
    @EnvironmentObject var store: AppStore
    /// Accumulated drag steps so a long swipe can change several values.
    @State private var lastStep = 0
    private let stepHeight: CGFloat = 44

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            VStack {
                Text("INTENSITY").font(.system(size: 11, weight: .medium, design: .monospaced)).tracking(3).foregroundStyle(.gray)
                Picker("Intensity", selection: $store.intensity) {
                    ForEach(1...5, id: \.self) { n in
                        Text("\(n)").tag(n)
                    }
                }
                .pickerStyle(.wheel)
                .allowsHitTesting(false)   // whole screen drives the value
                Text("SWIPE UP / DOWN TO ADJUST")
                    .font(.system(size: 11)).tracking(1.4).foregroundStyle(.gray)
                Text("SWIPE RIGHT FOR BACK TO MENU")
                    .font(.system(size: 11)).tracking(1.4).foregroundStyle(.gray)
            }
            .foregroundStyle(.black)
        }
        .contentShape(Rectangle())
        .gesture(fullScreenDrag)
        .onChange(of: store.intensity) { _, n in
            Announcer.number(n, language: store.language)
        }
    }

    private var fullScreenDrag: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                // Prefer vertical control; ignore mostly-horizontal moves (back swipe).
                guard abs(value.translation.height) >= abs(value.translation.width) else { return }
                // Up (negative height) → higher intensity
                let stepIndex = Int(-value.translation.height / stepHeight)
                guard stepIndex != lastStep else { return }
                let diff = stepIndex - lastStep
                lastStep = stepIndex
                let next = min(5, max(1, store.intensity + diff))
                if next != store.intensity {
                    store.intensity = next
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
            .onEnded { value in
                lastStep = 0
                // Horizontal swipe right → back to menu
                if value.translation.width > 70,
                   abs(value.translation.width) > abs(value.translation.height) {
                    store.panel = .stack
                }
            }
    }
}

struct LanguageWheel: View {
    @EnvironmentObject var store: AppStore
    private static let languages = AppLanguage.allCases
    @State private var lastStep = 0
    private let stepHeight: CGFloat = 44

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            VStack {
                Text("LANGUAGE").font(.system(size: 11, weight: .medium, design: .monospaced)).tracking(3).foregroundStyle(.gray)
                Picker("Language", selection: $store.language) {
                    ForEach(Self.languages, id: \.self) { lang in
                        Text(lang.nativeName).tag(lang)
                    }
                }
                .pickerStyle(.wheel)
                .allowsHitTesting(false)   // whole screen drives the value
                Text("SWIPE UP / DOWN TO ADJUST")
                    .font(.system(size: 11)).tracking(1.4).foregroundStyle(.gray)
                Text("SWIPE RIGHT FOR BACK TO MENU")
                    .font(.system(size: 11)).tracking(1.4).foregroundStyle(.gray)
            }
            .foregroundStyle(.black)
        }
        .contentShape(Rectangle())
        .gesture(fullScreenDrag)
        .onChange(of: store.language) { _, lang in
            Announcer.speak(lang.nativeName, language: lang)
        }
    }

    private var fullScreenDrag: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard abs(value.translation.height) >= abs(value.translation.width) else { return }
                // Up → next language in the list; down → previous (clamped, not wrapping)
                let stepIndex = Int(-value.translation.height / stepHeight)
                guard stepIndex != lastStep else { return }
                let diff = stepIndex - lastStep
                lastStep = stepIndex
                guard let idx = Self.languages.firstIndex(of: store.language) else { return }
                let nextIdx = min(Self.languages.count - 1, max(0, idx + diff))
                let next = Self.languages[nextIdx]
                if next != store.language {
                    store.language = next
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
            .onEnded { value in
                lastStep = 0
                if value.translation.width > 70,
                   abs(value.translation.width) > abs(value.translation.height) {
                    store.panel = .stack
                }
            }
    }
}

struct VolumeRocker: View {
    var onChord: () -> Void
    @GestureState private var pressing = false

    var body: some View {
        VStack(spacing: 6) {
            Capsule().fill(pressing ? Color.white : Color.white.opacity(0.28)).frame(width: 8, height: 48)
            Capsule().fill(pressing ? Color.white : Color.white.opacity(0.28)).frame(width: 8, height: 48)
        }
        .padding(.leading, 8)
        .padding(.vertical, 12)
        .padding(.trailing, 28)
        .contentShape(Rectangle())
        .highPriorityGesture(
            LongPressGesture(minimumDuration: 2)
                .updating($pressing) { current, state, _ in state = current }
                .onEnded { _ in onChord() }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, 110)
    }
}
