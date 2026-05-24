import Cocoa
import ApplicationServices
import ServiceManagement

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let eventMonitor = EventMonitor()
    private var statusItem: NSStatusItem?
    private var statusMenuItem: NSMenuItem?
    private var accessibilityPollTimer: Timer?
    private var didStartEventMonitor = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.windows.forEach { $0.close() }

        setupMenuBar()
        _ = SwitcherManager.shared

        requestAccessibilityIfNeeded()
        startEventMonitorIfTrusted()
        print("Simple Option Tab started")
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "rectangle.stack", accessibilityDescription: "Option Switcher")

        let menu = NSMenu()
        let currentSize = Preferences.shared.uiSize
        let statusMenuItem = NSMenuItem(title: "Status: Starting", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        self.statusMenuItem = statusMenuItem
        menu.addItem(statusMenuItem)
        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "About Simple Option Tab", action: #selector(actionShowAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        let previewItem = NSMenuItem(title: "Preview Window", action: #selector(togglePreviewWindow(_:)), keyEquivalent: "")
        previewItem.state = Preferences.shared.previewWindow ? .on : .off
        menu.addItem(previewItem)

        let sizeItem = NSMenuItem(title: "Size", action: nil, keyEquivalent: "")
        let sizeMenu = NSMenu()
        for size in UISize.allCases {
            let item = NSMenuItem(title: size.rawValue, action: #selector(changeSize(_:)), keyEquivalent: "")
            item.representedObject = size
            item.state = currentSize == size ? .on : .off
            sizeMenu.addItem(item)
        }
        sizeItem.submenu = sizeMenu
        menu.addItem(sizeItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Check Accessibility Permissions", action: #selector(actionCheckAccessibility), keyEquivalent: ""))
        let loginItem = NSMenuItem(title: "Start at Login", action: #selector(toggleLoginItem(_:)), keyEquivalent: "")
        if #available(macOS 13.0, *) {
            loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        }
        menu.addItem(loginItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    @objc private func changeSize(_ sender: NSMenuItem) {
        guard let newSize = sender.representedObject as? UISize else { return }
        Preferences.shared.uiSize = newSize

        if let menu = sender.menu {
            for item in menu.items {
                item.state = item.representedObject as? UISize == newSize ? .on : .off
            }
        }
    }

    @objc private func togglePreviewWindow(_ sender: NSMenuItem) {
        Preferences.shared.previewWindow.toggle()
        sender.state = Preferences.shared.previewWindow ? .on : .off
    }

    @objc private func actionCheckAccessibility() {
        let isTrusted = checkAccessibility(prompt: false)
        if isTrusted {
            _ = startEventMonitorIfTrusted()
        } else {
            requestAccessibilityIfNeeded()
        }
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = isTrusted ? "Accessibility Granted" : "Accessibility Required"
        alert.informativeText = isTrusted
            ? "Simple Option Tab has the required permissions to switch windows."
            : "Please allow the app in System Settings > Privacy & Security > Accessibility."
        alert.runModal()
    }

    @objc private func actionShowAbout() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Simple Option Tab"
        alert.informativeText = "A lightweight macOS window switcher."
        alert.icon = NSImage(systemSymbolName: "macwindow.on.rectangle", accessibilityDescription: nil)
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func toggleLoginItem(_ sender: NSMenuItem) {
        if #available(macOS 13.0, *) {
            do {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                    sender.state = .off
                } else {
                    try SMAppService.mainApp.register()
                    sender.state = .on
                }
            } catch {
                print("Login item toggle failed: \(error.localizedDescription)")
            }
        }
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    @discardableResult
    private func checkAccessibility(prompt: Bool) -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: prompt]
        return AXIsProcessTrustedWithOptions(options)
    }

    private func requestAccessibilityIfNeeded() {
        guard !checkAccessibility(prompt: false) else {
            updateStatus("Ready")
            return
        }
        updateStatus("Waiting for Accessibility")
        _ = checkAccessibility(prompt: true)
        startAccessibilityPolling()
    }

    private func startAccessibilityPolling() {
        accessibilityPollTimer?.invalidate()
        accessibilityPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            if self.startEventMonitorIfTrusted() {
                timer.invalidate()
                self.accessibilityPollTimer = nil
            }
        }
    }

    @discardableResult
    private func startEventMonitorIfTrusted() -> Bool {
        guard checkAccessibility(prompt: false) else {
            updateStatus("Waiting for Accessibility")
            return false
        }
        guard !didStartEventMonitor else { return true }

        if eventMonitor.start() {
            didStartEventMonitor = true
            updateStatus("Ready")
            return true
        }

        updateStatus("Keyboard Tap Failed")
        startAccessibilityPolling()
        return false
    }

    private func updateStatus(_ status: String) {
        statusMenuItem?.title = "Status: \(status)"
        statusItem?.button?.image = NSImage(
            systemSymbolName: status == "Ready" ? "rectangle.stack.fill" : "exclamationmark.triangle",
            accessibilityDescription: "Option Switcher"
        )
    }
}
