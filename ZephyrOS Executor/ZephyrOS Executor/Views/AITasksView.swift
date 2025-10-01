//
//  AITasksView.swift
//  ZephyrOS Executor
//
//  AI Tasks display panel
//

import SwiftUI

struct AITasksView: View {
    @EnvironmentObject var executorManager: ExecutorManager
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

            async let tasksLoad = zmemoryClient.getAITasks()
            async let agentsLoad = zmemoryClient.getAgents()
            async let simpleTasksLoad = zmemoryClient.getSimpleTasks()

            let (loadedTasks, loadedAgents, loadedSimpleTasks) = try await (tasksLoad, agentsLoad, simpleTasksLoad)

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

// MARK: - Header

struct AITasksHeader: View {
    @Binding var selectedFilter: AITaskFilter
    @Binding var selectedTab: AITaskTab
    @Binding var searchText: String
    let onRefresh: () async -> Void
    @State private var isRefreshing = false

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Task Grantor")
                        .font(.system(size: 28, weight: .bold))
                    Text("Design and assign tasks to AI agents with clear objectives")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

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

                // Refresh button
                Button(action: {
                    isRefreshing = true
                    _Concurrency.Task {
                        await onRefresh()
                        isRefreshing = false
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                        .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                }
                .buttonStyle(.plain)
                .disabled(isRefreshing)
            }

            // Tabs and filters
            HStack(spacing: 12) {
                // Tabs
                HStack(spacing: 4) {
                    ForEach(AITaskTab.allCases, id: \.self) { tab in
                        Button(action: { selectedTab = tab }) {
                            Text(tab.rawValue)
                                .font(.caption)
                                .fontWeight(selectedTab == tab ? .semibold : .regular)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(selectedTab == tab ? Color.blue : Color.clear)
                                )
                                .foregroundColor(selectedTab == tab ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )

                Divider()
                    .frame(height: 20)

                // Filters
                HStack(spacing: 8) {
                    ForEach(AITaskFilter.allCases, id: \.self) { filter in
                        FilterChip(
                            title: filter.rawValue,
                            isSelected: selectedFilter == filter,
                            action: { selectedFilter = filter }
                        )
                    }
                }

                Spacer()
            }
        }
    }
}

// MARK: - Sidebar

struct AITasksSidebar: View {
    let tasks: [AITask]
    @Binding var selectedTask: AITask?
    let isLoading: Bool
    let agents: [AIAgent]
    let simpleTasks: [SimpleTask]

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView()
                    .frame(maxHeight: .infinity)
            } else if tasks.isEmpty {
                EmptyStateView(
                    icon: "tray",
                    message: "No AI Tasks",
                    description: "AI tasks will appear here"
                )
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

// MARK: - Detail View

struct AITaskDetailView: View {
    let task: AITask
    let agent: AIAgent?
    let simpleTask: SimpleTask?
    let onStatusUpdate: (AITaskStatus) async -> Void

    @State private var isUpdating = false
    @State private var showFullObjective = false
    @State private var showFullDeliverables = false
    @State private var showFullContext = false

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
    }
}

// MARK: - Supporting Views

struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.2)))
            .foregroundColor(color)
    }
}

struct ModeBadge: View {
    let mode: AITaskMode

    var body: some View {
        Text(mode.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(mode.color.opacity(0.2)))
            .foregroundColor(mode.color)
    }
}

struct PriorityBadge: View {
    let priority: TaskPriority

    var priorityColor: Color {
        switch priority {
        case .low: return .gray
        case .normal: return .blue
        case .high: return .orange
        }
    }

    var body: some View {
        Text(priority.rawValue.capitalized)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(priorityColor.opacity(0.2)))
            .foregroundColor(priorityColor)
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.blue : Color(nsColor: .controlBackgroundColor))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

struct InfoCard: View {
    let icon: String
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(content)
                .font(.callout)
                .fontWeight(.medium)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct DetailSection: View {
    let title: String
    let icon: String
    let content: String
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.headline)

            Text(content)
                .font(.body)
                .lineLimit(isExpanded ? nil : 3)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)

            if content.count > 150 {
                Button(isExpanded ? "Show less" : "Show more") {
                    isExpanded.toggle()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
    }
}

struct GuardrailsSection: View {
    let guardrails: AITaskGuardrails

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Guardrails", systemImage: "shield")
                .font(.headline)

