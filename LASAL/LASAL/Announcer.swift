import AVFoundation

enum Announcer {
    private static let synth = AVSpeechSynthesizer()

    /// Stop any in-progress speech immediately (e.g. when user navigates away).
    static func stop() {
        synth.stopSpeaking(at: .immediate)
    }

    static func speak(_ text: String, language: AppLanguage) {
        stop()
        let u = AVSpeechUtterance(string: text)
        u.voice = AVSpeechSynthesisVoice(language: language.speechCode)
        u.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        synth.speak(u)
    }

    static func page(_ tab: AppTab, panel: Panel, intensity: Int, language: AppLanguage, hold: Bool = false) {
        speak(script(tab: tab, panel: panel, intensity: intensity, language: language, hold: hold), language: language)
    }

    static func number(_ n: Int, language: AppLanguage) {
        speak(numberLabel(n, language: language), language: language)
    }

    static func numberLabel(_ n: Int, language: AppLanguage) -> String {
        let en = ["One", "Two", "Three", "Four", "Five"]
        let zh = ["一", "二", "三", "四", "五"]
        let hi = ["एक", "दो", "तीन", "चार", "पाँच"]
        let i = min(5, max(1, n)) - 1
        return language == .zh ? zh[i] : language == .hi ? hi[i] : en[i]
    }

    static func script(tab: AppTab, panel: Panel, intensity: Int, language: AppLanguage, hold: Bool) -> String {
        let number = numberLabel(intensity, language: language)
        let langName = language.nativeName

        if panel == .language {
            switch language {
            case .zh:
                let base = "语言选择。向上滚动查看选项。向右滑动返回菜单。"
                return hold ? "\(base)当前语言，\(langName)。强度，\(number)。" : base
            case .hi:
                let base = "भाषा चयन। विकल्पों के लिए ऊपर स्क्रॉल करें। मेनू पर वापस दाएँ स्वाइप करें।"
                return hold ? "\(base) वर्तमान भाषा, \(langName)। तीव्रता, \(number)।" : base
            case .en:
                let base = "Language selection. Scroll up for options. Swipe right for back to menu."
                return hold ? "\(base) Current language, \(langName). Intensity, \(number)." : base
            }
        }
        if panel == .intensity {
            switch language {
            case .zh:
                let base = "强度选择。向上滚动提高强度，向下滚动降低强度。向右滑动返回菜单。"
                return hold ? "\(base)当前强度，\(number)。" : base
            case .hi:
                let base = "तीव्रता चयन। अधिक तीव्रता के लिए ऊपर स्क्रॉल करें, कम के लिए नीचे। मेनू पर वापस दाएँ स्वाइप करें।"
                return hold ? "\(base) वर्तमान तीव्रता, \(number)।" : base
            case .en:
                let base = "Intensity selection. Scroll up for higher intensity, scroll down for lower intensity. Swipe right for back to menu."
                return hold ? "\(base) Current intensity, \(number)." : base
            }
        }

        switch (tab, language) {
        case (.disclaimer, .en):
            return "Disclaimer. LAZAL is a supplement to help people with visual impairment sense proximity to objects. It is not a replacement for other visual aids and should be used in tandem. Double tap to start or stop the program. Swipe up to change the menu, swipe left or right to adjust the settings relevant to the menu. Swipe up for Language."
        case (.disclaimer, .zh):
            return "免责声明。LAZAL 是帮助视障人士感知周围物体距离的辅助工具。它不能替代其他助视设备，应配合使用。双击开始或停止程序。向上滑动切换菜单，向左或向右滑动调整当前菜单的设置。向上滑动进入语言。"
        case (.disclaimer, .hi):
            return "अस्वीकरण। LAZAL दृष्टिबाधित लोगों को वस्तुओं की निकटता समझने में मदद करने वाला पूरक है। यह अन्य दृश्य सहायक उपकरणों का विकल्प नहीं है और उनके साथ इस्तेमाल होना चाहिए। प्रोग्राम शुरू या बंद करने के लिए डबल टैप करें। मेनू बदलने के लिए ऊपर स्वाइप करें, सेटिंग बदलने के लिए बाएँ या दाएँ स्वाइप करें। भाषा के लिए ऊपर स्वाइप करें।"
        case (.language, .en):
            return "Language. Swipe left for language selection. Swipe up for Intensity."
        case (.language, .zh):
            return "语言。向左滑动选择语言。向上滑动进入强度。"
        case (.language, .hi):
            return "भाषा। भाषा चयन के लिए बाएँ स्वाइप करें। तीव्रता के लिए ऊपर स्वाइप करें।"
        case (.intensity, .en):
            return "Intensity. Swipe left for intensity selection. Swipe up for Disclaimer."
        case (.intensity, .zh):
            return "强度。向左滑动选择强度。向上滑动进入免责声明。"
        case (.intensity, .hi):
            return "तीव्रता। तीव्रता चयन के लिए बाएँ स्वाइप करें। अस्वीकरण के लिए ऊपर स्वाइप करें।"
        }
    }
}
