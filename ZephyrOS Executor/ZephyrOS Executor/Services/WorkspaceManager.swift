//
//  WorkspaceManager.swift
//  ZephyrOS Executor
//
//  Manager for local workspace operations - directory creation, file management, lifecycle
//

import Foundation
import Combine

class WorkspaceManager: ObservableObject {
    static let shared = WorkspaceManager()

    private let fileManager = FileManager.default

    @Published var currentDevice: ExecutorDevice?
    @Published var activeWorkspaces: [ExecutorWorkspace] = []
    @Published var isHeartbeatActive = false

    private var heartbeatTimer: Timer?
    private let heartbeatInterval: TimeInterval = 30 // 30 seconds

    private init() {}

    // Get client from ExecutorManager
    private var client: ZMemoryClient? {
        ExecutorManager.shared.getZMemoryClient()
    }

    // MARK: - Device Registration

    /// Register this device as an executor
    func registerDevice(deviceName: String? = nil, rootPath: String? = nil, maxConcurrent: Int = 5) async throws -> ExecutorDevice {
        guard let client = client else {
            throw WorkspaceError.clientNotAvailable
        }

        let deviceId = getDeviceIdentifier()
        let name = deviceName ?? Host.current().localizedName ?? "Unknown Device"
        let root = rootPath ?? getDefaultWorkspaceRoot()

        // Create root workspace directory
        try createDirectoryIfNeeded(at: root)

        var device = ExecutorDevice(
            id: "", // Will be assigned by backend
            userId: "", // Will be assigned by backend
            deviceName: name,
            deviceId: deviceId,
            platform: "macos",
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            executorVersion: "0.1.0",
            rootWorkspacePath: root,
            maxConcurrentWorkspaces: maxConcurrent,
            maxDiskUsageGb: 100,
            defaultShell: "/bin/zsh",
            defaultTimeoutMinutes: 60,
            allowedCommands: nil,
            environmentVars: nil,
            systemPrompt: nil,
            claudeCodePath: nil,
            features: nil,
            status: .active,
            isOnline: true,
            lastHeartbeatAt: Date(),
            currentWorkspacesCount: 0,
            currentDiskUsageGb: 0.0,
            notes: nil,
            tags: nil,
            createdAt: Date(),
            updatedAt: Date(),
            lastOnlineAt: Date()
        )

        let registered = try await client.registerDevice(device)

        await MainActor.run {
            self.currentDevice = registered
        }

        // Start heartbeat
        startHeartbeat()

        return registered
    }

    /// Get existing device or register if needed (auto-registers on first launch)
    func ensureDeviceRegistered() async throws -> ExecutorDevice {
        guard let client = client else {
            throw WorkspaceError.clientNotAvailable
        }

        if let device = currentDevice {
            return device
        }

        // Try to find existing device by hardware UUID
        let devices = try await client.listDevices(status: nil, isOnline: nil)
        let deviceId = getDeviceIdentifier()

        if let existing = devices.first(where: { $0.deviceId == deviceId }) {
            await MainActor.run {
                self.currentDevice = existing
            }
            startHeartbeat()
            return existing
        }

        // Auto-register new device on first launch with default settings
        return try await registerDevice()
    }

    /// Update device configuration (for user modifications)
    func updateDeviceConfiguration(
        deviceName: String? = nil,
        rootPath: String? = nil,
        maxConcurrent: Int? = nil,
        maxDiskUsage: Int? = nil,
        defaultShell: String? = nil,
        defaultTimeout: Int? = nil
    ) async throws -> ExecutorDevice {
        guard let client = client else {
            throw WorkspaceError.clientNotAvailable
        }

        guard let deviceId = currentDevice?.id else {
            throw WorkspaceError.noDeviceRegistered
        }

        var updates: [String: Any] = [:]

        if let deviceName = deviceName {
            updates["device_name"] = deviceName
        }
        if let rootPath = rootPath {
            updates["root_workspace_path"] = rootPath
        }
        if let maxConcurrent = maxConcurrent {
            updates["max_concurrent_workspaces"] = maxConcurrent
        }
        if let maxDiskUsage = maxDiskUsage {
            updates["max_disk_usage_gb"] = maxDiskUsage
        }
        if let defaultShell = defaultShell {
            updates["default_shell"] = defaultShell
        }
        if let defaultTimeout = defaultTimeout {
            updates["default_timeout_minutes"] = defaultTimeout
        }

        let updated = try await client.updateDevice(id: deviceId, updates: updates)

        await MainActor.run {
            self.currentDevice = updated
        }

        return updated
    }

