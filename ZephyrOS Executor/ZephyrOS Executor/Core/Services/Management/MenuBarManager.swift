//
//  MenuBarManager.swift
//  ZephyrOS Executor
//
//  Menu bar integration manager
//

import AppKit
import SwiftUI

class MenuBarManager: NSObject {
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private let executorManager = ExecutorManager.shared

    override init() {
        super.init()
        setupMenuBar()
    }

    private func setupMenuBar() {
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem?.button else { return }

        // Set initial icon
        updateStatusIcon()

        // Create menu
        menu = NSMenu()

        // Status section
        let statusMenuItem = NSMenuItem(title: "Status: Idle", action: nil, keyEquivalent: "")
        statusMenuItem.tag = MenuItemTag.status.rawValue
        menu?.addItem(statusMenuItem)

        let tasksItem = NSMenuItem(title: "Active Tasks: 0", action: nil, keyEquivalent: "")
        tasksItem.tag = MenuItemTag.activeTasks.rawValue
        menu?.addItem(tasksItem)

        menu?.addItem(NSMenuItem.separator())

        // Control buttons
        let startStopItem = NSMenuItem(title: "Start Executor", action: #selector(toggleExecutor), keyEquivalent: "")
        startStopItem.tag = MenuItemTag.startStop.rawValue
        startStopItem.target = self
        menu?.addItem(startStopItem)

        let pauseResumeItem = NSMenuItem(title: "Pause", action: #selector(togglePause), keyEquivalent: "")
        pauseResumeItem.tag = MenuItemTag.pauseResume.rawValue
        pauseResumeItem.target = self
        pauseResumeItem.isHidden = true
        menu?.addItem(pauseResumeItem)

        menu?.addItem(NSMenuItem.separator())

        // Quick actions
        let refreshItem = NSMenuItem(title: "Refresh Queue", action: #selector(refreshQueue), keyEquivalent: "r")
        refreshItem.target = self
        menu?.addItem(refreshItem)

        menu?.addItem(NSMenuItem.separator())

        // Window controls
        let showWindowItem = NSMenuItem(title: "Show Dashboard", action: #selector(showMainWindow), keyEquivalent: "d")
        showWindowItem.target = self
        menu?.addItem(showWindowItem)

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu?.addItem(settingsItem)

        menu?.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit ZephyrOS Executor", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu?.addItem(quitItem)

        statusItem?.menu = menu

        // Observe executor state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(executorStateChanged),
            name: NSNotification.Name("ExecutorStateChanged"),
            object: nil
        )

        // Update menu periodically
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateMenu()
        }
    }

    private func updateStatusIcon() {
        guard let button = statusItem?.button else { return }

        let status = executorManager.state.status
        let iconName: String

        switch status {
        case .idle:
            iconName = "pause.circle"
        case .running:
            iconName = "play.circle.fill"
        case .paused:
            iconName = "pause.circle.fill"
        case .error:
            iconName = "exclamationmark.triangle.fill"
        case .disconnected:
            iconName = "wifi.slash"
        }

        if let image = NSImage(systemSymbolName: iconName, accessibilityDescription: status.rawValue) {
            image.isTemplate = true
            button.image = image
        }
    }

    private func updateMenu() {
        guard let menu = menu else { return }

        let state = executorManager.state
        let stats = executorManager.statistics

        // Update status
        if let statusItem = menu.item(withTag: MenuItemTag.status.rawValue) {
            let statusText = state.status.rawValue.capitalized
            let connectionStatus = state.isConnectedToZMemory && state.isConnectedToClaude ? "✓" : "✗"
            statusItem.title = "Status: \(statusText) \(connectionStatus)"
        }

        // Update active tasks
        if let tasksItem = menu.item(withTag: MenuItemTag.activeTasks.rawValue) {
            tasksItem.title = "Active Tasks: \(state.activeTasks.count) • Total: \(stats.totalTasks)"
        }

        // Update start/stop button
        if let startStopItem = menu.item(withTag: MenuItemTag.startStop.rawValue) {
            if state.status == .running || state.status == .paused {
                startStopItem.title = "Stop Executor"
            } else {
                startStopItem.title = "Start Executor"
            }
        }

        // Update pause/resume button
        if let pauseResumeItem = menu.item(withTag: MenuItemTag.pauseResume.rawValue) {
            if state.status == .running {
                pauseResumeItem.title = "Pause"
                pauseResumeItem.isHidden = false
            } else if state.status == .paused {
                pauseResumeItem.title = "Resume"
                pauseResumeItem.isHidden = false
            } else {
                pauseResumeItem.isHidden = true
            }
        }

        updateStatusIcon()
    }

    // MARK: - Actions

    @objc private func toggleExecutor() {
        let state = executorManager.state.status
        if state == .running || state == .paused {
            executorManager.stop()
        } else {
            executorManager.start()
        }
    }

    @objc private func togglePause() {
        let state = executorManager.state.status
        if state == .running {
            executorManager.pause()
        } else if state == .paused {
            executorManager.resume()
        }
    }

    @objc private func refreshQueue() {
        // Trigger immediate polling
        NotificationCenter.default.post(name: NSNotification.Name("RefreshQueue"), object: nil)
    }

    @objc private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.title.contains("ZephyrOS") }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func showSettings() {
        showMainWindow()
        // Post notification to switch to settings tab
        NotificationCenter.default.post(name: NSNotification.Name("ShowSettings"), object: nil)
    }

    @objc private func quit() {
        executorManager.stop()
        NSApp.terminate(nil)
    }

    @objc private func executorStateChanged() {
        updateMenu()
    }
}

// MARK: - Menu Item Tags

private enum MenuItemTag: Int {
    case status = 100
    case activeTasks = 101
    case startStop = 200
    case pauseResume = 201
}
