import Cocoa
import ApplicationServices
import ServiceManagement

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let eventMonitor = EventMonitor()
    private var statusItem: NSStatusItem?
    private var statusMenuItem: NSMenuItem?
    private var permissionPollTimer: Timer?
    private var didStartEventMonitor = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.windows.forEach { $0.close() }

        setupMenuBar()
        _ = SwitcherManager.shared

        checkPermissionsAndStart()
        print("Simple Alt Tab started")
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

        menu.addItem(NSMenuItem(title: "About Simple Alt Tab", action: #selector(actionShowAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        let previewItem = NSMenuItem(title: "Live Window Preview", action: #selector(togglePreviewWindow(_:)), keyEquivalent: "")
        previewItem.state = Preferences.shared.previewWindow ? .on : .off
        menu.addItem(previewItem)

        let scopeItem = NSMenuItem(title: "Window Scope", action: nil, keyEquivalent: "")
        let scopeMenu = NSMenu()
        let currentScope = Preferences.shared.windowScope
        for scope in WindowScope.allCases {
            let item = NSMenuItem(title: scope.rawValue, action: #selector(changeWindowScope(_:)), keyEquivalent: "")
            item.representedObject = scope
            item.state = currentScope == scope ? .on : .off
            scopeMenu.addItem(item)
        }
        scopeItem.submenu = scopeMenu
        menu.addItem(scopeItem)

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
        menu.addItem(NSMenuItem(title: "Check Screen Recording Permission", action: #selector(actionCheckScreenRecording), keyEquivalent: ""))
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

    @objc private func changeWindowScope(_ sender: NSMenuItem) {
        guard let scope = sender.representedObject as? WindowScope else { return }
        Preferences.shared.windowScope = scope

        if let menu = sender.menu {
            for item in menu.items {
                item.state = item.representedObject as? WindowScope == scope ? .on : .off
            }
        }

        checkPermissionsAndStart()
    }

    @objc private func actionCheckScreenRecording() {
        if #available(macOS 10.15, *) {
            let hasPermission = CGPreflightScreenCaptureAccess()
            if !hasPermission {
                CGRequestScreenCaptureAccess()
            }
            checkPermissionsAndStart()
            
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = hasPermission ? "Screen Recording Permission Granted" : "Screen Recording Permission Required"
            alert.informativeText = hasPermission
                ? "The application has permissions to read window titles across all desktops."
                : "Please allow the app in System Settings > Privacy & Security > Screen & System Audio Recording (or Screen Recording) to enable window switching across all desktops."
            alert.runModal()
        } else {
            let alert = NSAlert()
            alert.messageText = "Not Required"
            alert.informativeText = "Screen recording permission is not required on this macOS version."
            alert.runModal()
        }
    }

    @objc private func actionCheckAccessibility() {
        let isTrusted = checkAccessibility(prompt: false)
        if !isTrusted {
            _ = checkAccessibility(prompt: true)
        }
        checkPermissionsAndStart()

        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = isTrusted ? "Accessibility Granted" : "Accessibility Required"
        alert.informativeText = isTrusted
            ? "Simple Alt Tab has the required permissions to switch windows."
            : "Please allow the app in System Settings > Privacy & Security > Accessibility."
        alert.runModal()
    }

    @objc private func actionShowAbout() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Simple Alt Tab"
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

    private func checkPermissionsAndStart() {
        let hasAccessibility = checkAccessibility(prompt: false)
        
        var hasScreenRecording = true
        if Preferences.shared.windowScope == .allDesktops {
            if #available(macOS 10.15, *) {
                hasScreenRecording = CGPreflightScreenCaptureAccess()
            }
        }

        if !hasAccessibility {
            updateStatus("Waiting for Accessibility")
            _ = checkAccessibility(prompt: true)
            startPermissionPolling()
        } else if !hasScreenRecording {
            updateStatus("Waiting for Screen Recording")
            if #available(macOS 10.15, *) {
                CGRequestScreenCaptureAccess()
            }
            startPermissionPolling()
        } else {
            permissionPollTimer?.invalidate()
            permissionPollTimer = nil
            if startEventMonitorIfTrusted() {
                updateStatus("Ready")
            }
        }
    }

    private func startPermissionPolling() {
        permissionPollTimer?.invalidate()
        permissionPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            
            let hasAccessibility = self.checkAccessibility(prompt: false)
            
            var hasScreenRecording = true
            if Preferences.shared.windowScope == .allDesktops {
                if #available(macOS 10.15, *) {
                    hasScreenRecording = CGPreflightScreenCaptureAccess()
                }
            }

            if hasAccessibility && hasScreenRecording {
                timer.invalidate()
                self.permissionPollTimer = nil
                if self.startEventMonitorIfTrusted() {
                    self.updateStatus("Ready")
                }
            } else if !hasAccessibility {
                self.updateStatus("Waiting for Accessibility")
            } else {
                self.updateStatus("Waiting for Screen Recording")
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
            return true
        }

        updateStatus("Keyboard Tap Failed")
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