    // MARK: - Workspace Lifecycle

    /// Create a new workspace with custom parameters
    func createWorkspace(
        agentId: String,
        workspacePath: String? = nil,
        projectName: String? = nil,
        projectType: String? = nil,
        repoUrl: String? = nil,
        branch: String = "main",
        systemPrompt: String? = nil,
        allowedCommands: [String]? = nil,
        environmentVars: [String: String]? = nil,
        executionTimeoutMinutes: Int = 60,
        maxDiskUsageMb: Int = 10240,
        enableNetwork: Bool = true,
        enableGit: Bool = true
    ) async throws -> ExecutorWorkspace {
        guard let client = client else {
            throw WorkspaceError.clientNotAvailable
        }

        let device = try await ensureDeviceRegistered()

        // Check capacity
        if device.availableSlots <= 0 {
            throw WorkspaceError.noAvailableSlots
        }

        // Use provided path or generate one
        let finalWorkspacePath = workspacePath ?? generateWorkspacePath(device: device, taskId: UUID().uuidString)

        // Create workspace directory structure locally first
        try createDirectoryIfNeeded(at: finalWorkspacePath)

        // Create workspace
        let workspace = ExecutorWorkspace(
            id: UUID().uuidString,
            executorDeviceId: device.id,
            agentId: agentId,
            userId: "",
            workspacePath: finalWorkspacePath,
            relativePath: finalWorkspacePath.replacingOccurrences(of: device.rootWorkspacePath, with: ""),
            metadataPath: nil,
            repoUrl: repoUrl,
            repoBranch: branch,
            projectType: projectType,
            projectName: projectName ?? "Agent Workspace",
            allowedCommands: allowedCommands,
            environmentVars: environmentVars,
            systemPrompt: systemPrompt,
            executionTimeoutMinutes: executionTimeoutMinutes,
            enableNetwork: enableNetwork,
            enableGit: enableGit,
            maxDiskUsageMb: maxDiskUsageMb,
            status: .creating,
            progressPercentage: 0,
            currentPhase: "Creating workspace",
            currentStep: nil,
            lastHeartbeatAt: nil,
            diskUsageBytes: 0,
            fileCount: 0,
            createdAt: Date(),
            initializedAt: nil,
            readyAt: nil,
            archivedAt: nil,
            updatedAt: Date()
        )

        await MainActor.run {
            activeWorkspaces.append(workspace)
        }

        // Setup directories asynchronously
        _Concurrency.Task {
            do {
                try await setupWorkspaceDirectories(workspace: workspace)
            } catch {
                try? await updateWorkspaceStatus(id: workspace.id, status: .failed, error: error.localizedDescription)
            }
        }

        return workspace
    }

