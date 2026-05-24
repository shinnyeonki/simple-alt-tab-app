import Cocoa

final class Preferences {
    static let shared = Preferences()
    private let keySize = "UISize"
    private let keyPreviewWindow = "PreviewWindow"
    private let keyWindowScope = "WindowScope"
    private let legacyKeyPreviewOnHover = "PreviewOnHover"

    var uiSize: UISize {
        get {
            if let raw = UserDefaults.standard.string(forKey: keySize), let size = UISize(rawValue: raw) {
                return size
            }
            return .medium
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: keySize)
        }
    }

    var previewWindow: Bool {
        get {
            if let value = UserDefaults.standard.object(forKey: keyPreviewWindow) as? Bool {
                return value
            }
            return UserDefaults.standard.object(forKey: legacyKeyPreviewOnHover) as? Bool ?? false
        }
        set {
            UserDefaults.standard.set(newValue, forKey: keyPreviewWindow)
        }
    }

    var windowScope: WindowScope {
        get {
            if let raw = UserDefaults.standard.string(forKey: keyWindowScope) {
                if raw == "All Windows" {
                    return .allDesktops
                }
                if let scope = WindowScope(rawValue: raw) {
                    return scope
                }
            }
            return .allDesktops
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: keyWindowScope)
        }
    }
}

enum UISize: String, CaseIterable {
    case small = "Small"
    case medium = "Medium"
    case large = "Large"

    var rowHeight: CGFloat { self == .small ? 36 : (self == .large ? 56 : 46) }
    var iconSize: CGFloat { self == .small ? 24 : (self == .large ? 40 : 32) }
    var fontSize: CGFloat { self == .small ? 13 : (self == .large ? 17 : 15) }
    var titleSize: CGFloat { self == .small ? 12 : (self == .large ? 15 : 14) }
}

enum WindowScope: String, CaseIterable {
    case allDesktops = "All Desktops"
    case currentDesktop = "Current Desktop Only"
}
