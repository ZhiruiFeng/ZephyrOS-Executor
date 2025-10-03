//
//  WorkspaceManagementView.swift
//  ZephyrOS Executor
//
//  Workspace management page for creating and managing agent workspaces
//

import SwiftUI

struct WorkspaceManagementView: View {
    @StateObject private var workspaceManager = WorkspaceManager.shared
    @State private var showCreateWorkspace = false
    @State private var selectedWorkspace: ExecutorWorkspace?
    @State private var isLoadingWorkspaces = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Agent Workspaces")
                        .font(.system(size: 28, weight: .bold))
                    Text("Create and manage isolated workspaces for agents")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isLoadingWorkspaces {
                    ProgressView()
                        .scaleEffect(0.8)
                }

                Button(action: { loadWorkspaces() }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)

                Button(action: { showCreateWorkspace = true }) {
                    Label("Create Workspace", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(24)

            Divider()

            // Workspace List
            ScrollView {
                if isLoadingWorkspaces && workspaceManager.activeWorkspaces.isEmpty {
                    // Loading state
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Loading workspaces...")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(60)
                } else if workspaceManager.activeWorkspaces.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)

                        Text("No Active Workspaces")
                            .font(.title3)
                            .fontWeight(.semibold)

                        Text("Create a new workspace to start running agent tasks")
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Button(action: { showCreateWorkspace = true }) {
                            Label("Create Your First Workspace", systemImage: "plus.circle")
                                .padding(.horizontal, 20)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(60)
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(workspaceManager.activeWorkspaces) { workspace in
                            WorkspaceCard(workspace: workspace) {
                                selectedWorkspace = workspace
                            }
                        }
                    }
                    .padding(24)
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            loadWorkspaces()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showCreateWorkspace) {
            CreateWorkspaceSheet()
        }
        .sheet(item: $selectedWorkspace) { workspace in
            WorkspaceDetailSheet(workspace: workspace)
        }
    }

