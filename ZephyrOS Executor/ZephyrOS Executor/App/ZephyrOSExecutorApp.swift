//
//  ZephyrOSExecutorApp.swift
//  ZephyrOS Executor
//
//  Main app entry point with menu bar integration
//

import SwiftUI

@main
struct ZephyrOSExecutorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var executorManager = ExecutorManager.shared
    @StateObject private var workspaceManager = WorkspaceManager.shared

    init() {
        // Load environment variables from .env file
        Environment.loadDotEnv()
    }

    var body: some Scene {
        WindowGroup {
            if executorManager.isAuthenticated {
                ContentView()
                    .environmentObject(executorManager)
                    .frame(minWidth: 900, minHeight: 600)
                    .onAppear {
                        initializeExecutorDevice()
                    }
            } else {
                LoginView(isAuthenticated: $executorManager.isAuthenticated)
                    .environmentObject(executorManager)
                    .frame(width: 500, height: 600)
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        Settings {
            SettingsView()
                .environmentObject(executorManager)
        }
    }

    // MARK: - Executor Device Initialization

    private func initializeExecutorDevice() {
        _Concurrency.Task {
            do {
                let device = try await workspaceManager.ensureDeviceRegistered()
                print("✅ Executor device registered: \(device.deviceName) (\(device.id))")
                print("📂 Root workspace path: \(device.rootWorkspacePath)")
                print("💚 Heartbeat active: \(workspaceManager.isHeartbeatActive)")
            } catch {
                print("⚠️ Failed to register executor device: \(error)")
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem?
    var menuBarManager: MenuBarManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize menu bar
        menuBarManager = MenuBarManager()

        // Hide dock icon (optional - can be toggled in settings)
        // NSApp.setActivationPolicy(.accessory)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep app running even if main window is closed
        return false
    }
}
