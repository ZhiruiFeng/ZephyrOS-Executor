//
//  AITasksHistoryView.swift
//  ZephyrOS Executor
//
//  History view for completed/failed/cancelled AI tasks - displayed as cards
//

import SwiftUI

struct AITasksHistoryView: View {
    let tasks: [AITask]
    @Binding var selectedTask: AITask?
    let isLoading: Bool
    let agents: [AIAgent]
    let simpleTasks: [SimpleTask]
    let onStatusUpdate: (String, AITaskStatus) async -> Void

    var body: some View {
        if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if tasks.isEmpty {
            EmptyStateView(
                icon: "clock.arrow.circlepath",
                message: "No Historical Tasks",
                description: "Completed, failed, and cancelled tasks will appear here"
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 350, maximum: 500), spacing: 16)
                ], spacing: 16) {
                    ForEach(tasks) { task in
                        AITaskHistoryCard(
                            task: task,
                            agent: agents.first(where: { $0.id == task.agentId }),
                            simpleTask: simpleTasks.first(where: { $0.id == task.taskId }),
                            isSelected: selectedTask?.id == task.id,
                            onTap: { selectedTask = task }
                        )
                    }
                }
                .padding()
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }
}

struct AITaskHistoryCard: View {
    let task: AITask
    let agent: AIAgent?
    let simpleTask: SimpleTask?
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            cardContent
        }
        .buttonStyle(.plain)
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerSection
            Divider()
            detailsSection

            if task.executionResult != nil {
                Divider()
                resultSection
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private var headerSection: some View {
        HStack(alignment: .top) {
            Image(systemName: task.statusIcon)
                .font(.title2)
                .foregroundColor(task.statusColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.objective)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                badgesSection
            }

            Spacer()
        }
    }

    private var badgesSection: some View {
        HStack(spacing: 6) {
            StatusBadge(text: task.status.displayName, color: task.statusColor)
            ModeBadge(mode: task.mode)
            if let priority = task.metadata?.priority {
                PriorityBadge(priority: priority)
            }
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let agent = agent {
                HStack(spacing: 6) {
                    Image(systemName: "cpu")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(agent.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if let simpleTask = simpleTask {
                HStack(spacing: 6) {
                    Image(systemName: "list.bullet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(simpleTask.title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            HStack {
                Label(task.assignedAt.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if let completedAt = task.completedAt {
                    Text(completedAt, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var resultSection: some View {
        Group {
            if let result = task.executionResult {
                let isSuccess = result.error == nil || result.error?.isEmpty == true
                HStack(spacing: 4) {
                    Image(systemName: isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(isSuccess ? .green : .red)
                    Text(isSuccess ? "Successful" : "Failed")
                        .font(.caption)
                        .foregroundColor(isSuccess ? .green : .red)

                    if let cost = task.actualCostUSD {
                        Spacer()
                        Text(String(format: "$%.4f", cost))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}
