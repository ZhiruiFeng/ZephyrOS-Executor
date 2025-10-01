//
//  ExecutorManager.swift
//  ZephyrOS Executor
//
//  Central manager for executor operations and state
//

import Foundation
import Combine
import SwiftUI

class ExecutorManager: ObservableObject {
    static let shared = ExecutorManager()

    // MARK: - Published Properties
    @Published var state: ExecutorState
    @Published var statistics: ExecutorStatistics
    @Published var tasks: [Task] = []
    @Published var logs: [LogEntry] = []
    @Published var isAuthenticated: Bool = false

    // MARK: - Configuration
    @Published var config: ExecutorConfig

    // MARK: - Private Properties
    private var zMemoryClient: ZMemoryClient?
    private var claudeClient: ClaudeClient?
    private var pollingTimer: Timer?
    private var activeTasks: Set<String> = []

    // MARK: - Initialization

    private init() {
        // Load config from UserDefaults
        self.config = ExecutorConfig.load()

        // Initialize state
        self.state = ExecutorState(
            status: .idle,
            isConnectedToZMemory: false,
            isConnectedToClaude: false,
            lastSyncTime: nil,
            activeTasks: [],
            queuedTasks: [],
            recentTasks: []
        )

        self.statistics = ExecutorStatistics()

        // Initialize clients if config is valid
        if config.isValid {
            initializeClients()
        }
    }

    // MARK: - Public Methods

    func start() {
        guard config.isValid else {
            addLog("Cannot start: Configuration is invalid", level: .error)
            return
        }

        addLog("Starting executor...", level: .info)
        state.status = .running

        // Test connections
        _Concurrency.Task {
            await testConnections()
            if state.isConnectedToZMemory && state.isConnectedToClaude {
                startPolling()
                addLog("Executor started successfully", level: .info)
            } else {
                state.status = .error
                addLog("Failed to connect to required services", level: .error)
            }
        }
    }

    func stop() {
        addLog("Stopping executor...", level: .info)
        stopPolling()
        state.status = .idle
        addLog("Executor stopped", level: .info)
    }

    func pause() {
        guard state.status == .running else { return }
        stopPolling()
        state.status = .paused
        addLog("Executor paused", level: .warning)
    }

    func resume() {
        guard state.status == .paused else { return }
        state.status = .running
        startPolling()
        addLog("Executor resumed", level: .info)
    }

    func updateConfig(_ newConfig: ExecutorConfig) {
        self.config = newConfig
        newConfig.save()
        initializeClients()

        if state.status == .running {
            stop()
            start()
        }
    }

    func setSupabaseToken(_ token: String) {
        // Ensure client is initialized if URL is available
        if zMemoryClient == nil && !config.zMemoryAPIURL.isEmpty {
            zMemoryClient = ZMemoryClient(baseURL: config.zMemoryAPIURL, apiKey: config.zMemoryAPIKey)
        }

        zMemoryClient?.setOAuthToken(token)

        isAuthenticated = true
        addLog("Authenticated with Supabase", level: .info)
    }

    // Keep for backwards compatibility
    func setGoogleOAuthToken(_ token: String) {
        setSupabaseToken(token)
    }

    func signInWithGoogleToken(_ idToken: String) async {
        // Exchange Google ID token for Supabase session
        // Ensure client is initialized
        if zMemoryClient == nil && !config.zMemoryAPIURL.isEmpty {
            zMemoryClient = ZMemoryClient(baseURL: config.zMemoryAPIURL, apiKey: config.zMemoryAPIKey)
        }

        do {
            let supabaseToken = try await exchangeGoogleTokenForSupabase(idToken: idToken)
            zMemoryClient?.setOAuthToken(supabaseToken)

            await MainActor.run {
                isAuthenticated = true
                addLog("Authenticated with Google ID token via Supabase", level: .info)
            }
        } catch {
            await MainActor.run {
                isAuthenticated = false
                addLog("Failed to exchange Google token: \(error.localizedDescription)", level: .error)
            }
        }
    }

    private func exchangeGoogleTokenForSupabase(idToken: String) async throws -> String {
        // Use Supabase's signInWithIdToken endpoint
        let supabaseURL = Environment.supabaseURL

        guard !supabaseURL.isEmpty else {
            throw APIError.invalidURL
        }

        let url = URL(string: "\(supabaseURL)/auth/v1/token?grant_type=id_token")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Environment.supabaseAnonKey, forHTTPHeaderField: "apikey")

