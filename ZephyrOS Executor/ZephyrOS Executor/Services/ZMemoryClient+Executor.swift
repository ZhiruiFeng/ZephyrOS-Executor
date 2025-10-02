//
//  ZMemoryClient+Executor.swift
//  ZephyrOS Executor
//
//  Extension for Executor API methods - devices, workspaces, tasks, events, artifacts, metrics
//

import Foundation

extension ZMemoryClient {

    // MARK: - Executor Device Management

    /// Register a new executor device
    func registerDevice(_ device: ExecutorDevice) async throws -> ExecutorDevice {
        let url = baseURL.appendingPathComponent("api/executor/devices")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(getAuthorizationHeader(), forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(device)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let decoder = makeDecoder()
        let deviceResponse = try decoder.decode([String: ExecutorDevice].self, from: data)

        guard let device = deviceResponse["device"] else {
            throw APIError.decodingError(NSError(domain: "Device not found in response", code: -1))
        }

        return device
    }

    /// Get a specific executor device by ID
    func getDevice(id: String) async throws -> ExecutorDevice {
        let url = baseURL.appendingPathComponent("api/executor/devices/\(id)")
        var request = URLRequest(url: url)
        request.setValue(getAuthorizationHeader(), forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let decoder = makeDecoder()
        let deviceResponse = try decoder.decode([String: ExecutorDevice].self, from: data)

        guard let device = deviceResponse["device"] else {
            throw APIError.decodingError(NSError(domain: "Device not found in response", code: -1))
        }

        return device
    }

    /// List all executor devices for the current user
    func listDevices(status: ExecutorDevice.DeviceStatus? = nil, isOnline: Bool? = nil) async throws -> [ExecutorDevice] {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/executor/devices"), resolvingAgainstBaseURL: false)!
        var queryItems: [URLQueryItem] = []

        if let status = status {
            queryItems.append(URLQueryItem(name: "status", value: status.rawValue))
        }
        if let isOnline = isOnline {
            queryItems.append(URLQueryItem(name: "is_online", value: String(isOnline)))
        }

        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(getAuthorizationHeader(), forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let decoder = makeDecoder()
        let devicesResponse = try decoder.decode(ExecutorDevicesResponse.self, from: data)

        return devicesResponse.devices
    }

    /// Update an executor device
    func updateDevice(id: String, updates: [String: Any]) async throws -> ExecutorDevice {
        let url = baseURL.appendingPathComponent("api/executor/devices/\(id)")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(getAuthorizationHeader(), forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        request.httpBody = try JSONSerialization.data(withJSONObject: updates)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let decoder = makeDecoder()
        let deviceResponse = try decoder.decode([String: ExecutorDevice].self, from: data)

        guard let device = deviceResponse["device"] else {
            throw APIError.decodingError(NSError(domain: "Device not found in response", code: -1))
        }

        return device
    }

    /// Delete an executor device
    func deleteDevice(id: String) async throws {
        let url = baseURL.appendingPathComponent("api/executor/devices/\(id)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(getAuthorizationHeader(), forHTTPHeaderField: "Authorization")

        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }

    /// Send heartbeat for an executor device
    func sendDeviceHeartbeat(id: String) async throws {
        let url = baseURL.appendingPathComponent("api/executor/devices/\(id)/heartbeat")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(getAuthorizationHeader(), forHTTPHeaderField: "Authorization")

        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }

    // MARK: - Executor Workspace Management

    /// Create a new workspace
    func createWorkspace(_ workspace: ExecutorWorkspace) async throws -> ExecutorWorkspace {
        let url = baseURL.appendingPathComponent("api/executor/workspaces")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(getAuthorizationHeader(), forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(workspace)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let decoder = makeDecoder()
        let workspaceResponse = try decoder.decode([String: ExecutorWorkspace].self, from: data)

        guard let workspace = workspaceResponse["workspace"] else {
            throw APIError.decodingError(NSError(domain: "Workspace not found in response", code: -1))
        }

        return workspace
    }

    /// Get a specific workspace by ID
    func getWorkspace(id: String) async throws -> ExecutorWorkspace {
        let url = baseURL.appendingPathComponent("api/executor/workspaces/\(id)")
        var request = URLRequest(url: url)
        request.setValue(getAuthorizationHeader(), forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let decoder = makeDecoder()
        let workspaceResponse = try decoder.decode([String: ExecutorWorkspace].self, from: data)

        guard let workspace = workspaceResponse["workspace"] else {
            throw APIError.decodingError(NSError(domain: "Workspace not found in response", code: -1))
        }

        return workspace
    }

    /// List workspaces with optional filters
    func listWorkspaces(
        executorDeviceId: String? = nil,
        agentId: String? = nil,
        status: ExecutorWorkspace.WorkspaceStatus? = nil,
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> [ExecutorWorkspace] {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/executor/workspaces"), resolvingAgainstBaseURL: false)!
        var queryItems: [URLQueryItem] = []

        if let executorDeviceId = executorDeviceId {
            queryItems.append(URLQueryItem(name: "executor_device_id", value: executorDeviceId))
        }
        if let agentId = agentId {
            queryItems.append(URLQueryItem(name: "agent_id", value: agentId))
        }
        if let status = status {
            queryItems.append(URLQueryItem(name: "status", value: status.rawValue))
        }
        queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        queryItems.append(URLQueryItem(name: "offset", value: String(offset)))

        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(getAuthorizationHeader(), forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let decoder = makeDecoder()
        let workspacesResponse = try decoder.decode(ExecutorWorkspacesResponse.self, from: data)

        return workspacesResponse.workspaces
    }

    /// Update a workspace
    func updateWorkspace(id: String, updates: [String: Any]) async throws -> ExecutorWorkspace {
        let url = baseURL.appendingPathComponent("api/executor/workspaces/\(id)")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(getAuthorizationHeader(), forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        request.httpBody = try JSONSerialization.data(withJSONObject: updates)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let decoder = makeDecoder()
        let workspaceResponse = try decoder.decode([String: ExecutorWorkspace].self, from: data)

        guard let workspace = workspaceResponse["workspace"] else {
            throw APIError.decodingError(NSError(domain: "Workspace not found in response", code: -1))
        }

        return workspace
    }

    /// Delete a workspace
    func deleteWorkspace(id: String) async throws {
        let url = baseURL.appendingPathComponent("api/executor/workspaces/\(id)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(getAuthorizationHeader(), forHTTPHeaderField: "Authorization")

        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }

    // MARK: - Workspace Task Management

    /// Assign a task to a workspace
    func assignTaskToWorkspace(workspaceId: String, aiTaskId: String, config: [String: Any] = [:]) async throws -> ExecutorWorkspaceTask {
        let url = baseURL.appendingPathComponent("api/executor/workspaces/\(workspaceId)/tasks")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(getAuthorizationHeader(), forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = ["ai_task_id": aiTaskId]
        body.merge(config) { (_, new) in new }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let decoder = makeDecoder()
        let taskResponse = try decoder.decode([String: ExecutorWorkspaceTask].self, from: data)

        guard let task = taskResponse["task"] else {
            throw APIError.decodingError(NSError(domain: "Task not found in response", code: -1))
        }

        return task
    }

    /// Get workspace tasks
    func getWorkspaceTasks(workspaceId: String) async throws -> [ExecutorWorkspaceTask] {
        let url = baseURL.appendingPathComponent("api/executor/workspaces/\(workspaceId)/tasks")
        var request = URLRequest(url: url)
        request.setValue(getAuthorizationHeader(), forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let decoder = makeDecoder()
        let tasksResponse = try decoder.decode(ExecutorWorkspaceTasksResponse.self, from: data)

        return tasksResponse.tasks
    }

    /// Update workspace task status
    func updateWorkspaceTask(id: String, updates: [String: Any]) async throws -> ExecutorWorkspaceTask {
        let url = baseURL.appendingPathComponent("api/executor/tasks/\(id)")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(getAuthorizationHeader(), forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        request.httpBody = try JSONSerialization.data(withJSONObject: updates)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let decoder = makeDecoder()
        let taskResponse = try decoder.decode([String: ExecutorWorkspaceTask].self, from: data)

        guard let task = taskResponse["task"] else {
            throw APIError.decodingError(NSError(domain: "Task not found in response", code: -1))
        }

        return task
    }

    // MARK: - Event Logging

    /// Log a workspace event
    func logWorkspaceEvent(workspaceId: String, event: ExecutorWorkspaceEvent) async throws {
        let url = baseURL.appendingPathComponent("api/executor/workspaces/\(workspaceId)/events")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(getAuthorizationHeader(), forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(event)

        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }

    /// Get workspace events
    func getWorkspaceEvents(workspaceId: String, limit: Int = 100) async throws -> [ExecutorWorkspaceEvent] {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/executor/workspaces/\(workspaceId)/events"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "limit", value: String(limit))]

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(getAuthorizationHeader(), forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let decoder = makeDecoder()
        let eventsResponse = try decoder.decode(ExecutorEventsResponse.self, from: data)

        return eventsResponse.events
    }

    // MARK: - Artifact Management

    /// Upload a workspace artifact
    func uploadArtifact(workspaceId: String, artifact: ExecutorWorkspaceArtifact) async throws -> ExecutorWorkspaceArtifact {
        let url = baseURL.appendingPathComponent("api/executor/workspaces/\(workspaceId)/artifacts")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(getAuthorizationHeader(), forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(artifact)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let decoder = makeDecoder()
        let artifactResponse = try decoder.decode([String: ExecutorWorkspaceArtifact].self, from: data)

        guard let artifact = artifactResponse["artifact"] else {
            throw APIError.decodingError(NSError(domain: "Artifact not found in response", code: -1))
        }

        return artifact
    }

    /// Get workspace artifacts
    func getWorkspaceArtifacts(workspaceId: String, artifactType: ExecutorWorkspaceArtifact.ArtifactType? = nil) async throws -> [ExecutorWorkspaceArtifact] {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/executor/workspaces/\(workspaceId)/artifacts"), resolvingAgainstBaseURL: false)!

        if let artifactType = artifactType {
            components.queryItems = [URLQueryItem(name: "artifact_type", value: artifactType.rawValue)]
        }

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(getAuthorizationHeader(), forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let decoder = makeDecoder()
        let artifactsResponse = try decoder.decode(ExecutorArtifactsResponse.self, from: data)

        return artifactsResponse.artifacts
    }

    // MARK: - Metrics Recording

    /// Record workspace metrics
    func recordMetrics(workspaceId: String, metrics: ExecutorWorkspaceMetric) async throws {
        let url = baseURL.appendingPathComponent("api/executor/workspaces/\(workspaceId)/metrics")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(getAuthorizationHeader(), forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(metrics)

        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }

    /// Get workspace metrics
    func getWorkspaceMetrics(workspaceId: String, limit: Int = 100) async throws -> [ExecutorWorkspaceMetric] {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/executor/workspaces/\(workspaceId)/metrics"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "limit", value: String(limit))]

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(getAuthorizationHeader(), forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let decoder = makeDecoder()
        let metricsResponse = try decoder.decode(ExecutorMetricsResponse.self, from: data)

        return metricsResponse.metrics
    }
}
