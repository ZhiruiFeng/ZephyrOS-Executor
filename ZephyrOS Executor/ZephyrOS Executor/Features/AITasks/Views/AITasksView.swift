//
//  AITasksView.swift
//  ZephyrOS Executor
//
//  AI Tasks display panel
//

import SwiftUI

struct AITasksView: View {
    @EnvironmentObject var executorManager: ExecutorManager
    @StateObject private var workspaceManager = WorkspaceManager.shared
    @State private var aiTasks: [AITask] = []
    @State private var agents: [AIAgent] = []
    @State private var tasks: [SimpleTask] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedFilter: AITaskFilter = .all
    @State private var selectedTab: AITaskTab = .pending
    @State private var searchText = ""
    @State private var selectedTask: AITask?

    var filteredTasks: [AITask] {
        let tabFiltered: [AITask]

        switch selectedTab {
        case .pending:
            tabFiltered = aiTasks.filter {
                $0.status == .pending || $0.status == .assigned || $0.status == .inProgress
            }
        case .history:
            tabFiltered = aiTasks.filter {
                $0.status == .completed || $0.status == .failed || $0.status == .cancelled
            }
        }

        let filtered = tabFiltered.filter { task in
            switch selectedFilter {
            case .all:
                return true
            case .planOnly:
                return task.mode == .planOnly
            case .dryRun:
                return task.mode == .dryRun
            case .execute:
                return task.mode == .execute
            }
        }

        if searchText.isEmpty {
            return filtered
        } else {
            return filtered.filter { task in
                task.objective.localizedCaseInsensitiveContains(searchText) ||
                task.id.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            AITasksHeader(
                selectedFilter: $selectedFilter,
                selectedTab: $selectedTab,
                searchText: $searchText,
                onRefresh: loadData
            )
            .padding()

            Divider()

            // Content
            HStack(spacing: 0) {
                // Sidebar - Task List
                AITasksSidebar(
                    tasks: filteredTasks,
                    selectedTask: $selectedTask,
                    isLoading: isLoading,
                    agents: agents,
                    simpleTasks: tasks
                )
                .frame(width: 320)

                Divider()

                // Detail View
                if executorManager.getZMemoryClient() == nil {
                    SetupRequiredView()
                } else if let selectedTask = selectedTask {
                    AITaskDetailView(
                        task: selectedTask,
                        agent: agents.first(where: { $0.id == selectedTask.agentId }),
                        simpleTask: tasks.first(where: { $0.id == selectedTask.taskId }),
                        onStatusUpdate: { status in
                            await updateTaskStatus(id: selectedTask.id, status: status)
                        }
                    )
                } else {
                    EmptyStateView(
                        icon: "sparkles",
                        message: "Select an AI Task",
                        description: "Choose a task from the sidebar to view details"
                    )
                }
            }

            if let error = errorMessage {
                ErrorBanner(message: error) {
                    errorMessage = nil
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            _Concurrency.Task {
                await loadData()
            }
        }
    }

    private func loadData() async {
        isLoading = true
        errorMessage = nil

        do {
            guard let zmemoryClient = executorManager.getZMemoryClient() else {
                errorMessage = "Not connected to ZMemory. Please check your settings and sign in with Google."
                isLoading = false
                return
            }

            let loadedTasks = try await zmemoryClient.getAITasks()

            let loadedAgents: [AIAgent]
            do {
                loadedAgents = try await zmemoryClient.getAgents()
            } catch {
                print("🔍 Warning: Failed to load AI agents: \(error)")
                loadedAgents = []
            }

            let loadedSimpleTasks: [SimpleTask]
            do {
                loadedSimpleTasks = try await zmemoryClient.getSimpleTasks()
            } catch {
                print("🔍 Warning: Failed to load simple tasks: \(error)")
                loadedSimpleTasks = []
            }

            aiTasks = loadedTasks
            agents = loadedAgents
            tasks = loadedSimpleTasks
        } catch let error as APIError {
            switch error {
            case .unauthorized:
                errorMessage = "Unauthorized: Please ensure you're signed in with Google OAuth"
            default:
                errorMessage = "Failed to load AI tasks: \(error.localizedDescription)"
            }
        } catch {
            errorMessage = "Failed to load AI tasks: \(error.localizedDescription)"
        }

        isLoading = false
    }

    private func updateTaskStatus(id: String, status: AITaskStatus) async {
        do {
            guard let zmemoryClient = executorManager.getZMemoryClient() else {
                throw APIError.unauthorized
            }

            try await zmemoryClient.updateAITaskStatus(id: id, status: status)
            await loadData()
        } catch {
            errorMessage = "Failed to update task: \(error.localizedDescription)"
        }
    }
}
