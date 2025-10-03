//
//  PTYTerminalController.swift
//  ZephyrOS Executor
//
//  Terminal controller for SwiftTerm with PTY session management
//

import Foundation
import SwiftTerm

/// Controller to manage a PTY-based terminal session using SwiftTerm
/// This provides a real interactive shell with full terminal emulation
class PTYTerminalController: ObservableObject {
    // MARK: - Properties

    /// The underlying terminal view from SwiftTerm
    private(set) var terminalView: LocalProcessTerminalView?

    /// Callback for terminal output (useful for logging/capturing)
    var onOutput: ((String) -> Void)?

    /// Callback for terminal errors
    var onError: ((String) -> Void)?

    /// Flag to track if terminal is ready
    @Published var isReady = false

    // MARK: - Initialization

    init() {
        // Terminal will be set up when createTerminal is called
    }

    // MARK: - Terminal Setup

    /// Creates and configures the terminal view with a shell process
    /// - Parameters:
    ///   - frame: Initial frame for the terminal view
    ///   - shellPath: Path to shell executable (defaults to /bin/zsh)
    ///   - workingDirectory: Initial working directory for the shell (defaults to user home)
    ///   - initialCommand: Optional command to run on startup
    /// - Returns: The configured LocalProcessTerminalView
    func createTerminal(
        frame: CGRect = CGRect(x: 0, y: 0, width: 800, height: 600),
        shellPath: String = "/bin/zsh",
        workingDirectory: String? = nil,
        initialCommand: String? = nil
    ) -> LocalProcessTerminalView {

        // Create LocalProcessTerminalView which handles PTY automatically
        let terminal = LocalProcessTerminalView(frame: frame)

        // Configure terminal appearance
        terminal.configureTerminalAppearance()

        // Store reference
        self.terminalView = terminal

        do {
            // Prepare environment with working directory if specified
            var environment: [String]? = nil
            if let workDir = workingDirectory {
                // Get default environment and add PWD
                var env = ProcessInfo.processInfo.environment
                env["PWD"] = workDir
                environment = env.map { "\($0.key)=\($0.value)" }
            }

            // Start the shell process with PTY as an interactive shell
            // This creates a pseudo-terminal and connects the shell to it
            if shellPath.contains("zsh") {
                // Start zsh as login interactive shell
                try terminal.startProcess(
                    executable: shellPath,
                    args: ["-l", "-i"],
                    environment: environment
                )
            } else if shellPath.contains("bash") {
                // Start bash as login interactive shell
                try terminal.startProcess(
                    executable: shellPath,
                    args: ["-l", "-i"],
                    environment: environment
                )
            } else {
                // For other shells, start with defaults
                try terminal.startProcess(
                    executable: shellPath,
                    args: [],
                    environment: environment
                )
            }
            isReady = true

            print("✅ PTY Terminal started successfully")

            // Change to working directory if specified
            if let workDir = workingDirectory {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.sendCommand("cd \"\(workDir)\"")
                }
            }

            // If there's an initial command, send it after shell starts and directory change
            if let command = initialCommand {
                // Give shell a moment to initialize and change directory, then send command
                let delay = workingDirectory != nil ? 0.7 : 0.5
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    self?.sendCommand(command)
                }
            }
        } catch {
            let errorMsg = "Failed to start terminal: \(error.localizedDescription)"
            print("❌ \(errorMsg)")
            onError?(errorMsg)
        }

        return terminal
    }

    // MARK: - Terminal Control

    /// Send a command to the terminal (programmatically inject commands)
    /// - Parameter command: Command string to execute
    /// - Note: This is how you can programmatically control the terminal from your AI task system
    func sendCommand(_ command: String) {
        guard let terminal = terminalView else {
            print("⚠️ Terminal not initialized")
            return
        }

        // Send command to terminal with newline
        terminal.send(txt: command + "\n")

        print("📤 Sent command to terminal: \(command)")
    }

    /// Send raw text to terminal (without newline)
    /// - Parameter text: Text to send
    func sendText(_ text: String) {
        guard let terminal = terminalView else {
            print("⚠️ Terminal not initialized")
            return
        }

        terminal.send(txt: text)
    }

    /// Clear the terminal screen
    func clear() {
        sendCommand("clear")
    }

    /// Terminate the shell process and clean up
    func terminate() {
        // LocalProcessTerminalView doesn't have a terminate method
        // The process will be cleaned up when the view is deallocated
        terminalView = nil
        isReady = false
        print("🛑 Terminal terminated")
    }

    // MARK: - ZMemory Integration Helpers

    /// Execute a command and capture output
    /// - Parameter command: Command to execute
    /// - Note: For full output capture, you'll need to implement a delegate
    ///         This is a simplified version for demonstration
    func executeAndCapture(_ command: String) {
        // TODO: Implement output capture using TerminalDelegate
        // For now, just send the command
        sendCommand(command)

        // To capture output, you would need to:
        // 1. Implement TerminalDelegate protocol
        // 2. Parse the terminal data stream
        // 3. Store output in a buffer
        // 4. Return the captured text
    }
}

// MARK: - Terminal Appearance Extension

private extension LocalProcessTerminalView {
    /// Configure terminal visual appearance
    func configureTerminalAppearance() {
        // Terminal colors and styling can be customized here
        // The terminal will use system defaults if not specified

        // Example customizations (uncomment to use):
        // self.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)

        // You can also set colors through the Terminal's color scheme
        // terminal.nativeForegroundColor = NSColor.white
        // terminal.nativeBackgroundColor = NSColor.black
    }
}

// MARK: - Usage Instructions

/*
 HOW TO EXTEND THIS IMPLEMENTATION:

 1. READ AI TASKS FROM ZMEMORY:
    - Get tasks from ZMemoryClient in your AITasksView
    - Pass task.objective or task.deliverables to terminal controller
    - Example:
      ```
      let controller = PTYTerminalController()
      if let task = await zmemoryClient.getNextTask() {
          controller.sendCommand(task.command)
      }
      ```

 2. PROGRAMMATICALLY INJECT COMMANDS:
    - Use controller.sendCommand("your command here")
    - Example for AI task execution:
      ```
      controller.sendCommand("cd ~/projects")
      controller.sendCommand("npm test")
      controller.sendCommand("git status")
      ```

 3. CAPTURE TERMINAL OUTPUT:
    - Implement TerminalDelegate protocol
    - Override send(source:, data:) method
    - Parse the byte data into strings
    - Example implementation:
      ```
      class OutputCapture: TerminalDelegate {
          var capturedOutput = ""

          func send(source: Terminal, data: ArraySlice<UInt8>) {
              if let text = String(bytes: data, encoding: .utf8) {
                  capturedOutput += text
                  // Send back to ZMemory task system
                  zmemoryClient.updateTaskOutput(text)
              }
          }
      }
      ```

 4. WRITE OUTPUT BACK TO TASK SYSTEM:
    - Store output in controller.onOutput callback
    - Send to ZMemory when command completes
    - Example:
      ```
      controller.onOutput = { output in
          Task {
              await zmemoryClient.updateAITask(
                  id: task.id,
                  output: output,
                  status: .completed
              )
          }
      }
      ```

 5. ADVANCED: AUTO-EXECUTE ON TASK ASSIGNMENT:
    - Listen for new tasks in ZMemory
    - When task.status == .assigned, extract command
    - Auto-inject to terminal
    - Capture result and update task
    - Example workflow:
      ```
      // In AITasksView or background service
      zmemoryClient.onNewTask = { task in
          if task.mode == .execute {
              controller.sendCommand(task.objective)
              // Wait for completion, capture output, update task
          }
      }
      ```
 */
