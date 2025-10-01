//
//  ZMemoryClient.swift
//  ZephyrOS Executor
//
//  Client for ZMemory API
//

import Foundation

class ZMemoryClient {
    private let baseURL: URL
    private var apiKey: String
    private let session: URLSession
    private var oauthToken: String?

    init(baseURL: String, apiKey: String) {
        guard let url = URL(string: baseURL) else {
            fatalError("Invalid ZMemory API URL: \(baseURL)")
        }
        self.baseURL = url
        self.apiKey = apiKey

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }

    // Set OAuth token for authenticated requests
    func setOAuthToken(_ token: String) {
        self.oauthToken = token
    }

    // Get authorization header value
    private func getAuthorizationHeader() -> String {
        // Prefer OAuth token if available, fallback to API key
        if let oauthToken = oauthToken {
            return "Bearer \(oauthToken)"
        }
        return "Bearer \(apiKey)"
    }

    // MARK: - API Methods

    func testConnection() async throws -> Bool {
        let url = baseURL.appendingPathComponent("health")
        var request = URLRequest(url: url)
        request.setValue(getAuthorizationHeader(), forHTTPHeaderField: "Authorization")

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            return false
        }
        return httpResponse.statusCode == 200
    }

    func getPendingTasks(agentName: String) async throws -> [Task] {
        var components = URLComponents(url: baseURL.appendingPathComponent("tasks/pending"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "agent", value: agentName)]

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(getAuthorizationHeader(), forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        let taskResponse = try decoder.decode(TasksResponse.self, from: data)
        return taskResponse.tasks
    }

    func acceptTask(taskId: String, agentName: String) async throws {
        let url = baseURL.appendingPathComponent("tasks/\(taskId)/accept")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(getAuthorizationHeader(), forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["agent": agentName]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }

    func updateTaskStatus(taskId: String, status: TaskStatus, progress: Int? = nil) async throws {
        let url = baseURL.appendingPathComponent("tasks/\(taskId)/status")
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue(getAuthorizationHeader(), forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = ["status": status.rawValue]
        if let progress = progress {
            body["progress"] = progress
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }

    func completeTask(taskId: String, result: TaskResult) async throws {
        let url = baseURL.appendingPathComponent("tasks/\(taskId)/complete")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(getAuthorizationHeader(), forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601

        let body = ["result": result, "completed_at": ISO8601DateFormatter().string(from: Date())] as [String : Any]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }

    func failTask(taskId: String, error: String) async throws {
        let url = baseURL.appendingPathComponent("tasks/\(taskId)/fail")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(getAuthorizationHeader(), forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["error": error, "failed_at": ISO8601DateFormatter().string(from: Date())]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }

    // MARK: - AI Tasks API

    func getAITasks(status: AITaskStatus? = nil, agentId: String? = nil, limit: Int = 100) async throws -> [AITask] {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/ai-tasks"), resolvingAgainstBaseURL: false)!
        var queryItems: [URLQueryItem] = []

        if let status = status {
            queryItems.append(URLQueryItem(name: "status", value: status.rawValue))
        }
        if let agentId = agentId {
            queryItems.append(URLQueryItem(name: "agent_id", value: agentId))
        }
        queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        queryItems.append(URLQueryItem(name: "sort_by", value: "assigned_at"))
        queryItems.append(URLQueryItem(name: "sort_order", value: "desc"))

        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(getAuthorizationHeader(), forHTTPHeaderField: "Authorization")

        // Debug logging
        print("🔍 AI Tasks Request URL: \(url)")
        print("🔍 Has OAuth Token: \(oauthToken != nil)")
        print("🔍 Auth Header: \(getAuthorizationHeader().prefix(20))...")

        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            print("🔍 AI Tasks Response Status: \(httpResponse.statusCode)")
        }

        try validateResponse(response)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        let taskResponse = try decoder.decode(AITasksResponse.self, from: data)
        return taskResponse.aiTasks
    }

    func getAITask(id: String) async throws -> AITask {
        let url = baseURL.appendingPathComponent("api/ai-tasks/\(id)")
        var request = URLRequest(url: url)
        request.setValue(getAuthorizationHeader(), forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        struct Response: Codable {
            let aiTask: AITask
            enum CodingKeys: String, CodingKey {
                case aiTask = "ai_task"
            }
        }

        let taskResponse = try decoder.decode(Response.self, from: data)
        return taskResponse.aiTask
    }

    func updateAITaskStatus(id: String, status: AITaskStatus) async throws {
        let url = baseURL.appendingPathComponent("api/ai-tasks/\(id)")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(getAuthorizationHeader(), forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["status": status.rawValue]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }

    func getAgents(isActive: Bool = true, limit: Int = 100) async throws -> [AIAgent] {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/ai-agents"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "is_active", value: String(isActive)),
            URLQueryItem(name: "limit", value: String(limit))
        ]

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(getAuthorizationHeader(), forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        let agentsResponse = try decoder.decode(AIAgentsResponse.self, from: data)
        return agentsResponse.agents
    }

    func getSimpleTasks(limit: Int = 100) async throws -> [SimpleTask] {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/tasks"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "limit", value: String(limit))
        ]

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(getAuthorizationHeader(), forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        let tasksResponse = try decoder.decode(SimpleTasksResponse.self, from: data)
        return tasksResponse.tasks
    }

    // MARK: - Helper Methods

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw APIError.unauthorized
        case 404:
            throw APIError.notFound
        case 500...599:
            throw APIError.serverError
        default:
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
    }
}

// MARK: - Response Models

struct TasksResponse: Decodable {
    let tasks: [Task]
}

// MARK: - Errors

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case notFound
    case serverError
    case httpError(statusCode: Int)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Unauthorized - check your API key"
        case .notFound:
            return "Resource not found"
        case .serverError:
            return "Server error occurred"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}
