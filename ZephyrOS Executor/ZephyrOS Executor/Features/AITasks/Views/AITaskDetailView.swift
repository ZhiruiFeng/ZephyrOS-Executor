//
//  AITaskDetailView.swift
//  ZephyrOS Executor
//
//  Detail view component for AI Tasks
//

import SwiftUI

struct AITaskDetailView: View {
    let task: AITask
    let agent: AIAgent?
    let simpleTask: SimpleTask?
    let onStatusUpdate: (AITaskStatus) async -> Void

    @StateObject private var workspaceManager = WorkspaceManager.shared
    @State private var isUpdating = false
    @State private var showFullObjective = false
    @State private var showFullDeliverables = false
    @State private var showFullContext = false
    @State private var workspace: ExecutorWorkspace?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: task.statusIcon)
                            .font(.title)
                            .foregroundColor(task.statusColor)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(task.objective)
                                .font(.title2)
                                .fontWeight(.bold)

                            HStack(spacing: 8) {
                                StatusBadge(text: task.status.displayName, color: task.statusColor)
                                ModeBadge(mode: task.mode)
                                if let priority = task.metadata?.priority {
                                    PriorityBadge(priority: priority)
                                }
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            // Workspace status
                            if let workspace = workspace {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(workspaceStatusColor(workspace.status))
                                        .frame(width: 6, height: 6)
                                    Text(workspace.status.rawValue)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }

                    // Status actions
                    if task.status == .pending || task.status == .assigned {
                        HStack(spacing: 8) {
                            AITaskActionButton(
                                title: "Start",
                                icon: "play.fill",
                                color: .blue,
                                isLoading: isUpdating
                            ) {
                                isUpdating = true
                                await onStatusUpdate(.inProgress)
                                isUpdating = false
                            }

                            AITaskActionButton(
                                title: "Cancel",
                                icon: "xmark",
                                color: .red,
                                isLoading: isUpdating
                            ) {
                                isUpdating = true
                                await onStatusUpdate(.cancelled)
                                isUpdating = false
                            }
                        }
                    } else if task.status == .inProgress {
                        HStack(spacing: 8) {
                            AITaskActionButton(
                                title: "Pause",
                                icon: "pause.fill",
                                color: .orange,
                                isLoading: isUpdating
                            ) {
                                isUpdating = true
                                await onStatusUpdate(.paused)
                                isUpdating = false
                            }

                            AITaskActionButton(
                                title: "Complete",
                                icon: "checkmark",
                                color: .green,
                                isLoading: isUpdating
                            ) {
                                isUpdating = true
                                await onStatusUpdate(.completed)
                                isUpdating = false
                            }

                            AITaskActionButton(
                                title: "Fail",
                                icon: "xmark.circle",
                                color: .red,
                                isLoading: isUpdating
                            ) {
                                isUpdating = true
                                await onStatusUpdate(.failed)
                                isUpdating = false
                            }
                        }
                    } else if task.status == .paused {
                        AITaskActionButton(
                            title: "Resume",
                            icon: "play.fill",
                            color: .blue,
                            isLoading: isUpdating
                        ) {
                            isUpdating = true
                            await onStatusUpdate(.inProgress)
                            isUpdating = false
                        }
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)

                // Agent & Task Info
                HStack(spacing: 16) {
                    if let agent = agent {
                        InfoCard(icon: "cpu", title: "Agent", content: agent.name)
                    }
                    if let simpleTask = simpleTask {
                        InfoCard(icon: "list.bullet", title: "Task", content: simpleTask.title)
                    }
                    InfoCard(icon: "tag", title: "Type", content: task.taskType)
                }

                // Deliverables
                if let deliverables = task.deliverables, !deliverables.isEmpty {
                    DetailSection(
                        title: "Deliverables",
                        icon: "checkmark.square",
                        content: deliverables,
                        isExpanded: $showFullDeliverables
                    )
                }

                // Context
                if let context = task.context, !context.isEmpty {
                    DetailSection(
                        title: "Context",
                        icon: "text.alignleft",
                        content: context,
                        isExpanded: $showFullContext
                    )
                }

                // Acceptance Criteria
                if let criteria = task.acceptanceCriteria, !criteria.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Acceptance Criteria", systemImage: "checklist")
                            .font(.headline)
                        Text(criteria)
                            .font(.body)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(8)
                    }
                }

                // Guardrails
                if let guardrails = task.guardrails {
                    GuardrailsSection(guardrails: guardrails)
                }

                // Timeline
                TimelineSection(task: task)

                // Cost tracking
                if task.estimatedCostUSD != nil || task.actualCostUSD != nil {
                    CostSection(task: task)
                }

                // Execution Result
                if let result = task.executionResult {
                    ExecutionResultSection(result: result)
                }
            }
            .padding()
        }
        .onAppear {
            loadWorkspace()
        }
    }

    // MARK: - Actions

    private func loadWorkspace() {
        // Find existing workspace for this task
        // Note: This is a simplified lookup. In production, you should query workspace tasks
        // to find the workspace assigned to this AI task via ExecutorWorkspaceTask
        workspace = workspaceManager.activeWorkspaces.first(where: { $0.agentId == task.agentId })
    }

    private func workspaceStatusColor(_ status: ExecutorWorkspace.WorkspaceStatus) -> Color {
        switch status {
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