            VStack(spacing: 8) {
                if let costCap = guardrails.costCapUSD {
                    GuardrailRow(icon: "dollarsign.circle", label: "Cost Cap", value: "$\(String(format: "%.2f", costCap))")
                }
                if let timeCap = guardrails.timeCapMin {
                    GuardrailRow(icon: "clock", label: "Time Cap", value: "\(timeCap) min")
                }
                if let requiresApproval = guardrails.requiresHumanApproval {
                    GuardrailRow(
                        icon: requiresApproval ? "person.fill.checkmark" : "person.fill.xmark",
                        label: "Human Approval",
                        value: requiresApproval ? "Required" : "Not Required"
                    )
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
    }
}

struct GuardrailRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.callout)
            Spacer()
            Text(value)
                .font(.callout)
                .foregroundColor(.secondary)
        }
    }
}

struct TimelineSection: View {
    let task: AITask

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Timeline", systemImage: "clock")
                .font(.headline)

            VStack(spacing: 8) {
                TimelineRow(icon: "plus.circle", label: "Assigned", date: task.assignedAt)
                if let startedAt = task.startedAt {
                    TimelineRow(icon: "play.circle", label: "Started", date: startedAt)
                }
                if let completedAt = task.completedAt {
                    TimelineRow(icon: "checkmark.circle.fill", label: "Completed", date: completedAt)
                }
                if let dueAt = task.dueAt {
                    TimelineRow(icon: "bell", label: "Due", date: dueAt, isWarning: Date() > dueAt && !task.isCompleted)
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
    }
}

struct TimelineRow: View {
    let icon: String
    let label: String
    let date: Date
    var isWarning: Bool = false

    var body: some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.callout)
                .foregroundColor(isWarning ? .orange : .primary)
            Spacer()
            Text(date, style: .relative)
                .font(.callout)
                .foregroundColor(.secondary)
        }
    }
}

struct CostSection: View {
    let task: AITask

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Cost Tracking", systemImage: "dollarsign.circle")
                .font(.headline)

            HStack(spacing: 16) {
                if let estimated = task.estimatedCostUSD {
                    CostCard(title: "Estimated", amount: estimated, color: .blue)
                }
                if let actual = task.actualCostUSD {
                    CostCard(title: "Actual", amount: actual, color: .green)
                }
            }
        }
    }
}

struct CostCard: View {
    let title: String
    let amount: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text("$\(String(format: "%.4f", amount))")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct ExecutionResultSection: View {
    let result: AITaskExecutionResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Execution Result", systemImage: "terminal")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                if let output = result.output {
                    ResultBlock(title: "Output", content: output, color: .green)
                }
                if let error = result.error {
                    ResultBlock(title: "Error", content: error, color: .red)
                }
                if let logs = result.logs {
                    ResultBlock(title: "Logs", content: logs, color: .blue)
                }
            }
        }
    }
}

struct ResultBlock: View {
    let title: String
    let content: String
    let color: Color
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Text(title)
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(color)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                ScrollView {
                    Text(content)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 200)
                .padding(8)
                .background(color.opacity(0.1))
                .cornerRadius(6)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct AITaskActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let isLoading: Bool
    let action: () async -> Void

    var body: some View {
        Button(action: {
            _Concurrency.Task {
                await action()
            }
        }) {
            HStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: icon)
                }
                Text(title)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(color)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.white)
            Text(message)
                .font(.callout)
                .foregroundColor(.white)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color.red)
    }
}

// MARK: - Enums

enum AITaskFilter: String, CaseIterable {
    case all = "All"
    case planOnly = "Plan Only"
    case dryRun = "Dry Run"
    case execute = "Execute"
}

enum AITaskTab: String, CaseIterable {
    case pending = "Pending"
    case history = "History"
}

// MARK: - Setup Required View

struct SetupRequiredView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "gearshape.2")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("Configuration Required")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Please configure your ZMemory API URL in Settings to use AI Tasks")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Text("1.")
                        .fontWeight(.semibold)
                    Text("Open Settings from the sidebar")
                }
                HStack(alignment: .top, spacing: 12) {
                    Text("2.")
                        .fontWeight(.semibold)
                    Text("Enter your ZMemory API URL (e.g., http://localhost:3000)")
                }
                HStack(alignment: .top, spacing: 12) {
                    Text("3.")
                        .fontWeight(.semibold)
                    Text("Sign in with Google OAuth if not already signed in")
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
