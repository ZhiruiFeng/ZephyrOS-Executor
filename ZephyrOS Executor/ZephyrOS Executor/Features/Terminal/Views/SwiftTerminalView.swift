//
//  SwiftTerminalView.swift
//  ZephyrOS Executor
//
//  SwiftUI wrapper for SwiftTerm terminal with PTY support
//

import SwiftUI
import SwiftTerm
import AppKit

/// SwiftUI wrapper for the SwiftTerm terminal emulator
/// Provides a real interactive terminal with full PTY support
struct SwiftTerminalView: View {
    let task: AITask
    var workspace: ExecutorWorkspace? = nil

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
                Text("Interactive Terminal - \(task.objective)")
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
                    Text("Initializing terminal...")
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

                if let workspace = workspace {
                    Text("Workspace: \(workspace.status.rawValue)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.trailing, 8)
                }

                Text("Task ID: \(task.id)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Mode: \(task.mode.displayName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 8)
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .frame(minWidth: 700, minHeight: 500)
        .onAppear {
            setupTerminal()
        }
        .onDisappear {
            controller.terminate()
        }
    }

    // MARK: - Setup

    private func setupTerminal() {
        // Determine working directory from workspace or use default
        let workingDirectory: String?
        if let workspace = workspace, FileManager.default.fileExists(atPath: workspace.workspacePath) {
            // Use workspace path with /src subdirectory if it exists
            let srcPath = (workspace.workspacePath as NSString).appendingPathComponent("src")
            workingDirectory = FileManager.default.fileExists(atPath: srcPath) ? srcPath : workspace.workspacePath
        } else {
            workingDirectory = nil
        }

        // Determine initial command based on task
        var initialCommand = "echo 'Terminal ready for task execution'"
        if let workspace = workspace {
            initialCommand += " && echo 'Workspace: \(workspace.workspacePath)' && ls -la"
        }

        // Create terminal with workspace directory
        let terminal = controller.createTerminal(
            shellPath: "/bin/zsh",
            workingDirectory: workingDirectory,
            initialCommand: initialCommand
        )

        // Store terminal view for rendering
        terminalView = terminal

        // Setup output capture callback (optional)
        controller.onOutput = { output in
            print("📋 Terminal output: \(output)")
            // TODO: Send to ZMemory task system
            // Task {
            //     if let workspace = workspace {
            //         let event = ExecutorWorkspaceEvent(...)
            //         try? await ZMemoryClient.shared.logWorkspaceEvent(workspaceId: workspace.id, event: event)
            //     }
            // }
        }

        controller.onError = { error in
            print("❌ Terminal error: \(error)")
        }
    }

    // MARK: - Command Injection

    private func injectCommand() {
        guard !commandInput.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        controller.sendCommand(commandInput)
        commandInput = ""
    }
}

// MARK: - Terminal View Wrapper

/// NSViewRepresentable wrapper to embed SwiftTerm's NSView in SwiftUI
struct TerminalViewWrapper: NSViewRepresentable {
    let terminalView: LocalProcessTerminalView

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        return terminalView
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        // No updates needed - terminal is interactive
    }
}

// MARK: - Preview

#Preview {
    SwiftTerminalView(task: AITask(
        id: "test-123",
        taskId: "task-456",
        agentId: "agent-789",
        objective: "Test Terminal Integration",
        deliverables: nil,
        context: nil,
        acceptanceCriteria: nil,
        taskType: "development",
        dependencies: nil,
        mode: .execute,
        guardrails: nil,
        metadata: nil,
        status: .inProgress,
        history: nil,
        executionResult: nil,
        estimatedCostUSD: nil,
        actualCostUSD: nil,
        estimatedDurationMin: nil,
        actualDurationMin: nil,
        assignedAt: Date(),
        startedAt: nil,
        completedAt: nil,
        dueAt: nil
    ))
    .frame(width: 900, height: 650)
}
