//
//  TerminalView.swift
//  ZephyrOS Executor
//
//  Terminal view component for AI Tasks
//

import SwiftUI
import AppKit

struct TerminalView: View {
    let task: AITask
    @State private var terminalText: String = ""
    @State private var inputCommand: String = ""
    @State private var commandHistory: [TerminalCommand] = []
    @SwiftUI.Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "terminal.fill")
                    .foregroundColor(.green)
                Text("Terminal - \(task.objective)")
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                Button(action: clearTerminal) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .help("Clear terminal")

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close terminal")
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Terminal Output Area
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        // Task context info
                        Text("Task ID: \(task.id)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.green)

                        Text("Mode: \(task.mode.displayName)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.green)

                        Text("Working directory: ~/")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.green)

                        Divider()
                            .padding(.vertical, 4)

                        // Command history
                        ForEach(commandHistory) { cmd in
                            VStack(alignment: .leading, spacing: 2) {
                                // Command prompt
                                HStack(spacing: 4) {
                                    Text("$")
                                        .foregroundColor(.blue)
                                    Text(cmd.command)
                                        .foregroundColor(.white)
                                }
                                .font(.system(.body, design: .monospaced))

                                // Output
                                if !cmd.output.isEmpty {
                                    Text(cmd.output)
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(cmd.isError ? .red : .white)
                                        .textSelection(.enabled)
                                }
                            }
                            .id(cmd.id)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }
                .background(Color.black)
                .onChange(of: commandHistory.count) { _ in
                    if let lastCommand = commandHistory.last {
                        withAnimation {
                            proxy.scrollTo(lastCommand.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Input Area
            HStack(spacing: 8) {
                Text("$")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.blue)

                TextField("Enter command...", text: $inputCommand)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white)
                    .onSubmit {
                        executeCommand()
                    }

                Button(action: executeCommand) {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundColor(.green)
                }
                .buttonStyle(.plain)
                .disabled(inputCommand.isEmpty)
            }
            .padding()
            .background(Color.black)
        }
        .frame(minWidth: 600, minHeight: 400)
        .onAppear {
            // Initial welcome message
            commandHistory.append(TerminalCommand(
                command: "# Terminal initialized for task: \(task.objective)",
                output: "Ready to execute commands for this AI task.",
                isError: false
            ))
        }
    }

    private func executeCommand() {
        guard !inputCommand.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let cmd = inputCommand
        inputCommand = ""

        // Execute command
        executeShellCommand(cmd)
    }

    private func executeShellCommand(_ command: String) {
        let task = Process()
        let pipe = Pipe()
        let errorPipe = Pipe()

        task.standardOutput = pipe
        task.standardError = errorPipe
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-c", command]

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

            let output = String(data: data, encoding: .utf8) ?? ""
            let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

            let isError = task.terminationStatus != 0
            let finalOutput = isError && !errorOutput.isEmpty ? errorOutput : output

            commandHistory.append(TerminalCommand(
                command: command,
                output: finalOutput.trimmingCharacters(in: .whitespacesAndNewlines),
                isError: isError
            ))
        } catch {
            commandHistory.append(TerminalCommand(
                command: command,
                output: "Error: \(error.localizedDescription)",
                isError: true
            ))
        }
    }

    private func clearTerminal() {
        commandHistory.removeAll()
        commandHistory.append(TerminalCommand(
            command: "# Terminal cleared",
            output: "",
            isError: false
        ))
    }
}

// MARK: - Terminal Command Model

struct TerminalCommand: Identifiable {
    let id = UUID()
    let command: String
    let output: String
    let isError: Bool
}

// MARK: - Preview

#Preview {
    TerminalView(task: AITask(
        id: "test-123",
        taskId: "task-456",
        agentId: "agent-789",
        objective: "Test Task",
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
    .frame(width: 800, height: 600)
}