        let body = [
            "provider": "google",
            "id_token": idToken
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        struct SupabaseAuthResponse: Codable {
            let accessToken: String
            enum CodingKeys: String, CodingKey {
                case accessToken = "access_token"
            }
        }

        let authResponse = try JSONDecoder().decode(SupabaseAuthResponse.self, from: data)
        return authResponse.accessToken
    }

    func signOut() {
        isAuthenticated = false
        stop()
        addLog("Signed out", level: .info)
    }

    func getZMemoryClient() -> ZMemoryClient? {
        return zMemoryClient
    }

    // MARK: - Private Methods

    private func initializeClients() {
        if !config.zMemoryAPIURL.isEmpty && !config.zMemoryAPIKey.isEmpty {
            zMemoryClient = ZMemoryClient(baseURL: config.zMemoryAPIURL, apiKey: config.zMemoryAPIKey)
        }

        if !config.anthropicAPIKey.isEmpty {
            claudeClient = ClaudeClient(
                apiKey: config.anthropicAPIKey,
                model: config.claudeModel,
                maxTokens: config.maxTokensPerRequest
            )
        }
    }

    private func testConnections() async {
        // Test ZMemory connection
        if let client = zMemoryClient {
            do {
                let connected = try await client.testConnection()
                await MainActor.run {
                    state.isConnectedToZMemory = connected
                    if connected {
                        addLog("✓ Connected to ZMemory", level: .info)
                    } else {
                        addLog("✗ Failed to connect to ZMemory", level: .error)
                    }
                }
            } catch APIError.unauthorized {
                await MainActor.run {
                    state.isConnectedToZMemory = false
                    addLog("✗ ZMemory authentication failed - please re-login", level: .error)
                    // Trigger logout to force re-authentication
                    signOut()
                }
            } catch {
                await MainActor.run {
                    state.isConnectedToZMemory = false
                    addLog("✗ ZMemory connection error: \(error.localizedDescription)", level: .error)
                }
            }
        }

        // Test Claude connection
        if let client = claudeClient {
            do {
                let connected = try await client.testConnection()
                await MainActor.run {
                    state.isConnectedToClaude = connected
                    if connected {
                        addLog("✓ Connected to Claude API", level: .info)
                    } else {
                        addLog("✗ Failed to connect to Claude API", level: .error)
                    }
                }
            } catch {
                await MainActor.run {
                    state.isConnectedToClaude = false
                    addLog("✗ Claude API connection error: \(error.localizedDescription)", level: .error)
                }
            }
        }
    }

