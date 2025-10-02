//
//  ExecutorConfigurationView.swift
//  ZephyrOS Executor
//
//  Configuration page for executor device settings - Edit Only Mode
//  One device per machine, auto-registered on first launch
//

import SwiftUI

struct ExecutorConfigurationView: View {
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @StateObject private var workspaceManager = WorkspaceManager.shared
    @State private var deviceName: String = ""
    @State private var rootWorkspacePath: String = ""
    @State private var maxConcurrentWorkspaces: Int = 5
    @State private var maxDiskUsageGb: Int = 100
    @State private var defaultShell: String = "/bin/zsh"
    @State private var defaultTimeoutMinutes: Int = 60
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var showPathPicker = false
    @State private var hasUnsavedChanges = false
    var showBackButton: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with back button (only when navigating from dashboard)
                if showBackButton {
                    HStack {
                        Button(action: { dismiss() }) {
                            Label("Back", systemImage: "chevron.left")
                        }
                        .buttonStyle(.borderless)

                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                }

                // Header
                VStack(spacing: 8) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)

                    Text("Executor Configuration")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Configure your executor device settings")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, showBackButton ? 8 : 32)

                Divider()

                // Loading or Device Info
                if workspaceManager.currentDevice == nil {
                    // Still loading/initializing
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Initializing executor device...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("This device will be automatically registered")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(40)
                } else {
                    // Device loaded - show configuration
                    deviceInfoSection
                    Divider()
                    deviceConfigurationSection
                    Divider()
                    workspaceSettingsSection
                    Divider()
                    advancedSettingsSection

                    // Save Button
                    HStack {
                        Spacer()

                        Button(action: saveConfiguration) {
                            if isSaving {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .padding(.horizontal, 20)
                            } else {
                                Label("Save Configuration", systemImage: "checkmark.circle")
                                    .padding(.horizontal, 20)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isSaving || !hasUnsavedChanges)
                        .controlSize(.large)

                        Spacer()
                    }
                    .padding(.vertical, 24)

                    if hasUnsavedChanges {
                        Text("You have unsaved changes")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding(24)
        }
        .frame(maxWidth: 800)
        .onAppear {
            loadCurrentConfiguration()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert("Success", isPresented: $showSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Configuration saved successfully!")
        }
        .fileImporter(
            isPresented: $showPathPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    rootWorkspacePath = url.path
                    hasUnsavedChanges = true
                }
            case .failure(let error):
                errorMessage = "Failed to select path: \(error.localizedDescription)"
                showError = true
            }
        }
    }

    // MARK: - Sections

    private var deviceInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Device Information")
                .font(.headline)

            VStack(spacing: 8) {
                infoRow(label: "Device ID", value: workspaceManager.currentDevice?.deviceId ?? "Unknown", icon: "number")
                infoRow(label: "Platform", value: workspaceManager.currentDevice?.platform ?? "Unknown", icon: "desktopcomputer")
                infoRow(label: "Status", value: workspaceManager.currentDevice?.status.rawValue.capitalized ?? "Unknown", icon: "circle.fill", valueColor: statusColor(workspaceManager.currentDevice?.status ?? .inactive))
                infoRow(label: "Online", value: (workspaceManager.currentDevice?.isOnline ?? false) ? "Yes" : "No", icon: "wifi", valueColor: (workspaceManager.currentDevice?.isOnline ?? false) ? .green : .red)
                infoRow(label: "Heartbeat", value: workspaceManager.isHeartbeatActive ? "Active" : "Inactive", icon: "heart.fill", valueColor: workspaceManager.isHeartbeatActive ? .green : .orange)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)

            Text("This device is automatically managed. Only one device is allowed per machine.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
    }

    private var deviceConfigurationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Device Configuration")
                .font(.headline)

            VStack(spacing: 16) {
                HStack {
                    Text("Device Name:")
                        .frame(width: 180, alignment: .trailing)
                    TextField("e.g., MacBook Pro - Dev", text: $deviceName)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: deviceName) { _ in hasUnsavedChanges = true }
                }

