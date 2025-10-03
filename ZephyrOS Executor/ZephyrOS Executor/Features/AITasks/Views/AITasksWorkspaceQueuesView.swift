//
//  AITasksWorkspaceQueuesView.swift
//  ZephyrOS Executor
//
//  View displaying pending tasks grouped by workspace (each workspace is a queue)
//

import SwiftUI

struct AITasksWorkspaceQueuesView: View {
    let tasksByWorkspace: [(workspace: ExecutorWorkspace, tasks: [AITask])]
    @Binding var selectedTask: AITask?
    let agents: [AIAgent]
    let simpleTasks: [SimpleTask]
    let onStatusUpdate: (String, AITaskStatus) async -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                ForEach(tasksByWorkspace, id: \.workspace.id) { item in
                    WorkspaceQueueSection(
                        workspace: item.workspace,
                        tasks: item.tasks,
                        selectedTask: $selectedTask,
                        agents: agents,
                        simpleTasks: simpleTasks
                    )
                }
            }
            .padding()
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct WorkspaceQueueSection: View {
    let workspace: ExecutorWorkspace
    let tasks: [AITask]
    @Binding var selectedTask: AITask?
    let agents: [AIAgent]
    let simpleTasks: [SimpleTask]

    @State private var isExpanded: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Workspace header
            Button(action: { isExpanded.toggle() }) {
                HStack(spacing: 12) {
                    // Status indicator
                    Circle()
                        .fill(workspaceStatusColor)
                        .frame(width: 10, height: 10)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(workspace.workspaceName)
                            .font(.headline)
                            .fontWeight(.semibold)

                        HStack(spacing: 8) {
                            Text(workspace.status.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text("\(tasks.count) task\(tasks.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
            }
            .buttonStyle(.plain)

            // Tasks in queue
            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                        WorkspaceQueueTaskItem(
                            task: task,
                            queuePosition: index + 1,
                            agent: agents.first(where: { $0.id == task.agentId }),
                            simpleTask: simpleTasks.first(where: { $0.id == task.taskId }),
                            isSelected: selectedTask?.id == task.id,
                            onTap: { selectedTask = task }
                        )
                    }
                }
                .padding(.leading, 20)
            }
        }
    }

    private var workspaceStatusColor: Color {
        switch workspace.status {
        case .ready, .assigned, .running:
            return .green
        case .creating, .initializing, .cloning:
            return .orange
        case .completed:
            return .blue
        case .failed:
            return .red
        case .paused:
            return .yellow
        case .archived, .cleanup:
            return .gray
        }
    }
}

struct WorkspaceQueueTaskItem: View {
    let task: AITask
    let queuePosition: Int
    let agent: AIAgent?
    let simpleTask: SimpleTask?
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Queue position
                ZStack {
                    Circle()
                        .fill(task.statusColor.opacity(0.2))
                        .frame(width: 32, height: 32)

                    Text("\(queuePosition)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(task.statusColor)
                }

                VStack(alignment: .leading, spacing: 6) {
                    // Task objective
                    Text(task.objective)
                        .font(.callout)
                        .fontWeight(.medium)
                        .lineLimit(2)

                    // Metadata
                    HStack(spacing: 8) {
                        StatusBadge(text: task.status.displayName, color: task.statusColor)
                        ModeBadge(mode: task.mode)

                        if let agent = agent {
                            Text(agent.name)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                // Status icon
                Image(systemName: task.statusIcon)
                    .foregroundColor(task.statusColor)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.gray.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
