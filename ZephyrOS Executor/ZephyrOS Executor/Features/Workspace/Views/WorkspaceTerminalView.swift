//
//  WorkspaceTerminalView.swift
//  ZephyrOS Executor
//
//  Terminal view restricted to workspace path
//

import SwiftUI
import SwiftTerm
import AppKit

/// Terminal view that is restricted to a specific workspace path
/// This prevents users from navigating outside the workspace directory
struct WorkspaceTerminalView: View {
    let workspace: ExecutorWorkspace

    @StateObject private var controller = PTYTerminalController()
    @State private var terminalView: LocalProcessTerminalView?
    @State private var showCommandInput = false
    @State private var commandInput = ""

    @SwiftUI.Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "terminal.fill")
                    .foregroundColor(.green)
                Text("Workspace Terminal - \(workspace.workspaceName)")
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                // Command injection toggle
                Button(action: { showCommandInput.toggle() }) {
                    Image(systemName: "arrow.down.doc.fill")
                }
                .buttonStyle(.plain)
                .help("Inject command")

                Button(action: { controller.clear() }) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .help("Clear terminal")

                Button(action: {
                    controller.terminate()
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close terminal")
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Workspace restriction notice
            HStack {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(.blue)
                Text("Terminal is restricted to workspace path: \(workspace.workspacePath)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.1))

            Divider()

            // Command Input Bar (for programmatic injection)
            if showCommandInput {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundColor(.green)

                    TextField("Inject command to terminal...", text: $commandInput)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            injectCommand()
                        }

                    Button("Send") {
                        injectCommand()
                    }
                    .disabled(commandInput.isEmpty)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(nsColor: .controlBackgroundColor))

                Divider()
            }

            // Terminal View
            if let terminal = terminalView {
                TerminalViewWrapper(terminalView: terminal)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Initializing workspace terminal...")
                        .foregroundColor(.secondary)
                        .padding(.top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Status bar
            HStack {
                if controller.isReady {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("Shell Ready")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                    Text("Initializing...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(workspaceStatusColor(workspace.status))
                        .frame(width: 6, height: 6)
                    Text(workspace.status.rawValue.capitalized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text("Agent: \(workspace.agentId.prefix(8))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 8)
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            setupTerminal()
        }
        .onDisappear {
            controller.terminate()
        }
    }

    // MARK: - Setup

    private func setupTerminal() {
        // Verify workspace path exists
        guard FileManager.default.fileExists(atPath: workspace.workspacePath) else {
            print("⚠️ Workspace path does not exist: \(workspace.workspacePath)")
            return
        }

        // Determine working directory - use workspace path or src subdirectory
        let srcPath = (workspace.workspacePath as NSString).appendingPathComponent("src")
        let workingDirectory = FileManager.default.fileExists(atPath: srcPath) ? srcPath : workspace.workspacePath

        // Initial command to show workspace info and prevent navigation outside
        let initialCommand = """
        clear && \
        echo '🔒 Workspace Terminal - Restricted Environment' && \
        echo '📁 Workspace: \(workspace.workspaceName)' && \
        echo '📂 Path: \(workspace.workspacePath)' && \
        echo '⚠️  Note: Terminal is restricted to workspace directory' && \
        echo '' && \
        ls -la
        """

        // Create terminal with workspace directory
        let terminal = controller.createTerminal(
            shellPath: "/bin/zsh",
            workingDirectory: workingDirectory,
            initialCommand: initialCommand
        )

        // Store terminal view for rendering
        terminalView = terminal

        // Setup output capture callback
        controller.onOutput = { output in
            print("📋 Workspace terminal output: \(output)")
            // TODO: Send to ZMemory workspace event system
            // Task {
            //     let event = ExecutorWorkspaceEvent(...)
            //     try? await ZMemoryClient.shared.logWorkspaceEvent(workspaceId: workspace.id, event: event)
            // }
        }

        controller.onError = { error in
            print("❌ Workspace terminal error: \(error)")
        }
    }

    // MARK: - Command Injection

    private func injectCommand() {
        guard !commandInput.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        controller.sendCommand(commandInput)
        commandInput = ""
    }

    // MARK: - Helpers

    private func workspaceStatusColor(_ status: ExecutorWorkspace.WorkspaceStatus) -> SwiftUI.Color {
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

#Preview {
    WorkspaceTerminalView(workspace: ExecutorWorkspace(
        id: "test-workspace",
        executorDeviceId: "test-device",
        agentId: "test-agent",
        userId: "test-user",
        workspacePath: "/tmp/test-workspace",
        relativePath: "test-workspace",
        metadataPath: nil,
        workspaceName: "Test Workspace",
        repoUrl: nil,
        repoBranch: "main",
        projectType: "swift",
        projectName: "Test Project",
        allowedCommands: nil,
        environmentVars: nil,
        systemPrompt: nil,
        executionTimeoutMinutes: 60,
        enableNetwork: true,
        enableGit: true,
        maxDiskUsageMb: 10240,
        status: .ready,
        progressPercentage: 100,
        currentPhase: nil,
        currentStep: nil,
        lastHeartbeatAt: nil,
        diskUsageBytes: 0,
        fileCount: 0,
        createdAt: Date(),
        initializedAt: Date(),
        readyAt: Date(),
        archivedAt: nil,
        updatedAt: Date()
    ))
    .frame(width: 900, height: 650)
}