    private func startPolling() {
        pollingTimer?.invalidate()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(config.pollingIntervalSeconds), repeats: true) { [weak self] _ in
            _Concurrency.Task {
                await self?.pollForTasks()
            }
        }
        // Trigger immediate poll
        _Concurrency.Task {
            await pollForTasks()
        }
    }

    private func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    private func pollForTasks() async {
        guard let client = zMemoryClient else { return }

        do {
            let pendingTasks = try await client.getPendingTasks(agentName: config.agentName)

            await MainActor.run {
                state.lastSyncTime = Date()
                addLog("Found \(pendingTasks.count) pending task(s)", level: .info)
            }

            // Process tasks up to max concurrent limit
            for task in pendingTasks {
                if activeTasks.count >= config.maxConcurrentTasks {
                    break
                }

                // Accept and execute task
                await executeTask(task)
            }

        } catch APIError.unauthorized {
            await MainActor.run {
                addLog("Authentication expired - please re-login", level: .error)
                // Trigger logout to force re-authentication
                signOut()
            }
        } catch {
            await MainActor.run {
                addLog("Polling error: \(error.localizedDescription)", level: .error)
            }
        }
    }

    private func executeTask(_ task: Task) async {
        guard let zMemory = zMemoryClient, let claude = claudeClient else { return }

        let taskId = task.id
        activeTasks.insert(taskId)

        await MainActor.run {
            var updatedTask = task
            updatedTask.status = .accepted
            tasks.append(updatedTask)
            updateState()
            addLog("Accepted task: \(taskId)", level: .info)
        }

        do {
            // Accept task in ZMemory
            try await zMemory.acceptTask(taskId: taskId, agentName: config.agentName)

            // Update status to in progress
            try await zMemory.updateTaskStatus(taskId: taskId, status: .inProgress, progress: 0)

            await MainActor.run {
                if let index = tasks.firstIndex(where: { $0.id == taskId }) {
                    tasks[index].status = .inProgress
                }
                updateState()
                addLog("Executing task: \(taskId)", level: .info)
            }

            // Execute with Claude
            let context = task.context.reduce(into: [String: Any]()) { result, pair in
                result[pair.key] = pair.value.value
            }
            let result = try await claude.executeTask(description: task.description, context: context)

            // Complete task
            try await zMemory.completeTask(taskId: taskId, result: result)

            await MainActor.run {
                if let index = tasks.firstIndex(where: { $0.id == taskId }) {
                    tasks[index].status = .completed
                    tasks[index].result = result
                    tasks[index].completedAt = Date()
                }
                statistics.completedTasks += 1
                statistics.totalTasks += 1
                if let usage = result.usage {
                    statistics.totalTokens += usage.totalTokens
                }
                updateState()
                addLog("✓ Task completed: \(taskId)", level: .info)
            }

        } catch APIError.unauthorized {
            await MainActor.run {
                addLog("Authentication expired during task execution - please re-login", level: .error)
                // Trigger logout to force re-authentication
                signOut()
            }
        } catch {
            // Fail task
            do {
                try await zMemory.failTask(taskId: taskId, error: error.localizedDescription)
            } catch APIError.unauthorized {
                await MainActor.run {
                    addLog("Authentication expired - please re-login", level: .error)
                    signOut()
                }
            } catch {
                await MainActor.run {
                    addLog("Failed to report task failure: \(error.localizedDescription)", level: .error)
                }
            }

            await MainActor.run {
                if let index = tasks.firstIndex(where: { $0.id == taskId }) {
                    tasks[index].status = .failed
                    tasks[index].error = error.localizedDescription
                    tasks[index].failedAt = Date()
                }
                statistics.failedTasks += 1
                statistics.totalTasks += 1
                updateState()
                addLog("✗ Task failed: \(taskId) - \(error.localizedDescription)", level: .error)
            }
        }

        activeTasks.remove(taskId)
        await MainActor.run {
            updateState()
        }
    }

    private func updateState() {
        state.activeTasks = tasks.filter { $0.status == .inProgress }
        state.queuedTasks = tasks.filter { $0.status == .pending || $0.status == .accepted }
        state.recentTasks = Array(tasks.suffix(10))
    }

    private func addLog(_ message: String, level: LogLevel) {
        let entry = LogEntry(timestamp: Date(), level: level, message: message)

        // Ensure UI updates happen on main thread
        if Thread.isMainThread {
            logs.append(entry)
            // Keep only last 1000 logs
            if logs.count > 1000 {
                logs.removeFirst(logs.count - 1000)
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.logs.append(entry)
                // Keep only last 1000 logs
                if let self = self, self.logs.count > 1000 {
                    self.logs.removeFirst(self.logs.count - 1000)
                }
            }
        }
    }
}

// MARK: - Supporting Types

struct ExecutorConfig: Codable {
    var zMemoryAPIURL: String = ""
    var zMemoryAPIKey: String = ""
    var anthropicAPIKey: String = ""
    var claudeModel: String = "claude-sonnet-4-20250514"
    var agentName: String = "zephyr-executor-1"
    var maxConcurrentTasks: Int = 2
    var pollingIntervalSeconds: Int = 30
    var maxTokensPerRequest: Int = 4096

    var isValid: Bool {
        !zMemoryAPIURL.isEmpty
    }

    static func load() -> ExecutorConfig {
        // Try to load from UserDefaults first
        if let data = UserDefaults.standard.data(forKey: "ExecutorConfig"),
           let config = try? JSONDecoder().decode(ExecutorConfig.self, from: data) {
            // If loaded config has values, use it
            if !config.zMemoryAPIURL.isEmpty {
                return config
            }
        }

        // Fallback to environment variables
        var config = ExecutorConfig()
        config.zMemoryAPIURL = Environment.zMemoryAPIURL
        config.zMemoryAPIKey = Environment.zMemoryAPIKey
        config.anthropicAPIKey = Environment.anthropicAPIKey
        config.agentName = Environment.agentName
        config.maxConcurrentTasks = Environment.maxConcurrentTasks
        config.pollingIntervalSeconds = Environment.pollingIntervalSeconds

        return config
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "ExecutorConfig")
        }
    }
}

struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let level: LogLevel
    let message: String

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }
}

enum LogLevel: String, Codable {
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"

    var color: Color {
        switch self {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }
}