    /// Create a new workspace for a task
    func createWorkspace(for task: AITask, agent: AIAgent? = nil) async throws -> ExecutorWorkspace {
        guard let client = client else {
            throw WorkspaceError.clientNotAvailable
        }

        let device = try await ensureDeviceRegistered()

        // Check capacity
        if device.availableSlots <= 0 {
            throw WorkspaceError.noAvailableSlots
        }

        // Generate workspace path
        let workspacePath = generateWorkspacePath(device: device, taskId: task.id)

        // For now, create a minimal workspace structure
        // TODO: Full workspace creation with all fields based on ExecutorModels.swift
        // This is a simplified version for initial implementation

        // Create workspace directory structure locally first
        try createDirectoryIfNeeded(at: workspacePath)

        // Return a stub workspace for now
        // In production, this will call the backend API
        let workspace = ExecutorWorkspace(
            id: UUID().uuidString,
            executorDeviceId: device.id,
            agentId: agent?.id ?? "",
            userId: "",
            workspacePath: workspacePath,
            relativePath: workspacePath.replacingOccurrences(of: device.rootWorkspacePath, with: ""),
            metadataPath: nil,
            repoUrl: nil,  // AITask doesn't have repository info
            repoBranch: "main",
            projectType: nil,
            projectName: task.objective.prefix(50).description,
            allowedCommands: nil,
            environmentVars: nil,
            systemPrompt: nil,
            executionTimeoutMinutes: 60,
            enableNetwork: true,
            enableGit: true,
            maxDiskUsageMb: 10240,
            status: .creating,
            progressPercentage: 0,
            currentPhase: "Creating workspace",
            currentStep: nil,
            lastHeartbeatAt: nil,
            diskUsageBytes: 0,
            fileCount: 0,
            createdAt: Date(),
            initializedAt: nil,
            readyAt: nil,
            archivedAt: nil,
            updatedAt: Date()
        )

        // TODO: Create workspace on backend
        // let created = try await client.createWorkspace(workspace)

        await MainActor.run {
            activeWorkspaces.append(workspace)
        }

        // Setup directories asynchronously
        _Concurrency.Task {
            do {
                try await setupWorkspaceDirectories(workspace: workspace)
            } catch {
                try? await updateWorkspaceStatus(id: workspace.id, status: .failed, error: error.localizedDescription)
            }
        }

        return workspace
    }

    /// Setup workspace directory structure
    func setupWorkspaceDirectories(workspace: ExecutorWorkspace) async throws {
        try await updateWorkspaceProgress(id: workspace.id, phase: "Creating directories", progress: 10)

        // Create main workspace directory
        try createDirectoryIfNeeded(at: workspace.workspacePath)

        // Create subdirectories
        let subdirs = ["src", "output", "logs", "artifacts", "temp"]
        for subdir in subdirs {
            let path = (workspace.workspacePath as NSString).appendingPathComponent(subdir)
            try createDirectoryIfNeeded(at: path)
        }

        // Create .workspace metadata file
        try createWorkspaceMetadata(workspace: workspace)

        try await updateWorkspaceProgress(id: workspace.id, phase: "Directories created", progress: 30)

        // Clone repository if provided
        if workspace.repoUrl != nil {
            try await cloneRepository(workspace: workspace)
        } else {
            // No repo to clone, mark as ready
            try await updateWorkspaceStatus(id: workspace.id, status: .ready)
        }
    }

    /// Clone repository into workspace
    func cloneRepository(workspace: ExecutorWorkspace) async throws {
        guard let repoUrl = workspace.repoUrl else {
            throw WorkspaceError.noRepositoryUrl
        }

        try await updateWorkspaceProgress(id: workspace.id, phase: "Cloning repository", progress: 40)

        let srcPath = (workspace.workspacePath as NSString).appendingPathComponent("src")

        // Execute git clone
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["clone", repoUrl, srcPath]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw WorkspaceError.cloneFailed(output)
        }

        try await updateWorkspaceProgress(id: workspace.id, phase: "Repository cloned", progress: 70)

        // Checkout specific branch
        if workspace.repoBranch != "main" && workspace.repoBranch != "master" {
            try await checkoutBranch(workspace: workspace, branch: workspace.repoBranch)
        }

