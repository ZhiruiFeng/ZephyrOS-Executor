//
//  ExecutorModels.swift
//  ZephyrOS Executor
//
//  Models for Executor system - devices, workspaces, tasks, events, artifacts, metrics
//

import Foundation
import SwiftUI

// MARK: - Executor Device

struct ExecutorDevice: Codable, Identifiable {
    let id: String
    let userId: String
    var deviceName: String
    let deviceId: String
    let platform: String
    var osVersion: String?
    var executorVersion: String?
    var rootWorkspacePath: String
    var maxConcurrentWorkspaces: Int
    var maxDiskUsageGb: Int
    var defaultShell: String
    var defaultTimeoutMinutes: Int
    var allowedCommands: [String]?
    var environmentVars: [String: String]?
    var systemPrompt: String?
    var claudeCodePath: String?
    var features: [String]?
    var status: DeviceStatus
    var isOnline: Bool
    var lastHeartbeatAt: Date?
    var currentWorkspacesCount: Int
    var currentDiskUsageGb: Double
    var notes: String?
    var tags: [String]?
    let createdAt: Date
    var updatedAt: Date
    var lastOnlineAt: Date?

    enum DeviceStatus: String, Codable, CaseIterable {
        case active, inactive, maintenance, disabled

        var displayName: String {
            switch self {
            case .active: return "Active"
            case .inactive: return "Inactive"
            case .maintenance: return "Maintenance"
            case .disabled: return "Disabled"
            }
        }

        var color: Color {
            switch self {
            case .active: return .green
            case .inactive: return .gray
            case .maintenance: return .orange
            case .disabled: return .red
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, platform, status, notes, tags, features
        case userId = "user_id"
        case deviceName = "device_name"
        case deviceId = "device_id"
        case osVersion = "os_version"
        case executorVersion = "executor_version"
        case rootWorkspacePath = "root_workspace_path"
        case maxConcurrentWorkspaces = "max_concurrent_workspaces"
        case maxDiskUsageGb = "max_disk_usage_gb"
        case defaultShell = "default_shell"
        case defaultTimeoutMinutes = "default_timeout_minutes"
        case allowedCommands = "allowed_commands"
        case environmentVars = "environment_vars"
        case systemPrompt = "system_prompt"
        case claudeCodePath = "claude_code_path"
        case isOnline = "is_online"
        case lastHeartbeatAt = "last_heartbeat_at"
        case currentWorkspacesCount = "current_workspaces_count"
        case currentDiskUsageGb = "current_disk_usage_gb"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case lastOnlineAt = "last_online_at"
    }

    // Computed properties
    var availableSlots: Int {
        max(0, maxConcurrentWorkspaces - currentWorkspacesCount)
    }

    var availableDiskGb: Double {
        max(0, Double(maxDiskUsageGb) - currentDiskUsageGb)
    }

    var isHealthy: Bool {
        isOnline && status == .active && availableSlots > 0 && availableDiskGb > 1.0
    }
}

// MARK: - Executor Workspace

struct ExecutorWorkspace: Codable, Identifiable {
    let id: String
    let executorDeviceId: String
    let agentId: String
    let userId: String
    var workspacePath: String
    var relativePath: String
    var metadataPath: String?
    var workspaceName: String // User-friendly name for the workspace
    var repoUrl: String?
    var repoBranch: String
    var projectType: String?
    var projectName: String?
    var allowedCommands: [String]?
    var environmentVars: [String: String]?
    var systemPrompt: String?
    var executionTimeoutMinutes: Int
    var enableNetwork: Bool
    var enableGit: Bool
    var maxDiskUsageMb: Int
    var status: WorkspaceStatus
    var progressPercentage: Int
    var currentPhase: String?
    var currentStep: String?
    var lastHeartbeatAt: Date?
    var diskUsageBytes: Int64
    var fileCount: Int
    let createdAt: Date
    var initializedAt: Date?
    var readyAt: Date?
    var archivedAt: Date?
    var updatedAt: Date

    enum WorkspaceStatus: String, Codable, CaseIterable {
        case creating, initializing, cloning, ready, assigned
        case running, paused, completed, failed, archived, cleanup

        var displayName: String {
            switch self {
            case .creating: return "Creating"
            case .initializing: return "Initializing"
            case .cloning: return "Cloning Repo"
            case .ready: return "Ready"
            case .assigned: return "Assigned"
            case .running: return "Running"
            case .paused: return "Paused"
            case .completed: return "Completed"
            case .failed: return "Failed"
            case .archived: return "Archived"
            case .cleanup: return "Cleaning Up"
            }
        }

