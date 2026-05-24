import Cocoa
import ApplicationServices
import Carbon.HIToolbox

final class Preferences {
    static let shared = Preferences()
    private let keySize = "UISize"
    private let keyPreviewWindow = "PreviewWindow"
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

struct Theme {
    static let width: CGFloat = 600
    static let padding: CGFloat = 12
    static let radiusBG: CGFloat = 14
    static let radiusItem: CGFloat = 8

    static let bg = NSColor(white: 0.12, alpha: 0.85)
    static let highlight = NSColor(white: 0.35, alpha: 0.6)

    static var paragraphStyle: NSParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        return style
    }()

    static func attributes(isSelected: Bool, isTitle: Bool) -> [NSAttributedString.Key: Any] {
        let size = Preferences.shared.uiSize
        let font = isTitle ? NSFont.systemFont(ofSize: size.titleSize, weight: .regular)
                           : NSFont.systemFont(ofSize: size.fontSize, weight: .bold)

        let color: NSColor
        if isTitle {
            color = isSelected ? (NSColor(hex: "FFD700") ?? .systemYellow) : NSColor(white: 0.55, alpha: 1.0)
        } else {
            color = isSelected ? NSColor.white : NSColor(white: 0.8, alpha: 1.0)
        }

        return [.font: font, .foregroundColor: color, .paragraphStyle: paragraphStyle]
    }
}

extension NSColor {
    convenience init?(hex: String) {
        let hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        self.init(
            red: CGFloat((rgb & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgb & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgb & 0x0000FF) / 255.0,
            alpha: 1.0
        )
    }
}

struct WindowKey: Hashable {
    let pid: pid_t
    let axHash: Int
}

struct WindowItem {
    let axWindow: AXUIElement
    let app: NSRunningApplication
    let appName: String
    let title: String
    let icon: NSImage
    let key: WindowKey
    let fallbackOrder: Int
}

final class SwitcherView: NSView {
    var items: [WindowItem] = []
    var onItemHovered: ((Int) -> Void)?
    var onItemClicked: ((Int) -> Void)?

    var currentIndex: Int = 0 {
        didSet {
            guard oldValue != currentIndex else { return }
            setNeedsDisplay(rectForItem(at: oldValue))
            setNeedsDisplay(rectForItem(at: currentIndex))
        }
    }

    private var trackingArea: NSTrackingArea?

    override var acceptsFirstResponder: Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let options: NSTrackingArea.Options = [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        trackingArea = area
        addTrackingArea(area)
    }

    override func mouseEntered(with event: NSEvent) {
        selectItem(at: event.locationInWindow)
    }

    override func mouseMoved(with event: NSEvent) {
        selectItem(at: event.locationInWindow)
    }

    override func mouseDown(with event: NSEvent) {
        let index = indexForPoint(convert(event.locationInWindow, from: nil))
        if index >= 0 {
            onItemClicked?(index)
        }
    }

    private func selectItem(at windowPoint: NSPoint) {
        let index = indexForPoint(convert(windowPoint, from: nil))
        if index >= 0 {
            onItemHovered?(index)
        }
    }

    private func indexForPoint(_ point: NSPoint) -> Int {
        items.indices.first(where: { rectForItem(at: $0).contains(point) }) ?? -1
    }

    private func rectForItem(at index: Int) -> NSRect {
        guard items.indices.contains(index) else { return .zero }
        let rowHeight = Preferences.shared.uiSize.rowHeight
        let yPos = bounds.height - Theme.padding - CGFloat(index + 1) * rowHeight
        return NSRect(x: 0, y: yPos, width: Theme.width, height: rowHeight)
    }

