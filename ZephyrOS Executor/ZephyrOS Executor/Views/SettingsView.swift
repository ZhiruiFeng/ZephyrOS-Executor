//
//  SettingsView.swift
//  ZephyrOS Executor
//
//  Settings configuration view
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var executorManager: ExecutorManager
    @State private var config: ExecutorConfig
    @State private var showingSaveConfirmation = false

    init() {
        _config = State(initialValue: ExecutorManager.shared.config)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Settings")
                    .font(.system(size: 28, weight: .bold))

                // ZMemory Configuration
                SettingsSection(title: "ZMemory API", icon: "cloud") {
                    TextField("API URL", text: $config.zMemoryAPIURL)
                        .textFieldStyle(.roundedBorder)

                    SecureField("API Key", text: $config.zMemoryAPIKey)
                        .textFieldStyle(.roundedBorder)
                }

                // Claude Configuration
                SettingsSection(title: "Claude API", icon: "brain") {
                    SecureField("Anthropic API Key", text: $config.anthropicAPIKey)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        Text("Model")
                        Spacer()
                        Picker("", selection: $config.claudeModel) {
                            Text("Claude Sonnet 4").tag("claude-sonnet-4-20250514")
                            Text("Claude Opus 4").tag("claude-opus-4-20250514")
                        }
                        .pickerStyle(.menu)
                        .frame(width: 200)
                    }

                    HStack {
                        Text("Max Tokens per Request")
                        Spacer()
                        TextField("", value: $config.maxTokensPerRequest, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                    }
                }

                // Executor Configuration
                SettingsSection(title: "Executor", icon: "gearshape.2") {
                    TextField("Agent Name", text: $config.agentName)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        Text("Max Concurrent Tasks")
                        Spacer()
                        Stepper("\(config.maxConcurrentTasks)", value: $config.maxConcurrentTasks, in: 1...10)
                            .frame(width: 120)
                    }

                    HStack {
                        Text("Polling Interval (seconds)")
                        Spacer()
                        Stepper("\(config.pollingIntervalSeconds)", value: $config.pollingIntervalSeconds, in: 10...300, step: 10)
                            .frame(width: 120)
                    }
                }

                // Account Section
                SettingsSection(title: "Account", icon: "person.circle") {
                    if executorManager.isAuthenticated {
                        HStack {
                            Text("Status: Signed in with Google")
                                .foregroundColor(.green)
                            Spacer()
                            Button("Sign Out") {
                                executorManager.signOut()
                            }
                            .buttonStyle(.bordered)
                        }
                    } else {
                        Text("Not signed in")
                            .foregroundColor(.secondary)
                    }
                }

                // Save button
                HStack {
                    Spacer()
                    Button("Revert") {
                        config = executorManager.config
                    }
                    .disabled(config == executorManager.config)

                    Button("Save Configuration") {
                        executorManager.updateConfig(config)
                        showingSaveConfirmation = true
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(config == executorManager.config || !config.isValid)
                }

                if !config.isValid {
                    Text("⚠️ Please fill in all required fields (ZMemory URL, ZMemory API Key, and Anthropic API Key)")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.top, 8)
                }
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("Settings Saved", isPresented: $showingSaveConfirmation) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your configuration has been saved. The executor will restart with the new settings.")
        }
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
        }
    }
}

extension ExecutorConfig: Equatable {
    static func == (lhs: ExecutorConfig, rhs: ExecutorConfig) -> Bool {
        lhs.zMemoryAPIURL == rhs.zMemoryAPIURL &&
        lhs.zMemoryAPIKey == rhs.zMemoryAPIKey &&
        lhs.anthropicAPIKey == rhs.anthropicAPIKey &&
        lhs.claudeModel == rhs.claudeModel &&
        lhs.agentName == rhs.agentName &&
        lhs.maxConcurrentTasks == rhs.maxConcurrentTasks &&
        lhs.pollingIntervalSeconds == rhs.pollingIntervalSeconds &&
        lhs.maxTokensPerRequest == rhs.maxTokensPerRequest
    }
}