    private func loadWorkspaces() {
        _Concurrency.Task {
            isLoadingWorkspaces = true
            defer { isLoadingWorkspaces = false }

            do {
                print("🔄 Loading workspaces from backend...")
                try await workspaceManager.refreshActiveWorkspaces()
                print("✅ Loaded \(workspaceManager.activeWorkspaces.count) workspaces")
            } catch {
                print("❌ Failed to load workspaces: \(error)")
                await MainActor.run {
                    errorMessage = "Failed to load workspaces: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
}

struct WorkspaceCard: View {
    let workspace: ExecutorWorkspace
    let onTap: () -> Void
    @State private var agentName: String?
    @State private var isLoadingAgent = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    // Status indicator
                    Circle()
                        .fill(statusColor(workspace.status))
                        .frame(width: 12, height: 12)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(workspace.workspaceName)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        if let repoUrl = workspace.repoUrl {
                            Text(repoUrl)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        } else {
                            Text("ID: \(workspace.id.prefix(8))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(workspace.status.rawValue.capitalized)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(statusColor(workspace.status))

                        Text("\(workspace.progressPercentage)%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                // Progress bar
                ProgressView(value: Double(workspace.progressPercentage) / 100.0)
                    .progressViewStyle(.linear)
                    .tint(statusColor(workspace.status))

                Divider()

                // Workspace info
                HStack(spacing: 24) {
                    if isLoadingAgent {
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.6)
                            Text("Loading agent...")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    } else {
                        Label("Agent: \(agentName ?? workspace.agentId.prefix(8).description)", systemImage: "person.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Label(workspace.repoBranch, systemImage: "arrow.branch")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onAppear {
            loadAgentName()
        }
    }

    private func loadAgentName() {
        guard !workspace.agentId.isEmpty else { return }

        _Concurrency.Task {
            isLoadingAgent = true
            defer { isLoadingAgent = false }

            do {
                guard let client = ExecutorManager.shared.getZMemoryClient() else { return }
                let agents = try await client.getAgents(isActive: true, limit: 1000)
                if let agent = agents.first(where: { $0.id == workspace.agentId }) {
                    await MainActor.run {
                        agentName = agent.name
                    }
                }
            } catch {
                print("❌ Failed to load agent name: \(error)")
            }
        }
    }

    private func statusColor(_ status: ExecutorWorkspace.WorkspaceStatus) -> Color {
        switch status {
        case .ready, .assigned, .completed:
            return .green
        case .running:
            return .blue
        case .creating, .initializing, .cloning:
            return .orange
        case .paused:
            return .yellow
        case .failed:
            return .red
        case .archived, .cleanup:
            return .secondary
        }
    }
}

struct CreateWorkspaceSheet: View {
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @StateObject private var workspaceManager = WorkspaceManager.shared

    // Basic fields
    @State private var agentId: String = ""
    @State private var availableAgents: [AIAgent] = []
    @State private var selectedAgent: AIAgent?
    @State private var isLoadingAgents = false
    @State private var workspaceName: String = ""
    @State private var workspacePath: String = ""
    @State private var projectName: String = ""
    @State private var projectType: String = ""

    // Repository fields
    @State private var repoUrl: String = ""
    @State private var repoBranch: String = "main"

    @State private var showPathPicker = false

    // Configuration fields
    @State private var executionTimeoutMinutes: Int = 60
    @State private var maxDiskUsageMb: Int = 10240
    @State private var enableNetwork: Bool = true
    @State private var enableGit: Bool = true

    // Advanced fields
    @State private var systemPrompt: String = ""
    @State private var allowedCommands: String = ""
    @State private var environmentVars: String = ""

    @State private var isCreating = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showAdvanced = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Create New Workspace")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            .padding(24)

            Divider()

            // Scrollable Form
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Basic Information Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Basic Information")
                            .font(.headline)
                            .foregroundColor(.primary)

                        AgentSelectionField(
                            agentId: $agentId,
                            selectedAgent: $selectedAgent,
                            availableAgents: availableAgents,
                            isLoadingAgents: isLoadingAgents
                        )

                        FormField(
                            label: "Workspace Name",
                            placeholder: "My Workspace",
                            text: $workspaceName,
                            required: true,
                            description: "Unique name for this workspace (leave empty to auto-generate from project name or repo)"
                        )

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Workspace Path")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("*")
                                    .foregroundColor(.red)
                            }

                            HStack(spacing: 8) {
                                TextField("e.g., /path/to/workspace or leave empty for auto", text: $workspacePath)
                                    .textFieldStyle(.roundedBorder)

                                Button(action: { showPathPicker = true }) {
                                    Image(systemName: "folder")
                                }
                            }

                            Text("Directory path for this workspace. Leave empty to auto-generate under device root path.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        FormField(
                            label: "Project Name",
                            placeholder: "My Project",
                            text: $projectName,
                            description: "Human-readable name for this workspace"
                        )

                        FormField(
                            label: "Project Type",
                            placeholder: "e.g., python, nodejs, rust",
                            text: $projectType,
                            description: "Type of project (optional)"
                        )
                    }
                    .padding(16)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)

                    // Repository Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Repository Settings")
                            .font(.headline)
                            .foregroundColor(.primary)

                        FormField(
                            label: "Repository URL",
                            placeholder: "https://github.com/user/repo.git",
                            text: $repoUrl,
                            description: "Git repository to clone (optional)"
                        )

                        FormField(
                            label: "Branch",
                            placeholder: "main",
                            text: $repoBranch,
                            description: "Git branch to checkout"
                        )
                    }
                    .padding(16)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)

                    // Configuration Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Configuration")
                            .font(.headline)
                            .foregroundColor(.primary)

                        HStack {
                            Text("Execution Timeout:")
                                .frame(width: 180, alignment: .trailing)

                            Stepper("\(executionTimeoutMinutes) min", value: $executionTimeoutMinutes, in: 5...240, step: 5)
                                .frame(width: 150)

                            Text("minutes")
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text("Max Disk Usage:")
                                .frame(width: 180, alignment: .trailing)

                            Stepper("\(maxDiskUsageMb) MB", value: $maxDiskUsageMb, in: 100...102400, step: 1024)
                                .frame(width: 180)

                            Text("(\(maxDiskUsageMb / 1024) GB)")
                                .foregroundColor(.secondary)
                        }

                        Toggle(isOn: $enableNetwork) {
                            HStack {
                                Text("Enable Network:")
                                    .frame(width: 180, alignment: .trailing)
                                Text("Allow network access")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Toggle(isOn: $enableGit) {
                            HStack {
                                Text("Enable Git:")
                                    .frame(width: 180, alignment: .trailing)
                                Text("Allow git operations")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)

                    // Advanced Section (Collapsible)
                    VStack(alignment: .leading, spacing: 16) {
                        Button(action: { showAdvanced.toggle() }) {
                            HStack {
                                Text("Advanced Settings")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)

                        if showAdvanced {
                            VStack(alignment: .leading, spacing: 16) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("System Prompt")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    TextEditor(text: $systemPrompt)
                                        .font(.system(.body, design: .monospaced))
                                        .frame(height: 80)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                        )
                                    Text("Custom system prompt for the agent")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Allowed Commands")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    TextEditor(text: $allowedCommands)
                                        .font(.system(.body, design: .monospaced))
                                        .frame(height: 60)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                        )
                                    Text("Comma-separated list of allowed shell commands")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Environment Variables")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    TextEditor(text: $environmentVars)
                                        .font(.system(.body, design: .monospaced))
                                        .frame(height: 80)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                        )
                                    Text("KEY=value format, one per line")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                }
                .padding(24)
            }

            Divider()

            // Actions
            HStack {
                Button(action: { dismiss() }) {
                    Text("Cancel")
                        .frame(minWidth: 100)
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(action: createWorkspace) {
                    if isCreating {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(minWidth: 100)
                    } else {
                        Text("Create Workspace")
                            .frame(minWidth: 120)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(agentId.isEmpty || isCreating)
            }
            .padding(24)
        }
        .frame(width: 700, height: 700)
        .onAppear {
            loadAgents()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .fileImporter(
            isPresented: $showPathPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    workspacePath = url.path
                }
            case .failure(let error):
                errorMessage = "Failed to select path: \(error.localizedDescription)"
                showError = true
            }
        }
    }

    private func loadAgents() {
        _Concurrency.Task {
            isLoadingAgents = true
            defer { isLoadingAgents = false }

            do {
                guard let client = ExecutorManager.shared.getZMemoryClient() else {
                    print("⚠️ ZMemory client not available")
                    return
                }

                let agents = try await client.getAgents(isActive: true, limit: 100)
                await MainActor.run {
                    availableAgents = agents
                    print("✅ Loaded \(agents.count) agents")
                }
            } catch {
                print("❌ Failed to load agents: \(error)")
                await MainActor.run {
                    errorMessage = "Failed to load agents: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }

    private func createWorkspace() {
        _Concurrency.Task {
            isCreating = true
            defer { isCreating = false }

            do {
                let _ = try await workspaceManager.createWorkspace(
                    agentId: agentId,
                    workspaceName: workspaceName.isEmpty ? nil : workspaceName,
                    workspacePath: workspacePath.isEmpty ? nil : workspacePath,
                    projectName: projectName.isEmpty ? nil : projectName,
                    projectType: projectType.isEmpty ? nil : projectType,
                    repoUrl: repoUrl.isEmpty ? nil : repoUrl,
                    branch: repoBranch,
                    systemPrompt: systemPrompt.isEmpty ? nil : systemPrompt,
                    allowedCommands: parseCommands(allowedCommands),
                    environmentVars: parseEnvironmentVars(environmentVars),
                    executionTimeoutMinutes: executionTimeoutMinutes,
                    maxDiskUsageMb: maxDiskUsageMb,
                    enableNetwork: enableNetwork,
                    enableGit: enableGit
                )

                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    private func parseCommands(_ input: String) -> [String]? {
        let commands = input.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return commands.isEmpty ? nil : commands
    }

    private func parseEnvironmentVars(_ input: String) -> [String: String]? {
        var vars: [String: String] = [:]
        for line in input.split(separator: "\n") {
            let parts = line.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                vars[key] = value
            }
        }
        return vars.isEmpty ? nil : vars
    }
}

struct FormField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var required: Bool = false
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if required {
                    Text("*")
                        .foregroundColor(.red)
                }
            }
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct WorkspaceDetailSheet: View {
    @SwiftUI.Environment(\.dismiss) private var dismiss
    let workspace: ExecutorWorkspace
    @StateObject private var workspaceManager = WorkspaceManager.shared
    @State private var agentName: String?
    @State private var isLoadingAgent = false
    @State private var showEditSheet = false

    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Workspace Details")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("ID: \(workspace.id)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Workspace info
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    DetailRow(label: "Status", value: workspace.status.rawValue.capitalized, icon: "circle.fill")

                    if isLoadingAgent {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading agent...")
                                .font(.caption)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(8)
                    } else {
                        DetailRow(label: "Agent", value: agentName ?? workspace.agentId, icon: "person.circle")
                    }

                    DetailRow(label: "Workspace Path", value: workspace.workspacePath, icon: "folder")

                    if let repoUrl = workspace.repoUrl {
                        DetailRow(label: "Repository", value: repoUrl, icon: "arrow.down.doc")
                    }

                    DetailRow(label: "Branch", value: workspace.repoBranch, icon: "arrow.branch")
                    DetailRow(label: "Progress", value: "\(workspace.progressPercentage)%", icon: "chart.bar")

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Progress")
                            .font(.headline)
                        ProgressView(value: Double(workspace.progressPercentage) / 100.0)
                            .progressViewStyle(.linear)
                    }
                }
            }

            Spacer()

            // Actions
            HStack {
                Button(action: { dismiss() }) {
                    Text("Close")
                        .frame(minWidth: 100)
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(action: { showEditSheet = true }) {
                    Label("Edit", systemImage: "pencil")
                }
                .buttonStyle(.bordered)

                Button(action: openTerminal) {
                    Label("Open Terminal", systemImage: "terminal")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 500, height: 500)
        .onAppear {
            loadAgentName()
        }
        .sheet(isPresented: $showEditSheet) {
            EditWorkspaceSheet(workspace: workspace)
        }
    }

    private func loadAgentName() {
        guard !workspace.agentId.isEmpty else { return }

        _Concurrency.Task {
            isLoadingAgent = true
            defer { isLoadingAgent = false }

            do {
                guard let client = ExecutorManager.shared.getZMemoryClient() else { return }
                let agents = try await client.getAgents(isActive: true, limit: 1000)
                if let agent = agents.first(where: { $0.id == workspace.agentId }) {
                    await MainActor.run {
                        agentName = agent.name
                    }
                }
            } catch {
                print("❌ Failed to load agent name: \(error)")
            }
        }
    }

    private func openTerminal() {
        // TODO: Implement terminal opening
        dismiss()
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.body)
                .textSelection(.enabled)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct EditWorkspaceSheet: View {
    @SwiftUI.Environment(\.dismiss) private var dismiss
    let workspace: ExecutorWorkspace
    @StateObject private var workspaceManager = WorkspaceManager.shared

    // Basic fields
    @State private var workspaceName: String
    @State private var projectName: String
    @State private var projectType: String

    // Repository fields
    @State private var repoUrl: String
    @State private var repoBranch: String

    // Advanced fields
    @State private var systemPrompt: String
    @State private var allowedCommands: String
    @State private var environmentVars: String

    // Configuration fields
    @State private var executionTimeoutMinutes: Int
    @State private var maxDiskUsageMb: Int
    @State private var enableNetwork: Bool
    @State private var enableGit: Bool

    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showAdvanced = false

    init(workspace: ExecutorWorkspace) {
        self.workspace = workspace
        _workspaceName = State(initialValue: workspace.workspaceName)
        _projectName = State(initialValue: workspace.projectName ?? "")
        _projectType = State(initialValue: workspace.projectType ?? "")
        _repoUrl = State(initialValue: workspace.repoUrl ?? "")
        _repoBranch = State(initialValue: workspace.repoBranch)
        _systemPrompt = State(initialValue: workspace.systemPrompt ?? "")
        _allowedCommands = State(initialValue: workspace.allowedCommands?.joined(separator: "\n") ?? "")
        _environmentVars = State(initialValue: workspace.environmentVars?.map { "\($0.key)=\($0.value)" }.joined(separator: "\n") ?? "")
        _executionTimeoutMinutes = State(initialValue: workspace.executionTimeoutMinutes)
        _maxDiskUsageMb = State(initialValue: workspace.maxDiskUsageMb)
        _enableNetwork = State(initialValue: workspace.enableNetwork)
        _enableGit = State(initialValue: workspace.enableGit)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edit Workspace")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            .padding(24)

            Divider()

            // Form
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Basic Information")
                            .font(.headline)

                        FormField(
                            label: "Workspace Name",
                            placeholder: "My Workspace",
                            text: $workspaceName,
                            required: true,
                            description: "User-friendly name for this workspace"
                        )

                        FormField(
                            label: "Project Name",
                            placeholder: "My Project",
                            text: $projectName,
                            description: "Human-readable name for this workspace"
                        )

                        FormField(
                            label: "Project Type",
                            placeholder: "e.g., python, nodejs, rust",
                            text: $projectType,
                            description: "Programming language or framework"
                        )
                    }
                    .padding(16)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Repository")
                            .font(.headline)

                        FormField(
                            label: "Repository URL",
                            placeholder: "https://github.com/user/repo.git",
                            text: $repoUrl,
                            description: "Git repository URL to clone"
                        )

                        FormField(
                            label: "Branch",
                            placeholder: "main",
                            text: $repoBranch,
                            description: "Git branch to checkout"
                        )
                    }
                    .padding(16)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Configuration")
                            .font(.headline)

                        HStack {
                            Text("Execution Timeout:")
                                .frame(width: 180, alignment: .trailing)
                            Stepper("\(executionTimeoutMinutes) min", value: $executionTimeoutMinutes, in: 5...240, step: 5)
                                .frame(width: 150)
                        }

                        HStack {
                            Text("Max Disk Usage:")
                                .frame(width: 180, alignment: .trailing)
                            Stepper("\(maxDiskUsageMb) MB", value: $maxDiskUsageMb, in: 100...102400, step: 1024)
                                .frame(width: 180)
                        }

                        Toggle(isOn: $enableNetwork) {
                            HStack {
                                Text("Enable Network:")
                                    .frame(width: 180, alignment: .trailing)
                            }
                        }

                        Toggle(isOn: $enableGit) {
                            HStack {
                                Text("Enable Git:")
                                    .frame(width: 180, alignment: .trailing)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)

                    // Advanced Settings
                    VStack(alignment: .leading, spacing: 16) {
                        Button(action: { showAdvanced.toggle() }) {
                            HStack {
                                Text("Advanced Settings")
                                    .font(.headline)
                                Spacer()
                                Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                                    .font(.caption)
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.primary)

                        if showAdvanced {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("System Prompt")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("Custom instructions for Claude Code in this workspace")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextEditor(text: $systemPrompt)
                                    .font(.system(.body, design: .monospaced))
                                    .frame(height: 100)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                    )
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Allowed Commands")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("One command per line (e.g., git, npm, python)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextEditor(text: $allowedCommands)
                                    .font(.system(.body, design: .monospaced))
                                    .frame(height: 80)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                    )
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Environment Variables")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("One per line: KEY=value")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextEditor(text: $environmentVars)
                                    .font(.system(.body, design: .monospaced))
                                    .frame(height: 80)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                    )
                            }
                        }
                    }
                    .padding(16)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                }
                .padding(24)
            }

            Divider()

            // Actions
            HStack {
                Button(action: { dismiss() }) {
                    Text("Cancel")
                        .frame(minWidth: 100)
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(action: saveChanges) {
                    if isSaving {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(minWidth: 100)
                    } else {
                        Text("Save Changes")
                            .frame(minWidth: 120)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaving)
            }
            .padding(24)
        }
        .frame(width: 700, height: 700)
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func saveChanges() {
        _Concurrency.Task {
            isSaving = true
            defer { isSaving = false }

            do {
                var updates: [String: Any] = [:]

                // Basic fields
                if !workspaceName.isEmpty && workspaceName != workspace.workspaceName {
                    updates["workspace_name"] = workspaceName
                }
                // Allow clearing optional fields by comparing directly without empty check
                if projectName != (workspace.projectName ?? "") {
                    updates["project_name"] = projectName.isEmpty ? nil : projectName
                }
                if projectType != (workspace.projectType ?? "") {
                    updates["project_type"] = projectType.isEmpty ? nil : projectType
                }

                // Repository fields - allow clearing
                if repoUrl != (workspace.repoUrl ?? "") {
                    updates["repo_url"] = repoUrl.isEmpty ? nil : repoUrl
                }
                if repoBranch != workspace.repoBranch {
                    updates["repo_branch"] = repoBranch
                }

                // Advanced fields - allow clearing
                if systemPrompt != (workspace.systemPrompt ?? "") {
                    updates["system_prompt"] = systemPrompt.isEmpty ? nil : systemPrompt
                }

                // Parse allowed commands
                let newAllowedCommands = parseCommands(allowedCommands)
                if newAllowedCommands != workspace.allowedCommands {
                    updates["allowed_commands"] = newAllowedCommands ?? []
                }

                // Parse environment variables
                let newEnvVars = parseEnvironmentVars(environmentVars)
                if newEnvVars != workspace.environmentVars {
                    updates["environment_vars"] = newEnvVars ?? [:]
                }

                // Configuration fields
                if executionTimeoutMinutes != workspace.executionTimeoutMinutes {
                    updates["execution_timeout_minutes"] = executionTimeoutMinutes
                }
                if maxDiskUsageMb != workspace.maxDiskUsageMb {
                    updates["max_disk_usage_mb"] = maxDiskUsageMb
                }
                if enableNetwork != workspace.enableNetwork {
                    updates["enable_network"] = enableNetwork
                }
                if enableGit != workspace.enableGit {
                    updates["enable_git"] = enableGit
                }

                guard !updates.isEmpty else {
                    await MainActor.run {
                        dismiss()
                    }
                    return
                }

                guard let client = ExecutorManager.shared.getZMemoryClient() else {
                    throw WorkspaceError.clientNotAvailable
                }

                let updatedWorkspace = try await client.updateWorkspace(id: workspace.id, updates: updates)

                // Update local workspace list
                await MainActor.run {
                    if let index = workspaceManager.activeWorkspaces.firstIndex(where: { $0.id == workspace.id }) {
                        workspaceManager.activeWorkspaces[index] = updatedWorkspace
                    }
                    dismiss()
                }
            } catch {
                print("❌ Failed to update workspace: \(error)")
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    private func parseCommands(_ text: String) -> [String]? {
        let commands = text
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return commands.isEmpty ? nil : commands
    }

    private func parseEnvironmentVars(_ text: String) -> [String: String]? {
        var vars: [String: String] = [:]
        let lines = text.split(separator: "\n")
        for line in lines {
            let parts = line.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                if !key.isEmpty {
                    vars[key] = value
                }
            }
        }
        return vars.isEmpty ? nil : vars
    }
}

struct AgentSelectionField: View {
    @Binding var agentId: String
    @Binding var selectedAgent: AIAgent?
    let availableAgents: [AIAgent]
    let isLoadingAgents: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Agent")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("*")
                    .foregroundColor(.red)
            }

            if isLoadingAgents {
                loadingView
            } else if availableAgents.isEmpty {
                emptyStateView
            } else {
                pickerView
            }

            Text("Select the AI agent that will use this workspace")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var loadingView: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading agents...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(8)
    }

    private var emptyStateView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("No agents available")
                .font(.caption)
                .foregroundColor(.secondary)
            TextField("Enter UUID manually", text: $agentId)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var pickerView: some View {
        Picker("Select Agent", selection: $selectedAgent) {
            Text("Select an agent...").tag(nil as AIAgent?)
            ForEach(availableAgents) { agent in
                Text(agent.name).tag(agent as AIAgent?)
            }
        }
        .pickerStyle(.menu)
        .onChange(of: selectedAgent) { newAgent in
            agentId = newAgent?.id ?? ""
        }
    }
}

#Preview {
    WorkspaceManagementView()
}