        // Mark as ready
        try await updateWorkspaceStatus(id: workspace.id, status: .ready)
    }

    /// Checkout specific branch
    private func checkoutBranch(workspace: ExecutorWorkspace, branch: String) async throws {
        try await updateWorkspaceProgress(id: workspace.id, phase: "Checking out branch \(branch)", progress: 80)

        let srcPath = (workspace.workspacePath as NSString).appendingPathComponent("src")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", srcPath, "checkout", branch]

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw WorkspaceError.checkoutFailed(branch)
        }
    }

    /// Update workspace progress
    func updateWorkspaceProgress(id: String, phase: String, progress: Int) async throws {
        guard let client = client else {
            throw WorkspaceError.clientNotAvailable
        }

        let updates: [String: Any] = [
            "current_phase": phase,
            "progress_percentage": progress
        ]

        let updated = try await client.updateWorkspace(id: id, updates: updates)

        await MainActor.run {
            if let index = activeWorkspaces.firstIndex(where: { $0.id == id }) {
                activeWorkspaces[index] = updated
            }
        }
    }

    /// Update workspace status
    func updateWorkspaceStatus(id: String, status: ExecutorWorkspace.WorkspaceStatus, error: String? = nil) async throws {
        guard let client = client else {
            throw WorkspaceError.clientNotAvailable
        }

        var updates: [String: Any] = [
            "status": status.rawValue,
            "progress_percentage": status == .ready ? 100 : (status == .failed ? 0 : nil) as Any
        ]

        if let error = error {
            updates["error_message"] = error
        }

        let updated = try await client.updateWorkspace(id: id, updates: updates)

        await MainActor.run {
            if let index = activeWorkspaces.firstIndex(where: { $0.id == id }) {
                activeWorkspaces[index] = updated
            }
        }
    }

    /// Cleanup workspace (delete local files)
    func cleanupWorkspace(id: String) async throws {
        guard let workspace = activeWorkspaces.first(where: { $0.id == id }) else {
            throw WorkspaceError.workspaceNotFound(id)
        }

        // Update status to cleanup
        try await updateWorkspaceStatus(id: id, status: .cleanup)

        // Delete local directory
        if fileManager.fileExists(atPath: workspace.workspacePath) {
            try fileManager.removeItem(atPath: workspace.workspacePath)
        }

        // Update status to archived
        try await updateWorkspaceStatus(id: id, status: .archived)

        await MainActor.run {
            activeWorkspaces.removeAll { $0.id == id }
        }
    }

    /// Archive workspace (create tar.gz before cleanup)
    func archiveWorkspace(id: String) async throws -> URL {
        guard let client = client else {
            throw WorkspaceError.clientNotAvailable
        }

        guard let workspace = activeWorkspaces.first(where: { $0.id == id }) else {
            throw WorkspaceError.workspaceNotFound(id)
        }

        guard let device = currentDevice else {
            throw WorkspaceError.noDeviceRegistered
        }

        // Create archives directory
        let archivesPath = (device.rootWorkspacePath as NSString).appendingPathComponent("archives")
        try createDirectoryIfNeeded(at: archivesPath)

        // Generate archive name
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let archiveName = "workspace-\(workspace.id)-\(timestamp).tar.gz"
        let archivePath = (archivesPath as NSString).appendingPathComponent(archiveName)

        // Create tar.gz archive
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = ["-czf", archivePath, "-C", workspace.workspacePath, "."]

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw WorkspaceError.archiveFailed
        }

        let archiveUrl = URL(fileURLWithPath: archivePath)

        // Upload as artifact
        let artifact = ExecutorWorkspaceArtifact(
            id: "",
            workspaceId: workspace.id,
            workspaceTaskId: nil,
            userId: "",
            filePath: archivePath,
            fileName: archiveName,
            fileExtension: "tar.gz",
            artifactType: .other,  // Using .other for archive type
            fileSizeBytes: try fileManager.attributesOfItem(atPath: archivePath)[.size] as? Int64,
            mimeType: "application/gzip",
            checksum: nil,
            storageType: .reference,
            content: nil,
            contentPreview: nil,
            externalUrl: nil,
            language: nil,
            lineCount: nil,
            description: "Workspace archive",
            tags: ["archive", "workspace"],
            isOutput: true,
            isModified: false,
            createdAt: Date(),
            modifiedAt: nil,
            detectedAt: Date()
        )

        try await client.uploadArtifact(workspaceId: workspace.id, artifact: artifact)

        return archiveUrl
    }

    // MARK: - Heartbeat

    private func startHeartbeat() {
        guard !isHeartbeatActive else { return }

        isHeartbeatActive = true

        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: heartbeatInterval, repeats: true) { [weak self] _ in
            guard let self = self, let client = self.client, let device = self.currentDevice else { return }

            _Concurrency.Task {
                do {
                    try await client.sendDeviceHeartbeat(id: device.id)
                } catch {
                    print("Heartbeat failed: \(error)")
                }
            }
        }

        heartbeatTimer?.fire() // Send immediately
    }

    private func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        isHeartbeatActive = false
    }

    // MARK: - Helper Methods

    private func getDeviceIdentifier() -> String {
        // Use hardware UUID as stable device identifier
        if let uuid = getHardwareUUID() {
            return uuid
        }

        // Fallback to hostname-based identifier
        return Host.current().localizedName ?? "unknown-device"
    }

    private func getHardwareUUID() -> String? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        defer { IOObjectRelease(service) }

        if let uuid = IORegistryEntryCreateCFProperty(service, kIOPlatformUUIDKey as CFString, kCFAllocatorDefault, 0) {
            return uuid.takeRetainedValue() as? String
        }

        return nil
    }

    private func getDefaultWorkspaceRoot() -> String {
        let home = fileManager.homeDirectoryForCurrentUser.path
        return (home as NSString).appendingPathComponent(".zephyros/workspaces")
    }

    private func getDeviceCapabilities() -> [String: Any] {
        var capabilities: [String: Any] = [:]

        #if arch(arm64)
        capabilities["architecture"] = "arm64"
        #elseif arch(x86_64)
        capabilities["architecture"] = "x86_64"
        #endif

        capabilities["os"] = "macOS"
        capabilities["os_version"] = ProcessInfo.processInfo.operatingSystemVersionString

        return capabilities
    }

    private func generateWorkspacePath(device: ExecutorDevice, taskId: String) -> String {
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let dirName = "task-\(taskId)-\(timestamp)"
        return (device.rootWorkspacePath as NSString).appendingPathComponent(dirName)
    }

    private func createDirectoryIfNeeded(at path: String) throws {
        if !fileManager.fileExists(atPath: path) {
            try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
        }
    }

    private func createWorkspaceMetadata(workspace: ExecutorWorkspace) throws {
        let metadataPath = (workspace.workspacePath as NSString).appendingPathComponent(".workspace")

        let metadata: [String: Any] = [
            "workspace_id": workspace.id,
            "created_at": ISO8601DateFormatter().string(from: workspace.createdAt),
            "repository_url": workspace.repoUrl ?? "",
            "branch": workspace.repoBranch
        ]

        let data = try JSONSerialization.data(withJSONObject: metadata, options: .prettyPrinted)
        try data.write(to: URL(fileURLWithPath: metadataPath))
    }

    // MARK: - Public Query Methods

    /// Get workspace by ID
    func getWorkspace(id: String) -> ExecutorWorkspace? {
        activeWorkspaces.first { $0.id == id }
    }

    /// Refresh active workspaces from backend
    func refreshActiveWorkspaces() async throws {
        guard let client = client else {
            throw WorkspaceError.clientNotAvailable
        }

        guard let device = currentDevice else { return }

        let workspaces = try await client.listWorkspaces(
            executorDeviceId: device.id,
            status: nil
        )

        await MainActor.run {
            self.activeWorkspaces = workspaces.filter {
                $0.status != .archived && $0.status != .cleanup
            }
        }
    }
}

// MARK: - Error Types

enum WorkspaceError: LocalizedError {
    case clientNotAvailable
    case noDeviceRegistered
    case noAvailableSlots
    case workspaceNotFound(String)
    case noRepositoryUrl
    case cloneFailed(String)
    case checkoutFailed(String)
    case archiveFailed

    var errorDescription: String? {
        switch self {
        case .clientNotAvailable:
            return "ZMemory client is not available. Please ensure you are logged in."
        case .noDeviceRegistered:
            return "Device is not registered as an executor"
        case .noAvailableSlots:
            return "No available workspace slots on this device"
        case .workspaceNotFound(let id):
            return "Workspace not found: \(id)"
        case .noRepositoryUrl:
            return "No repository URL provided for workspace"
        case .cloneFailed(let output):
            return "Failed to clone repository: \(output)"
        case .checkoutFailed(let branch):
            return "Failed to checkout branch: \(branch)"
        case .archiveFailed:
            return "Failed to create workspace archive"
        }
    }
}