    override func draw(_ dirtyRect: NSRect) {
        if dirtyRect.intersects(bounds) {
            Theme.bg.setFill()
            NSBezierPath(roundedRect: bounds, xRadius: Theme.radiusBG, yRadius: Theme.radiusBG).fill()
        }

        let prefs = Preferences.shared.uiSize
        let iconSize = prefs.iconSize
        let textHeight: CGFloat = prefs.fontSize + 10

        for (index, item) in items.enumerated() {
            let itemRect = rectForItem(at: index)
            guard dirtyRect.intersects(itemRect) else { continue }

            let isSelected = index == currentIndex
            let innerRect = itemRect.insetBy(dx: Theme.padding, dy: 0)

            if isSelected {
                Theme.highlight.setFill()
                NSBezierPath(roundedRect: innerRect, xRadius: Theme.radiusItem, yRadius: Theme.radiusItem).fill()
            }

            let iconRect = NSRect(
                x: innerRect.minX + 12,
                y: innerRect.midY - (iconSize / 2),
                width: iconSize,
                height: iconSize
            )
            item.icon.draw(in: iconRect)

            let textRect = NSRect(
                x: iconRect.maxX + 12,
                y: innerRect.midY - (textHeight / 2) - 2,
                width: innerRect.width - iconSize - 34,
                height: textHeight
            )

            let textToDraw = NSMutableAttributedString(
                string: "\(item.appName)   ",
                attributes: Theme.attributes(isSelected: isSelected, isTitle: false)
            )
            textToDraw.append(NSAttributedString(
                string: item.title,
                attributes: Theme.attributes(isSelected: isSelected, isTitle: true)
            ))
            textToDraw.draw(in: textRect)
        }
    }
}

final class SwitcherWindow: NSPanel {
    let switcherView = SwitcherView()

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .screenSaver
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        contentView = switcherView
        acceptsMouseMovedEvents = true
    }

    func show(with items: [WindowItem], index: Int) {
        let rowHeight = Preferences.shared.uiSize.rowHeight
        let height = CGFloat(items.count) * rowHeight + (Theme.padding * 2)
        guard let screen = NSScreen.main else { return }

        let frame = NSRect(
            x: screen.frame.midX - (Theme.width / 2),
            y: screen.frame.midY - (height / 2),
            width: Theme.width,
            height: height
        )

        setFrame(frame, display: false)
        switcherView.items = items
        switcherView.currentIndex = index
        makeKeyAndOrderFront(nil)
        switcherView.window?.acceptsMouseMovedEvents = true
        switcherView.needsDisplay = true
    }

    func hide() {
        orderOut(nil)
        switcherView.items.removeAll(keepingCapacity: true)
    }
}

final class SwitcherManager {
    static let shared = SwitcherManager()

    private let uiWindow = SwitcherWindow()
    private var isSwitching = false
    private var cachedWins: [WindowItem] = []
    private var currentIndex = 0

    private var mruWindowKeys: [WindowKey] = []
    private var observedPIDs: Set<pid_t> = []
    private var axObservers: [pid_t: AXObserver] = [:]
    private var iconCache: [String: NSImage] = [:]
    private var pendingPreviewWorkItem: DispatchWorkItem?
    private let mruLock = NSLock()

    private init() {
        setupObservers()
        setupUIHandlers()
        refreshAXObservers()
        seedInitialMRU()
    }

