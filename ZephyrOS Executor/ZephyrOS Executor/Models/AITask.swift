//
//  AITask.swift
//  ZephyrOS Executor
//
//  AI Task data model matching the database schema
//

import Foundation
import SwiftUI

enum AITaskMode: String, Codable, CaseIterable {
    case planOnly = "plan_only"
    case dryRun = "dry_run"
    case execute = "execute"

    var displayName: String {
        switch self {
        case .planOnly: return "Plan Only"
        case .dryRun: return "Dry Run"
        case .execute: return "Execute"
        }
    }

    var color: Color {
        switch self {
        case .planOnly: return .blue
        case .dryRun: return .orange
        case .execute: return .purple
        }
    }
}

enum AITaskStatus: String, Codable, CaseIterable {
    case pending
    case assigned
    case inProgress = "in_progress"
    case paused
    case completed
    case failed
    case cancelled

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .assigned: return "Assigned"
        case .inProgress: return "In Progress"
        case .paused: return "Paused"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }

    var color: Color {
        switch self {
        case .pending: return .gray
        case .assigned: return .blue
        case .inProgress: return .blue
        case .paused: return .yellow
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .gray
        }
    }

    var icon: String {
        switch self {
        case .pending: return "clock"
        case .assigned: return "checkmark.circle"
        case .inProgress: return "arrow.triangle.2.circlepath"
        case .paused: return "pause.circle"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .cancelled: return "xmark.circle"
        }
    }
}

struct AITaskGuardrails: Codable, Equatable {
    var costCapUSD: Double?
    var timeCapMin: Int?
    var requiresHumanApproval: Bool?
    var dataScopes: [String]?

    enum CodingKeys: String, CodingKey {
        case costCapUSD
        case timeCapMin
        case requiresHumanApproval
        case dataScopes
    }
}

struct AITaskMetadata: Codable, Equatable {
    var priority: TaskPriority?
    var tags: [String]?
}

struct AITask: Identifiable, Codable, Equatable {
    let id: String
    let taskId: String
    let agentId: String
    var objective: String
    var deliverables: String?
    var context: String?
    var acceptanceCriteria: String?
    let taskType: String
    var dependencies: [String]?
    var mode: AITaskMode
    var guardrails: AITaskGuardrails?
    var metadata: AITaskMetadata?
    var status: AITaskStatus
    var history: [AITaskHistoryEntry]?
    var executionResult: AITaskExecutionResult?
    var estimatedCostUSD: Double?
    var actualCostUSD: Double?
    var estimatedDurationMin: Int?
    var actualDurationMin: Int?
    let assignedAt: Date
    var startedAt: Date?
    var completedAt: Date?
    var dueAt: Date?

    // Computed properties
    var statusColor: Color {
        status.color
    }

    var statusIcon: String {
        status.icon
    }

    var elapsedTime: TimeInterval? {
        guard let startedAt = startedAt else { return nil }
        let endTime = completedAt ?? Date()
        return endTime.timeIntervalSince(startedAt)
    }

    var isActive: Bool {
        status == .assigned || status == .inProgress
    }

    var isCompleted: Bool {
        status == .completed || status == .failed || status == .cancelled
    }

    enum CodingKeys: String, CodingKey {
        case id
        case taskId = "task_id"
        case agentId = "agent_id"
        case objective
        case deliverables
        case context
        case acceptanceCriteria = "acceptance_criteria"
        case taskType = "task_type"
        case dependencies
        case mode
        case guardrails
        case metadata
        case status
        case history
        case executionResult = "execution_result"
        case estimatedCostUSD = "estimated_cost_usd"
        case actualCostUSD = "actual_cost_usd"
        case estimatedDurationMin = "estimated_duration_min"
        case actualDurationMin = "actual_duration_min"
        case assignedAt = "assigned_at"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case dueAt = "due_at"
    }
}

struct AITaskHistoryEntry: Codable, Equatable {
    let timestamp: Date
    let action: String
    let oldValues: [String: AnyCodable]?
    let newValues: [String: AnyCodable]?
    let userId: String?

    enum CodingKeys: String, CodingKey {
        case timestamp
        case action
        case oldValues = "old_values"
        case newValues = "new_values"
        case userId = "user_id"
    }
}

struct AITaskExecutionResult: Codable, Equatable {
    var output: String?
    var artifacts: [String]?
    var logs: String?
    var error: String?
}

// Agent info for display
struct AIAgent: Identifiable, Codable {
    let id: String
    let name: String
    let description: String?
    let vendorId: String
    let modelName: String?
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case vendorId = "vendor_id"
        case modelName = "model_name"
        case isActive = "is_active"
    }
}

// Task info for display
struct SimpleTask: Identifiable, Codable {
    let id: String
    let title: String
    let status: String
}

// API Response wrappers
struct AITasksResponse: Codable {
    let aiTasks: [AITask]

    enum CodingKeys: String, CodingKey {
        case aiTasks = "ai_tasks"
    }
}

struct AIAgentsResponse: Codable {
    let agents: [AIAgent]
}

struct SimpleTasksResponse: Codable {
    let tasks: [SimpleTask]
}
