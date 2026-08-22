import Combine
import Foundation
import SwiftUI

enum AppTab: Int, CaseIterable {
    case disclaimer, language, intensity
}

enum Panel {
    case stack, intensity, language, debug
}

enum AppLanguage: String, CaseIterable {
    case zh, en, hi

    var speechCode: String {
        switch self {
        case .zh: return "zh-CN"
        case .en: return "en-US"
        case .hi: return "hi-IN"
        }
    }

    /// Always shown in the language’s own script (e.g. 中文, English, हिन्दी).
    var nativeName: String {
        switch self {
        case .zh: return "中文"
        case .en: return "English"
        case .hi: return "हिन्दी"
        }
    }

    var label: (en: String, zh: String, hi: String) {
        switch self {
        case .zh: return ("Chinese", "中文", "चीनी")
        case .en: return ("English", "英语", "अंग्रेज़ी")
        case .hi: return ("Hindi", "印地语", "हिन्दी")
        }
    }

    static func fromSystem() -> AppLanguage {
        let preferred = (Locale.preferredLanguages.first ?? Locale.current.identifier).lowercased()
        if preferred.hasPrefix("zh") { return .zh }
        if preferred.hasPrefix("hi") { return .hi }
        return .en
    }

    static func resolved() -> AppLanguage {
        if let raw = UserDefaults.standard.string(forKey: "lasal.language"),
           let lang = AppLanguage(rawValue: raw) {
            return lang
        }
        return fromSystem()
    }
}

enum Copy {
    static let brand = "LASAL"

    static func disclaimer(for language: AppLanguage) -> String {
        switch language {
        case .en:
            return """
            LASAL is a supplement to help people with visual impairment sense proximity to objects. It is not a replacement for other visual aids and should be used in tandem.

            Double tap to start or stop the program. Swipe up to change the menu, swipe left or right to adjust the settings relevant to the menu.
            """
        case .zh:
            return """
            LASAL 是帮助视障人士感知周围物体距离的辅助工具。它不能替代其他助视设备，应配合使用。

            双击开始或停止程序。向上滑动切换菜单，向左或向右滑动调整当前菜单的设置。
            """
        case .hi:
            return """
            LASAL दृष्टिबाधित लोगों को वस्तुओं की निकटता समझने में मदद करने वाला पूरक है। यह अन्य दृश्य सहायक उपकरणों का विकल्प नहीं है और उनके साथ इस्तेमाल होना चाहिए।

            प्रोग्राम शुरू या बंद करने के लिए डबल टैप करें। मेनू बदलने के लिए ऊपर स्वाइप करें, सेटिंग बदलने के लिए बाएँ या दाएँ स्वाइप करें।
            """
        }
    }
}

final class AppStore: ObservableObject {
    @Published var tab: AppTab = .disclaimer
    @Published var panel: Panel = .stack
    @Published var intensity: Int = 3
    @Published var language: AppLanguage = AppLanguage.resolved() {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "lasal.language") }
    }
    @Published var sensing = false
    @Published var debug = false

    func nextTab() {
        tab = AppTab(rawValue: (tab.rawValue + 1) % 3) ?? .disclaimer
        panel = .stack
    }

    func prevTab() {
        tab = AppTab(rawValue: (tab.rawValue + 2) % 3) ?? .disclaimer
        panel = .stack
    }

    func openPicker() {
        if tab == .intensity { panel = .intensity }
        if tab == .language { panel = .language }
    }
}