    private func setupObservers() {
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] notification in
            guard let self,
                  !self.isSwitching,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }
            self.observeApp(app)
            self.recordFocusedWindow(for: app)
        }

        nc.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.observeApp(app)
        }

        nc.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] notification in
            guard let self,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }
            let pid = app.processIdentifier
            self.mruLock.lock()
            self.mruWindowKeys.removeAll(where: { $0.pid == pid })
            self.mruLock.unlock()
            self.observedPIDs.remove(pid)
            self.axObservers.removeValue(forKey: pid)
            self.iconCache = self.iconCache.filter { !$0.key.hasPrefix("\(pid):") }
        }
    }

    private func setupUIHandlers() {
        uiWindow.switcherView.onItemHovered = { [weak self] index in
            guard let self, self.isSwitching, self.cachedWins.indices.contains(index) else { return }
            self.currentIndex = index
            self.uiWindow.switcherView.currentIndex = index
            self.schedulePreviewWindow(at: index)
        }

        uiWindow.switcherView.onItemClicked = { [weak self] index in
            guard let self, self.isSwitching, self.cachedWins.indices.contains(index) else { return }
            self.currentIndex = index
            self.executeSwitch()
        }
    }

    private func refreshAXObservers() {
        let runningApps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
        let runningPIDs = Set(runningApps.map(\.processIdentifier))

        for pid in observedPIDs.subtracting(runningPIDs) {
            observedPIDs.remove(pid)
            axObservers.removeValue(forKey: pid)
            iconCache = iconCache.filter { !$0.key.hasPrefix("\(pid):") }
        }

        runningApps.forEach { observeApp($0) }
    }

    private func observeApp(_ app: NSRunningApplication) {
        guard app.activationPolicy == .regular else { return }

        let pid = app.processIdentifier
        guard !observedPIDs.contains(pid) else { return }

        var observer: AXObserver?
        let result = AXObserverCreate(pid, { _, element, notification, userData in
            guard notification as String == kAXFocusedWindowChangedNotification else { return }
            guard let userData else { return }
            let pid = pid_t(Int(bitPattern: userData))
            DispatchQueue.main.async {
                SwitcherManager.shared.recordWindow(element, pid: pid)
            }
        }, &observer)

        guard result == .success, let observer else { return }

        let axApp = AXUIElementCreateApplication(pid)
        let userData = UnsafeMutableRawPointer(bitPattern: Int(pid))
        AXObserverAddNotification(observer, axApp, kAXFocusedWindowChangedNotification as CFString, userData)
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        observedPIDs.insert(pid)
        axObservers[pid] = observer
    }

    private func seedInitialMRU() {
        if let frontmost = NSWorkspace.shared.frontmostApplication {
            recordFocusedWindow(for: frontmost)
        }
    }

    private func recordFocusedWindow(for app: NSRunningApplication) {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var focusedRaw: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &focusedRaw) == .success,
              let focusedWindow = focusedRaw else {
            return
        }
        recordWindow(focusedWindow as! AXUIElement, pid: app.processIdentifier)
    }

    private func recordWindow(_ window: AXUIElement, pid: pid_t) {
        let key = WindowKey(pid: pid, axHash: Int(CFHash(window)))

        mruLock.lock()
        if let index = mruWindowKeys.firstIndex(of: key) {
            mruWindowKeys.remove(at: index)
        }
        mruWindowKeys.insert(key, at: 0)
        if mruWindowKeys.count > 200 {
            mruWindowKeys.removeLast(mruWindowKeys.count - 200)
        }
        mruLock.unlock()
    }

    private func fallbackWindowOrder() -> [WindowKey: Int] {
        guard let windowInfos = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return [:]
        }

        var order: [WindowKey: Int] = [:]
        for (index, info) in windowInfos.enumerated() {
            guard let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                  NSRunningApplication(processIdentifier: pid)?.activationPolicy == .regular else {
                continue
            }
            order[WindowKey(pid: pid, axHash: 0)] = index
        }
        return order
    }

    private func cachedIcon(for app: NSRunningApplication, size: CGFloat) -> NSImage {
        let cacheKey = "\(app.processIdentifier):\(Int(size))"
        if let cached = iconCache[cacheKey] {
            return cached
        }

        let icon = (app.icon?.copy() as? NSImage) ?? NSImage()
        icon.size = NSSize(width: size, height: size)
        iconCache[cacheKey] = icon
        return icon
    }

    private func getWindows(isAppOnly: Bool) -> [WindowItem] {
        var items: [WindowItem] = []
        let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let iconSize = Preferences.shared.uiSize.iconSize
        let fallbackOrder = fallbackWindowOrder()

        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            if isAppOnly && app.processIdentifier != frontPID { continue }

            let axApp = AXUIElementCreateApplication(app.processIdentifier)
            var windowsRaw: CFTypeRef?
            guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRaw) == .success,
                  let windows = windowsRaw as? [AXUIElement] else {
                continue
            }

            let appName = app.localizedName ?? "Unknown"
            let icon = cachedIcon(for: app, size: iconSize)

            for window in windows {
                var subroleRaw: CFTypeRef?
                AXUIElementCopyAttributeValue(window, kAXSubroleAttribute as CFString, &subroleRaw)
                if let subrole = subroleRaw as? String, subrole != kAXStandardWindowSubrole {
                    continue
                }

                var titleRaw: CFTypeRef?
                AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRaw)
                let title = (titleRaw as? String) ?? ""

                let key = WindowKey(pid: app.processIdentifier, axHash: Int(CFHash(window)))
                let pidFallbackKey = WindowKey(pid: app.processIdentifier, axHash: 0)
                items.append(WindowItem(
                    axWindow: window,
                    app: app,
                    appName: appName,
                    title: title,
                    icon: icon,
                    key: key,
                    fallbackOrder: fallbackOrder[pidFallbackKey] ?? Int.max
                ))
            }
        }

        mruLock.lock()
        let currentMRU = mruWindowKeys
        mruLock.unlock()

        return items.sorted { left, right in
            let leftMRU = currentMRU.firstIndex(of: left.key) ?? Int.max
            let rightMRU = currentMRU.firstIndex(of: right.key) ?? Int.max
            if leftMRU != rightMRU {
                return leftMRU < rightMRU
            }
            if left.fallbackOrder != right.fallbackOrder {
                return left.fallbackOrder < right.fallbackOrder
            }
            return left.appName.localizedCaseInsensitiveCompare(right.appName) == .orderedAscending
        }
    }

    func handleSwitch(isAppOnly: Bool, isReverse: Bool) {
        if !isSwitching {
            isSwitching = true
            refreshAXObservers()
            cachedWins = getWindows(isAppOnly: isAppOnly)
            if cachedWins.count <= 1 {
                cancelSwitch()
                return
            }
            currentIndex = isReverse ? cachedWins.count - 1 : 1
        } else if isReverse {
            currentIndex = currentIndex > 0 ? currentIndex - 1 : cachedWins.count - 1
        } else {
            currentIndex = currentIndex < cachedWins.count - 1 ? currentIndex + 1 : 0
        }

        uiWindow.show(with: cachedWins, index: currentIndex)
        schedulePreviewWindow(at: currentIndex)
    }

    func handleModifiersChanged(flags: CGEventFlags) {
        guard isSwitching, !flags.contains(.maskAlternate) else { return }
        executeSwitch()
    }

    private func schedulePreviewWindow(at index: Int) {
        pendingPreviewWorkItem?.cancel()
        guard Preferences.shared.previewWindow else { return }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.isSwitching, self.cachedWins.indices.contains(index), self.currentIndex == index else { return }
            self.previewWindow(self.cachedWins[index])
        }
        pendingPreviewWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: workItem)
    }

    private func previewWindow(_ item: WindowItem) {
        if #available(macOS 14.0, *) {
            NSApp.yieldActivation(to: item.app)
            item.app.activate()
        } else {
            item.app.activate(options: .activateIgnoringOtherApps)
        }

        AXUIElementSetAttributeValue(item.axWindow, kAXMainAttribute as CFString, true as CFTypeRef)
        AXUIElementSetAttributeValue(item.axWindow, kAXFocusedAttribute as CFString, true as CFTypeRef)
        AXUIElementPerformAction(item.axWindow, kAXRaiseAction as CFString)
    }

    private func executeSwitch() {
        guard isSwitching, cachedWins.indices.contains(currentIndex) else {
            cancelSwitch()
            return
        }

        let target = cachedWins[currentIndex]

        if #available(macOS 14.0, *) {
            NSApp.yieldActivation(to: target.app)
            target.app.activate()
        } else {
            target.app.activate(options: .activateIgnoringOtherApps)
        }

        var isMinimized: CFTypeRef?
        AXUIElementCopyAttributeValue(target.axWindow, kAXMinimizedAttribute as CFString, &isMinimized)
        if let minimized = isMinimized as? Bool, minimized {
            AXUIElementSetAttributeValue(target.axWindow, kAXMinimizedAttribute as CFString, false as CFTypeRef)
        } else {
            AXUIElementPerformAction(target.axWindow, kAXRaiseAction as CFString)
        }

        recordWindow(target.axWindow, pid: target.app.processIdentifier)
        cancelSwitch()
    }

    private func cancelSwitch() {
        isSwitching = false
        pendingPreviewWorkItem?.cancel()
        pendingPreviewWorkItem = nil
        uiWindow.hide()
        cachedWins.removeAll(keepingCapacity: true)
    }
}

final class EventMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    func start() -> Bool {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: true)
            return CGEvent.tapIsEnabled(tap: eventTap)
        }

        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { _, type, event, _ in
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    return Unmanaged.passUnretained(event)
                }

                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                let flags = event.flags
                let isOption = flags.contains(.maskAlternate)
                let isShift = flags.contains(.maskShift)

                if type == .flagsChanged {
                    DispatchQueue.main.async {
                        SwitcherManager.shared.handleModifiersChanged(flags: flags)
                    }
                    return Unmanaged.passUnretained(event)
                }

                if type == .keyDown && isOption {
                    if keyCode == 48 {
                        DispatchQueue.main.async {
                            SwitcherManager.shared.handleSwitch(isAppOnly: false, isReverse: isShift)
                        }
                        return nil
                    } else if keyCode == 50 {
                        DispatchQueue.main.async {
                            SwitcherManager.shared.handleSwitch(isAppOnly: true, isReverse: isShift)
                        }
                        return nil
                    }
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: nil
        )

        guard let eventTap else {
            print("EventTap creation failed. Allow Accessibility permission in System Settings.")
            return false
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        return CGEvent.tapIsEnabled(tap: eventTap)
    }
}
