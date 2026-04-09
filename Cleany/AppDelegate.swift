//
//  AppDelegate.swift
//  Cleany
//
//  Created by Leo Bähre on 2/6/26
//

import AppKit
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {

    private let settings = AppSettings.shared

    private let intervalOptions: [(title: String, hours: Int)] = [
        ("Every 1 hour", 1),
        ("Every 3 hours", 3),
        ("Every 6 hours", 6),
        ("Every 12 hours", 12),
        ("Every 24 hours", 24)
    ]

    private let cutoffOptions: [Int] = [1, 3, 7, 30, 90, 365]

    var statusItem: NSStatusItem!
    var menuRefreshTimer: Timer?

    var lastCleanupMenuItem: NSMenuItem!

    var lastCleanupDate: Date? {
        get {
            UserDefaults.standard.object(forKey: "LastCleanupDate") as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "LastCleanupDate")
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()

        syncLaunchAtLoginState()

        rebuildMenu()
        startMenuRefreshTimer()

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        runCleanupIfNeeded()
    }
    
    private func syncLaunchAtLoginState() {
        do {
            if settings.cleanAtLogin {
                if SMAppService.mainApp.status != .enabled {
                    do {
                        try SMAppService.mainApp.register()
                    } catch {
                        print(error)
                    }
                    print("Registered at login on launch")
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                    print("Unregistered at login on launch")
                }
            }
        } catch {
            print("Failed to sync launch at login:", error)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        menuRefreshTimer?.invalidate()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "trash",
            accessibilityDescription: "Cleany"
        )
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        lastCleanupMenuItem = NSMenuItem(
            title: lastCleanupTitle(),
            action: nil,
            keyEquivalent: ""
        )
        lastCleanupMenuItem.isEnabled = false
        menu.addItem(lastCleanupMenuItem)

        menu.addItem(.separator())

        menu.addItem(
            NSMenuItem(
                title: "Clean Downloads Now",
                action: #selector(cleanNow),
                keyEquivalent: "c"
            )
        )

        menu.addItem(.separator())

        let intervalItem = NSMenuItem(title: "Cleanup Interval", action: nil, keyEquivalent: "")
        intervalItem.submenu = makeIntervalMenu()
        menu.addItem(intervalItem)

        let cutoffItem = NSMenuItem(title: "Delete files older than", action: nil, keyEquivalent: "")
        cutoffItem.submenu = makeCutoffMenu()
        menu.addItem(cutoffItem)

        menu.addItem(.separator())

        let runAtLoginItem = NSMenuItem(
            title: "Run at Login",
            action: #selector(toggleCleanAtLogin),
            keyEquivalent: ""
        )
        runAtLoginItem.state = settings.cleanAtLogin ? .on : .off
        runAtLoginItem.target = self
        menu.addItem(runAtLoginItem)

        menu.addItem(.separator())

        menu.addItem(
            NSMenuItem(
                title: "Quit",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            )
        )

        statusItem.menu = menu
    }

    private func makeIntervalMenu() -> NSMenu {
        let menu = NSMenu()

        for option in intervalOptions {
            let item = NSMenuItem(
                title: option.title,
                action: #selector(selectInterval(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = option.hours
            item.state = settings.cleanupIntervalHours == option.hours ? .on : .off
            menu.addItem(item)
        }

        return menu
    }

    private func makeCutoffMenu() -> NSMenu {
        let menu = NSMenu()

        for days in cutoffOptions {
            let item = NSMenuItem(
                title: days > 1 ? "\(days) days" : "\(days) day",
                action: #selector(selectCutoff(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = days
            item.state = settings.cutoffDays == days ? .on : .off
            menu.addItem(item)
        }

        return menu
    }
    

    @objc private func cleanNow() {
        performCleanup()
    }

    @objc private func selectInterval(_ sender: NSMenuItem) {
        guard let hours = sender.representedObject as? Int else { return }
        settings.cleanupIntervalHours = hours
        rebuildMenu()
        runCleanupIfNeeded()
    }

    @objc private func selectCutoff(_ sender: NSMenuItem) {
        guard let days = sender.representedObject as? Int else { return }
        settings.cutoffDays = days
        rebuildMenu()
    }

    @objc private func toggleCleanAtLogin(_ sender: NSMenuItem) {
        settings.cleanAtLogin.toggle()
        sender.state = settings.cleanAtLogin ? .on : .off

        if settings.cleanAtLogin {
            try? SMAppService.mainApp.register()
        } else {
            try? SMAppService.mainApp.unregister()
        }
    }

    private func isCleanupDue() -> Bool {
        let interval = TimeInterval(settings.cleanupIntervalHours * 3600)

        guard let last = lastCleanupDate else {
            return true
        }

        return Date().timeIntervalSince(last) >= interval
    }

    private func runCleanupIfNeeded() {
        guard isCleanupDue() else { return }
        performCleanup()
    }

    @objc private func systemDidWake() {
        runCleanupIfNeeded()
    }

    private func performCleanup() {
        DownloadCleaner().clean()
        lastCleanupDate = Date()
        lastCleanupMenuItem.title = lastCleanupTitle()
    }

    private func startMenuRefreshTimer() {
        menuRefreshTimer = Timer.scheduledTimer(
            timeInterval: 60,
            target: self,
            selector: #selector(updateLastCleanupTitle),
            userInfo: nil,
            repeats: true
        )
    }

    private func lastCleanupTitle() -> String {
        guard let date = lastCleanupDate else {
            return "Last Cleanup: Never"
        }

        let seconds = Date().timeIntervalSince(date)
        if seconds < 60 {
            return "Last Cleanup: Just now"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short

        return "Last Cleanup: " + formatter.localizedString(
            for: date,
            relativeTo: Date()
        )
    }

    @objc private func updateLastCleanupTitle() {
        guard lastCleanupDate != nil else { return }
        lastCleanupMenuItem.title = lastCleanupTitle()
    }
}