        var color: Color {
            switch self {
            case .creating, .initializing, .cloning: return .blue
            case .ready: return .green
            case .assigned: return .cyan
            case .running: return .purple
            case .paused: return .orange
            case .completed: return .green
            case .failed: return .red
            case .archived: return .gray
            case .cleanup: return .yellow
            }
        }

        var icon: String {
            switch self {
            case .creating, .initializing: return "gear"
            case .cloning: return "arrow.down.doc"
            case .ready: return "checkmark.circle"
            case .assigned: return "doc.badge.gearshape"
            case .running: return "play.circle.fill"
            case .paused: return "pause.circle"
            case .completed: return "checkmark.circle.fill"
            case .failed: return "xmark.circle.fill"
            case .archived: return "archivebox"
            case .cleanup: return "trash"
            }
        }

        var isActive: Bool {
            switch self {
            case .running, .assigned, .initializing, .cloning: return true
            default: return false
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, status
        case executorDeviceId = "executor_device_id"
        case agentId = "agent_id"
        case userId = "user_id"
        case workspacePath = "workspace_path"
        case relativePath = "relative_path"
        case metadataPath = "metadata_path"
        case workspaceName = "workspace_name"
        case repoUrl = "repo_url"
        case repoBranch = "repo_branch"
        case projectType = "project_type"
        case projectName = "project_name"
        case allowedCommands = "allowed_commands"
        case environmentVars = "environment_vars"
        case systemPrompt = "system_prompt"
        case executionTimeoutMinutes = "execution_timeout_minutes"
        case enableNetwork = "enable_network"
        case enableGit = "enable_git"
        case maxDiskUsageMb = "max_disk_usage_mb"
        case progressPercentage = "progress_percentage"
        case currentPhase = "current_phase"
        case currentStep = "current_step"
        case lastHeartbeatAt = "last_heartbeat_at"
        case diskUsageBytes = "disk_usage_bytes"
        case fileCount = "file_count"
        case createdAt = "created_at"
        case initializedAt = "initialized_at"
        case readyAt = "ready_at"
        case archivedAt = "archived_at"
        case updatedAt = "updated_at"
    }

    // Computed properties
    var diskUsageMb: Double {
        Double(diskUsageBytes) / 1024.0 / 1024.0
    }

    var diskUsagePercentage: Int {
        guard maxDiskUsageMb > 0 else { return 0 }
        let usageMb = Int(diskUsageMb)
        return min(100, (usageMb * 100) / maxDiskUsageMb)
    }
}

// MARK: - Executor Workspace Task

struct ExecutorWorkspaceTask: Codable, Identifiable {
    let id: String
    let workspaceId: String
    let aiTaskId: String
    let userId: String
    let assignedAt: Date
    var startedAt: Date?
    var completedAt: Date?
    var status: TaskStatus
    var promptFilePath: String?
    var outputFilePath: String?
    var resultFilePath: String?
    var exitCode: Int?
    var outputSummary: String?
    var errorMessage: String?
    var executionDurationSeconds: Int?
    var cpuTimeSeconds: Int?
    var memoryPeakMb: Int?
    var estimatedCostUsd: Double?
    var actualCostUsd: Double?
    var retryCount: Int
    var maxRetries: Int
    let createdAt: Date
    var updatedAt: Date

    enum TaskStatus: String, Codable, CaseIterable {
        case assigned, queued, starting, running, paused
        case completed, failed, timeout, cancelled

        var displayName: String {
            switch self {
            case .assigned: return "Assigned"
            case .queued: return "Queued"
            case .starting: return "Starting"
            case .running: return "Running"
            case .paused: return "Paused"
            case .completed: return "Completed"
            case .failed: return "Failed"
            case .timeout: return "Timeout"
            case .cancelled: return "Cancelled"
            }
        }

