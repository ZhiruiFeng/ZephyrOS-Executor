//
//  AITasksSidebar.swift
//  ZephyrOS Executor
//
//  Sidebar component for AI Tasks view
//

import SwiftUI

struct AITasksSidebar: View {
    let tasks: [AITask]
    @Binding var selectedTask: AITask?
    let isLoading: Bool
    let agents: [AIAgent]
    let simpleTasks: [SimpleTask]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Unassigned Tasks")
                    .font(.headline)
                    .foregroundColor(.secondary)

                Spacer()

                if !tasks.isEmpty {
                    Text("\(tasks.count)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.secondary.opacity(0.2))
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))

            Divider()

            if isLoading {
                ProgressView()
                    .frame(maxHeight: .infinity)
            } else if tasks.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No unassigned tasks")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(tasks) { task in
                            AITaskListItem(
                                task: task,
                                agent: agents.first(where: { $0.id == task.agentId }),
                                isSelected: selectedTask?.id == task.id,
                                action: { selectedTask = task }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
    }
}

struct AITaskListItem: View {
    let task: AITask
    let agent: AIAgent?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack {
                    Image(systemName: task.statusIcon)
                        .foregroundColor(task.statusColor)

                    Text(task.objective)
                        .font(.callout)
                        .fontWeight(.medium)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Details
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        StatusBadge(text: task.status.displayName, color: task.statusColor)
                        ModeBadge(mode: task.mode)
                    }

                    if let agent = agent {
                        Label(agent.name, systemImage: "cpu")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text(task.assignedAt, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}
