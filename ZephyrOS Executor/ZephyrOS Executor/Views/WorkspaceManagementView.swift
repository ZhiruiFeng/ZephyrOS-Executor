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

                Button(action: { showCreateWorkspace = true }) {
                    Label("Create Workspace", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(24)

            Divider()

            // Workspace List
            ScrollView {
                if workspaceManager.activeWorkspaces.isEmpty {
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
        .sheet(isPresented: $showCreateWorkspace) {
            CreateWorkspaceSheet()
        }
        .sheet(item: $selectedWorkspace) { workspace in
            WorkspaceDetailSheet(workspace: workspace)
        }
    }
}

struct WorkspaceCard: View {
    let workspace: ExecutorWorkspace
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    // Status indicator
                    Circle()
                        .fill(statusColor(workspace.status))
                        .frame(width: 12, height: 12)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Workspace #\(workspace.id.prefix(8))")
                            .font(.headline)
                            .foregroundColor(.primary)

                        if let repoUrl = workspace.repoUrl {
                            Text(repoUrl)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
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
                    Label("Agent: \(workspace.agentId.prefix(8))", systemImage: "person.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)

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

                        FormField(
                            label: "Agent ID",
                            placeholder: "Enter agent identifier",
                            text: $agentId,
                            required: true,
                            description: "Unique identifier for the agent that will use this workspace"
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

    private func createWorkspace() {
        _Concurrency.Task {
            isCreating = true
            defer { isCreating = false }

            do {
                let _ = try await workspaceManager.createWorkspace(
                    agentId: agentId,
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
                    DetailRow(label: "Agent ID", value: workspace.agentId, icon: "person.circle")
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

                Button(action: openTerminal) {
                    Label("Open Terminal", systemImage: "terminal")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 500, height: 500)
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

#Preview {
    WorkspaceManagementView()
}
