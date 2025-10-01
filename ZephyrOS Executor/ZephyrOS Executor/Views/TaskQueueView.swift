//
//  TaskQueueView.swift
//  ZephyrOS Executor
//
//  Task queue management view
//

import SwiftUI

struct TaskQueueView: View {
    @EnvironmentObject var executorManager: ExecutorManager
    @State private var selectedFilter: TaskFilter = .all
    @State private var searchText = ""

    var filteredTasks: [Task] {
        let filtered = executorManager.tasks.filter { task in
            // Apply status filter
            switch selectedFilter {
            case .all:
                return true
            case .pending:
                return task.status == .pending || task.status == .accepted
            case .inProgress:
                return task.status == .inProgress
            case .completed:
                return task.status == .completed
            case .failed:
                return task.status == .failed
            }
        }

        // Apply search filter
        if searchText.isEmpty {
            return filtered
        } else {
            return filtered.filter { task in
                task.description.localizedCaseInsensitiveContains(searchText) ||
                task.id.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            TaskQueueHeader(selectedFilter: $selectedFilter, searchText: $searchText)
                .padding()

            Divider()

            // Task list
            if filteredTasks.isEmpty {
                EmptyStateView(
                    icon: "tray",
                    message: "No tasks found",
                    description: searchText.isEmpty ? "Tasks will appear here when they are received" : "No tasks match your search"
                )
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredTasks) { task in
                            TaskRow(task: task)
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct TaskQueueHeader: View {
    @Binding var selectedFilter: TaskFilter
    @Binding var searchText: String

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Task Queue")
                    .font(.system(size: 28, weight: .bold))

                Spacer()

                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search tasks...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .frame(width: 250)
            }

            // Filters
            HStack(spacing: 8) {
                ForEach(TaskFilter.allCases, id: \.self) { filter in
                    FilterButton(
                        title: filter.rawValue,
                        isSelected: selectedFilter == filter,
                        action: { selectedFilter = filter }
                    )
                }

                Spacer()
            }
        }
    }
}

struct FilterButton: View {
    let title: String
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
                        .fill(isSelected ? Color.blue : Color(nsColor: .controlBackgroundColor))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

struct TaskRow: View {
    let task: Task
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Main row
            HStack(spacing: 12) {
                // Status indicator
                Image(systemName: task.statusIcon)
                    .font(.system(size: 16))
                    .foregroundColor(task.statusColor)
                    .frame(width: 24)

                // Task info
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.description)
                        .font(.callout)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(task.status.rawValue.capitalized)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(task.statusColor.opacity(0.2))
                            )
                            .foregroundColor(task.statusColor)

                        Text("ID: \(task.id)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if let elapsed = task.elapsedTime {
                            Text("• \(formatDuration(elapsed))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                // Progress (for in-progress tasks)
                if task.status == .inProgress {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(task.progress)%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        ProgressView(value: Double(task.progress) / 100.0)
                            .progressViewStyle(.linear)
                            .frame(width: 100)
                    }
                }

                // Expand button
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(10)

            // Expanded details
            if isExpanded {
                TaskDetailView(task: task)
                    .padding(.top, 8)
            }
        }
    }
}

struct TaskDetailView: View {
    let task: Task

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()

            // Timestamps
            VStack(alignment: .leading, spacing: 6) {
                Text("Timeline")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                HStack {
                    Label("Created", systemImage: "clock")
                        .font(.caption)
                    Spacer()
                    Text(task.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let acceptedAt = task.acceptedAt {
                    HStack {
                        Label("Accepted", systemImage: "checkmark.circle")
                            .font(.caption)
                        Spacer()
                        Text(acceptedAt, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if let completedAt = task.completedAt {
                    HStack {
                        Label("Completed", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                        Spacer()
                        Text(completedAt, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if let failedAt = task.failedAt {
                    HStack {
                        Label("Failed", systemImage: "xmark.circle.fill")
                            .font(.caption)
                        Spacer()
                        Text(failedAt, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Context
            if !task.context.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("Context")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    ForEach(Array(task.context.keys.sorted()), id: \.self) { key in
                        HStack {
                            Text(key)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(task.context[key]?.value ?? "")")
                                .font(.caption)
                                .lineLimit(1)
                        }
                    }
                }
            }

            // Result (if completed)
            if let result = task.result {
                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("Result")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    Text(result.response)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(5)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(nsColor: .textBackgroundColor))
                        )

                    if let usage = result.usage {
                        HStack {
                            Label("\(usage.totalTokens) tokens", systemImage: "cube")
                                .font(.caption)
                            Spacer()
                            Text(String(format: "%.2fs", result.executionTimeSeconds))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            // Error (if failed)
            if let error = task.error {
                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("Error")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)

                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.red.opacity(0.1))
                        )
                }
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
    }
}

enum TaskFilter: String, CaseIterable {
    case all = "All"
    case pending = "Pending"
    case inProgress = "In Progress"
    case completed = "Completed"
    case failed = "Failed"
}

private func formatDuration(_ duration: TimeInterval) -> String {
    let minutes = Int(duration) / 60
    let seconds = Int(duration) % 60
    if minutes > 0 {
        return String(format: "%dm %ds", minutes, seconds)
    } else {
        return String(format: "%ds", seconds)
    }
}
