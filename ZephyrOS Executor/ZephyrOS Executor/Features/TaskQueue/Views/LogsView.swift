//
//  LogsView.swift
//  ZephyrOS Executor
//
//  Execution logs view
//

import SwiftUI

struct LogsView: View {
    @EnvironmentObject var executorManager: ExecutorManager
    @State private var selectedLevel: LogLevel? = nil
    @State private var searchText = ""
    @State private var autoScroll = true

    var filteredLogs: [LogEntry] {
        executorManager.logs
            .filter { entry in
                // Filter by level
                if let selectedLevel = selectedLevel, entry.level != selectedLevel {
                    return false
                }
                // Filter by search text
                if !searchText.isEmpty && !entry.message.localizedCaseInsensitiveContains(searchText) {
                    return false
                }
                return true
            }
            .reversed() // Show newest first
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            LogsHeader(selectedLevel: $selectedLevel, searchText: $searchText, autoScroll: $autoScroll)
                .padding()

            Divider()

            // Logs list
            if filteredLogs.isEmpty {
                EmptyStateView(
                    icon: "doc.text",
                    message: "No logs",
                    description: searchText.isEmpty ? "Logs will appear here as the executor runs" : "No logs match your filters"
                )
                .frame(maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(filteredLogs) { entry in
                                LogRow(entry: entry)
                                    .id(entry.id)
                            }
                        }
                    }
                    .onChange(of: executorManager.logs.count) { _ in
                        if autoScroll, let lastLog = filteredLogs.first {
                            withAnimation {
                                proxy.scrollTo(lastLog.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct LogsHeader: View {
    @EnvironmentObject var executorManager: ExecutorManager
    @Binding var selectedLevel: LogLevel?
    @Binding var searchText: String
    @Binding var autoScroll: Bool

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Execution Logs")
                    .font(.system(size: 28, weight: .bold))

                Spacer()

                // Auto-scroll toggle
                Toggle("Auto-scroll", isOn: $autoScroll)
                    .toggleStyle(.switch)

                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search logs...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .frame(width: 250)
            }

            // Level filters
            HStack(spacing: 8) {
                LogLevelButton(
                    title: "All",
                    isSelected: selectedLevel == nil,
                    action: { selectedLevel = nil }
                )

                ForEach([LogLevel.info, LogLevel.warning, LogLevel.error], id: \.self) { level in
                    LogLevelButton(
                        title: level.rawValue,
                        color: level.color,
                        isSelected: selectedLevel == level,
                        action: { selectedLevel = level }
                    )
                }

                Spacer()

                // Clear logs button
                Button(action: {
                    executorManager.logs.removeAll()
                }) {
                    Label("Clear", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .disabled(executorManager.logs.isEmpty)
            }
        }
    }
}

struct LogLevelButton: View {
    let title: String
    var color: Color?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? (color ?? Color.blue) : Color(nsColor: .controlBackgroundColor))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

struct LogRow: View {
    let entry: LogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Timestamp
            Text(entry.formattedTime)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .leading)

            // Level badge
            Text(entry.level.rawValue)
                .font(.system(.caption2, design: .monospaced))
                .fontWeight(.semibold)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(entry.level.color.opacity(0.2))
                )
                .foregroundColor(entry.level.color)
                .frame(width: 70)

            // Message
            Text(entry.message)
                .font(.system(.callout, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(entry.level == .error ? Color.red.opacity(0.05) : Color.clear)
    }
}
