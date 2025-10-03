//
//  DashboardView.swift
//  ZephyrOS Executor
//
//  Dashboard showing executor status and statistics
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var executorManager: ExecutorManager
    @StateObject private var workspaceManager = WorkspaceManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with title and controls
                DashboardHeader()

                // Status Card
                StatusCard()

                // Executor Device Card
                ExecutorDeviceCard()

                // Active Tasks
                ActiveTasksSection()

                // Statistics
                StatisticsSection()

                Spacer()
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct DashboardHeader: View {
    @EnvironmentObject var executorManager: ExecutorManager

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Dashboard")
                    .font(.system(size: 28, weight: .bold))
                if let lastSync = executorManager.state.lastSyncTime {
                    Text("Last sync: \(lastSync, formatter: relativeDateFormatter)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Control buttons
            HStack(spacing: 12) {
                if executorManager.state.status == .running {
                    Button(action: { executorManager.pause() }) {
                        Label("Pause", systemImage: "pause.circle.fill")
                    }
                    .buttonStyle(.bordered)
                } else if executorManager.state.status == .paused {
                    Button(action: { executorManager.resume() }) {
                        Label("Resume", systemImage: "play.circle.fill")
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button(action: { executorManager.start() }) {
                        Label("Start", systemImage: "play.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }

                if executorManager.state.status == .running || executorManager.state.status == .paused {
                    Button(action: { executorManager.stop() }) {
                        Label("Stop", systemImage: "stop.circle.fill")
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }
        }
    }
}

struct StatusCard: View {
    @EnvironmentObject var executorManager: ExecutorManager

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                // Status indicator
                HStack(spacing: 12) {
                    Image(systemName: executorManager.state.statusIcon)
                        .font(.system(size: 32))
                        .foregroundColor(executorManager.state.statusColor)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("EXECUTOR STATUS")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(executorManager.state.status.rawValue.capitalized)
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(executorManager.state.activeTasks.count) active")
                        .font(.title3)
                        .fontWeight(.medium)
                    Text("\(executorManager.state.queuedTasks.count) queued")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Connection status
            HStack(spacing: 24) {
                ConnectionStatusItem(
                    title: "ZMemory",
                    isConnected: executorManager.state.isConnectedToZMemory
                )

                ConnectionStatusItem(
                    title: "Claude API",
                    isConnected: executorManager.state.isConnectedToClaude
                )

                Spacer()
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}

struct ConnectionStatusItem: View {
    let title: String
    let isConnected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isConnected ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isConnected ? .green : .red)
            Text(title)
                .font(.callout)
        }
    }
}

struct ActiveTasksSection: View {
    @EnvironmentObject var executorManager: ExecutorManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Tasks")
                .font(.title3)
                .fontWeight(.semibold)

            if executorManager.state.activeTasks.isEmpty {
                EmptyStateView(
                    icon: "tray",
                    message: "No active tasks",
                    description: "Tasks will appear here when execution starts"
                )
                .frame(height: 120)
            } else {
                VStack(spacing: 12) {
                    ForEach(executorManager.state.activeTasks.prefix(3)) { task in
                        ActiveTaskCard(task: task)
                    }

                    if executorManager.state.activeTasks.count > 3 {
                        Text("+ \(executorManager.state.activeTasks.count - 3) more")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

struct ActiveTaskCard: View {
    let task: Task

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "circle.fill")
                    .font(.system(size: 8))
                    .foregroundColor(.blue)

                Text(task.description)
                    .font(.callout)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Spacer()

                if let elapsed = task.elapsedTime {
                    Text(formatDuration(elapsed))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Progress bar
            ProgressView(value: Double(task.progress) / 100.0)
                .progressViewStyle(.linear)
                .tint(.blue)

            Text("\(task.progress)%")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}

struct ExecutorDeviceCard: View {
    @StateObject private var workspaceManager = WorkspaceManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Executor Device", systemImage: "server.rack")
                    .font(.title3)
                    .fontWeight(.semibold)

                Spacer()

                NavigationLink(destination: ExecutorConfigurationView(showBackButton: true)) {
                    Label("Configure", systemImage: "gearshape")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }

            if let device = workspaceManager.currentDevice {
                // Device is registered
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(device.deviceName)
                                .font(.headline)
                            Text(device.deviceId)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        HStack(spacing: 16) {
                            VStack(alignment: .trailing, spacing: 2) {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(device.isOnline ? Color.green : Color.red)
                                        .frame(width: 6, height: 6)
                                    Text(device.isOnline ? "Online" : "Offline")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(workspaceManager.isHeartbeatActive ? Color.green : Color.orange)
                                        .frame(width: 6, height: 6)
                                    Text(workspaceManager.isHeartbeatActive ? "Heartbeat Active" : "No Heartbeat")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }

                    Divider()

                    HStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Workspaces")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(device.currentWorkspacesCount) / \(device.maxConcurrentWorkspaces)")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }

                        Divider()
                            .frame(height: 30)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Disk Usage")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(Int(device.currentDiskUsageGb)) / \(device.maxDiskUsageGb) GB")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }

                        Divider()
                            .frame(height: 30)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Active")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(workspaceManager.activeWorkspaces.count)")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                    }
                }
            } else {
                // Device initializing
                HStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Initializing Device...")
                            .font(.headline)
                        Text("Your executor device is being automatically registered")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    NavigationLink(destination: ExecutorConfigurationView(showBackButton: true)) {
                        Label("View Configuration", systemImage: "gearshape")
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.1))
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct StatisticsSection: View {
    @EnvironmentObject var executorManager: ExecutorManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Statistics")
                .font(.title3)
                .fontWeight(.semibold)

            HStack(spacing: 16) {
                StatCard(
                    title: "Tasks",
                    value: "\(executorManager.statistics.totalTasks)",
                    icon: "checkmark.circle",
                    color: .blue
                )

                StatCard(
                    title: "Success",
                    value: String(format: "%.0f%%", executorManager.statistics.successRate),
                    icon: "chart.line.uptrend.xyaxis",
                    color: .green
                )

                StatCard(
                    title: "Tokens",
                    value: formatNumber(executorManager.statistics.totalTokens),
                    icon: "cube",
                    color: .purple
                )

                StatCard(
                    title: "Cost",
                    value: String(format: "$%.2f", executorManager.statistics.totalCost),
                    icon: "dollarsign.circle",
                    color: .orange
                )
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}

struct EmptyStateView: View {
    let icon: String
    let message: String
    let description: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text(message)
                .font(.callout)
                .fontWeight(.medium)

            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

// MARK: - Helper Functions

private let relativeDateFormatter: RelativeDateTimeFormatter = {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter
}()

private func formatDuration(_ duration: TimeInterval) -> String {
    let minutes = Int(duration) / 60
    let seconds = Int(duration) % 60
    return String(format: "%d:%02d", minutes, seconds)
}

private func formatNumber(_ number: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
}