                HStack(alignment: .top) {
                    Text("Root Workspace Path:")
                        .frame(width: 180, alignment: .trailing)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            TextField("e.g., /Users/name/.zephyros/workspaces", text: $rootWorkspacePath)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: rootWorkspacePath) { _ in hasUnsavedChanges = true }

                            Button(action: { showPathPicker = true }) {
                                Image(systemName: "folder")
                            }
                        }

                        Text("Directory where workspaces will be created")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private var workspaceSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Workspace Settings")
                .font(.headline)

            VStack(spacing: 16) {
                HStack {
                    Text("Max Concurrent Workspaces:")
                        .frame(width: 180, alignment: .trailing)

                    HStack {
                        Stepper("\(maxConcurrentWorkspaces)", value: $maxConcurrentWorkspaces, in: 1...20)
                            .frame(width: 120)
                            .onChange(of: maxConcurrentWorkspaces) { _ in hasUnsavedChanges = true }

                        Text("workspace\(maxConcurrentWorkspaces == 1 ? "" : "s")")
                            .foregroundColor(.secondary)
                    }
                }

                HStack {
                    Text("Max Disk Usage:")
                        .frame(width: 180, alignment: .trailing)

                    HStack {
                        Stepper("\(maxDiskUsageGb) GB", value: $maxDiskUsageGb, in: 10...1000, step: 10)
                            .frame(width: 150)
                            .onChange(of: maxDiskUsageGb) { _ in hasUnsavedChanges = true }

                        Text("per workspace")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private var advancedSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Advanced Settings")
                .font(.headline)

            VStack(spacing: 16) {
                HStack {
                    Text("Default Shell:")
                        .frame(width: 180, alignment: .trailing)

                    Picker("", selection: $defaultShell) {
                        Text("/bin/zsh").tag("/bin/zsh")
                        Text("/bin/bash").tag("/bin/bash")
                        Text("/bin/sh").tag("/bin/sh")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 300)
                    .onChange(of: defaultShell) { _ in hasUnsavedChanges = true }
                }

                HStack {
                    Text("Default Timeout:")
                        .frame(width: 180, alignment: .trailing)

                    HStack {
                        Stepper("\(defaultTimeoutMinutes) min", value: $defaultTimeoutMinutes, in: 5...240, step: 5)
                            .frame(width: 150)
                            .onChange(of: defaultTimeoutMinutes) { _ in hasUnsavedChanges = true }

                        Text("execution timeout")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private func infoRow(label: String, value: String, icon: String, valueColor: Color = .primary) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(valueColor)
        }
    }

    // MARK: - Actions

    private func loadCurrentConfiguration() {
        guard let device = workspaceManager.currentDevice else {
            // Will auto-load when device is registered
            return
        }

        deviceName = device.deviceName
        rootWorkspacePath = device.rootWorkspacePath
        maxConcurrentWorkspaces = device.maxConcurrentWorkspaces
        maxDiskUsageGb = device.maxDiskUsageGb
        defaultShell = device.defaultShell
        defaultTimeoutMinutes = device.defaultTimeoutMinutes
        hasUnsavedChanges = false
    }

    private func saveConfiguration() {
        _Concurrency.Task {
            isSaving = true
            defer { isSaving = false }

            do {
                _ = try await workspaceManager.updateDeviceConfiguration(
                    deviceName: deviceName,
                    rootPath: rootWorkspacePath,
                    maxConcurrent: maxConcurrentWorkspaces,
                    maxDiskUsage: maxDiskUsageGb,
                    defaultShell: defaultShell,
                    defaultTimeout: defaultTimeoutMinutes
                )

                await MainActor.run {
                    hasUnsavedChanges = false
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    private func statusColor(_ status: ExecutorDevice.DeviceStatus) -> Color {
        switch status {
        case .active:
            return .green
        case .inactive:
            return .orange
        case .maintenance:
            return .yellow
        case .disabled:
            return .red
        }
    }
}

#Preview {
    ExecutorConfigurationView()
}