        var color: Color {
            switch self {
            case .assigned, .queued: return .blue
            case .starting, .running: return .purple
            case .paused: return .orange
            case .completed: return .green
            case .failed, .timeout: return .red
            case .cancelled: return .gray
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, status
        case workspaceId = "workspace_id"
        case aiTaskId = "ai_task_id"
        case userId = "user_id"
        case assignedAt = "assigned_at"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case promptFilePath = "prompt_file_path"
        case outputFilePath = "output_file_path"
        case resultFilePath = "result_file_path"
        case exitCode = "exit_code"
        case outputSummary = "output_summary"
        case errorMessage = "error_message"
        case executionDurationSeconds = "execution_duration_seconds"
        case cpuTimeSeconds = "cpu_time_seconds"
        case memoryPeakMb = "memory_peak_mb"
        case estimatedCostUsd = "estimated_cost_usd"
        case actualCostUsd = "actual_cost_usd"
        case retryCount = "retry_count"
        case maxRetries = "max_retries"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // Computed properties
    var canRetry: Bool {
        (status == .failed || status == .timeout) && retryCount < maxRetries
    }

    var executionDuration: TimeInterval? {
        guard let seconds = executionDurationSeconds else { return nil }
        return TimeInterval(seconds)
    }
}

// MARK: - Executor Workspace Event

struct ExecutorWorkspaceEvent: Codable, Identifiable {
    let id: String
    let workspaceId: String
    let workspaceTaskId: String?
    let executorDeviceId: String
    let userId: String
    let eventType: String
    let eventCategory: EventCategory
    let message: String
    var details: [String: AnyCodable]?
    let level: EventLevel
    let source: String?
    let createdAt: Date

    enum EventCategory: String, Codable {
        case lifecycle, task, error, resource, system
    }

    enum EventLevel: String, Codable {
        case debug, info, warning, error, critical

        var color: Color {
            switch self {
            case .debug: return .gray
            case .info: return .blue
            case .warning: return .orange
            case .error: return .red
            case .critical: return .purple
            }
        }

        var icon: String {
            switch self {
            case .debug: return "ant"
            case .info: return "info.circle"
            case .warning: return "exclamationmark.triangle"
            case .error: return "xmark.circle"
            case .critical: return "exclamationmark.octagon"
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, message, details, level, source
        case workspaceId = "workspace_id"
        case workspaceTaskId = "workspace_task_id"
        case executorDeviceId = "executor_device_id"
        case userId = "user_id"
        case eventType = "event_type"
        case eventCategory = "event_category"
        case createdAt = "created_at"
    }
}

// MARK: - Executor Workspace Artifact

struct ExecutorWorkspaceArtifact: Codable, Identifiable {
    let id: String
    let workspaceId: String
    let workspaceTaskId: String?
    let userId: String
    var filePath: String
    var fileName: String
    var fileExtension: String?
    var artifactType: ArtifactType
    var fileSizeBytes: Int64?
    var mimeType: String?
    var checksum: String?
    var storageType: StorageType
    var content: String?
    var contentPreview: String?
    var externalUrl: String?
    var language: String?
    var lineCount: Int?
    var description: String?
    var tags: [String]?
    var isOutput: Bool
    var isModified: Bool
    let createdAt: Date
    var modifiedAt: Date?
    let detectedAt: Date

    enum ArtifactType: String, Codable, CaseIterable {
        case sourceCode = "source_code"
        case config
        case documentation
        case test
        case buildOutput = "build_output"
        case log
        case result
        case prompt
        case screenshot
        case data
        case other

        var displayName: String {
            switch self {
            case .sourceCode: return "Source Code"
            case .config: return "Configuration"
            case .documentation: return "Documentation"
            case .test: return "Test"
            case .buildOutput: return "Build Output"
            case .log: return "Log"
            case .result: return "Result"
            case .prompt: return "Prompt"
            case .screenshot: return "Screenshot"
            case .data: return "Data"
            case .other: return "Other"
            }
        }

        var icon: String {
            switch self {
            case .sourceCode: return "doc.text"
            case .config: return "gearshape"
            case .documentation: return "book"
            case .test: return "checkmark.seal"
            case .buildOutput: return "hammer"
            case .log: return "list.bullet.rectangle"
            case .result: return "chart.bar.doc.horizontal"
            case .prompt: return "text.bubble"
            case .screenshot: return "photo"
            case .data: return "tablecells"
            case .other: return "doc"
            }
        }
    }

    enum StorageType: String, Codable {
        case reference, inline, external
    }

    enum CodingKeys: String, CodingKey {
        case id, description, tags
        case workspaceId = "workspace_id"
        case workspaceTaskId = "workspace_task_id"
        case userId = "user_id"
        case filePath = "file_path"
        case fileName = "file_name"
        case fileExtension = "file_extension"
        case artifactType = "artifact_type"
        case fileSizeBytes = "file_size_bytes"
        case mimeType = "mime_type"
        case checksum
        case storageType = "storage_type"
        case content
        case contentPreview = "content_preview"
        case externalUrl = "external_url"
        case language
        case lineCount = "line_count"
        case isOutput = "is_output"
        case isModified = "is_modified"
        case createdAt = "created_at"
        case modifiedAt = "modified_at"
        case detectedAt = "detected_at"
    }

    // Computed properties
    var fileSizeMb: Double? {
        guard let bytes = fileSizeBytes else { return nil }
        return Double(bytes) / 1024.0 / 1024.0
    }

    var formattedFileSize: String {
        guard let bytes = fileSizeBytes else { return "Unknown" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Executor Workspace Metric

struct ExecutorWorkspaceMetric: Codable, Identifiable {
    let id: String
    let workspaceId: String
    let workspaceTaskId: String?
    let executorDeviceId: String
    let userId: String
    var cpuUsagePercent: Double?
    var memoryUsageMb: Int?
    var diskUsageMb: Int?
    var diskReadMb: Int?
    var diskWriteMb: Int?
    var networkInMb: Int?
    var networkOutMb: Int?
    var processCount: Int?
    var threadCount: Int?
    var openFilesCount: Int?
    var commandExecutionCount: Int?
    var commandSuccessCount: Int?
    var commandFailureCount: Int?
    var avgCommandDurationMs: Int?
    var cumulativeCostUsd: Double?
    var metricType: MetricType
    var aggregationPeriodMinutes: Int?
    let recordedAt: Date

    enum MetricType: String, Codable {
        case snapshot, aggregated, peak, average
    }

    enum CodingKeys: String, CodingKey {
        case id
        case workspaceId = "workspace_id"
        case workspaceTaskId = "workspace_task_id"
        case executorDeviceId = "executor_device_id"
        case userId = "user_id"
        case cpuUsagePercent = "cpu_usage_percent"
        case memoryUsageMb = "memory_usage_mb"
        case diskUsageMb = "disk_usage_mb"
        case diskReadMb = "disk_read_mb"
        case diskWriteMb = "disk_write_mb"
        case networkInMb = "network_in_mb"
        case networkOutMb = "network_out_mb"
        case processCount = "process_count"
        case threadCount = "thread_count"
        case openFilesCount = "open_files_count"
        case commandExecutionCount = "command_execution_count"
        case commandSuccessCount = "command_success_count"
        case commandFailureCount = "command_failure_count"
        case avgCommandDurationMs = "avg_command_duration_ms"
        case cumulativeCostUsd = "cumulative_cost_usd"
        case metricType = "metric_type"
        case aggregationPeriodMinutes = "aggregation_period_minutes"
        case recordedAt = "recorded_at"
    }

    // Computed properties
    var commandSuccessRate: Double? {
        guard let total = commandExecutionCount, total > 0,
              let success = commandSuccessCount else { return nil }
        return Double(success) / Double(total)
    }
}

// MARK: - API Response Wrappers

struct ExecutorDevicesResponse: Codable {
    let devices: [ExecutorDevice]
}

struct ExecutorWorkspacesResponse: Codable {
    let workspaces: [ExecutorWorkspace]
}

struct ExecutorWorkspaceTasksResponse: Codable {
    let tasks: [ExecutorWorkspaceTask]
}

struct ExecutorEventsResponse: Codable {
    let events: [ExecutorWorkspaceEvent]
}

struct ExecutorArtifactsResponse: Codable {
    let artifacts: [ExecutorWorkspaceArtifact]
}

struct ExecutorMetricsResponse: Codable {
    let metrics: [ExecutorWorkspaceMetric]
}

// MARK: - Resource Summary

struct WorkspaceResourceSummary: Codable {
    let totalDiskMb: Int
    let peakMemoryMb: Int
    let totalCpuTimeSeconds: Int
    let totalArtifacts: Int
    let totalEvents: Int

    enum CodingKeys: String, CodingKey {
        case totalDiskMb = "total_disk_mb"
        case peakMemoryMb = "peak_memory_mb"
        case totalCpuTimeSeconds = "total_cpu_time_seconds"
        case totalArtifacts = "total_artifacts"
        case totalEvents = "total_events"
    }
}
