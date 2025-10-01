//
//  ExecutorState.swift
//  ZephyrOS Executor
//
//  Executor state and statistics
//

import Foundation
import SwiftUI

enum ExecutorStatus: String {
    case idle
    case running
    case paused
    case error
    case disconnected
}

struct ExecutorState {
    var status: ExecutorStatus
    var isConnectedToZMemory: Bool
    var isConnectedToClaude: Bool
    var lastSyncTime: Date?
    var activeTasks: [Task]
    var queuedTasks: [Task]
    var recentTasks: [Task]

    var statusColor: Color {
        switch status {
        case .idle: return .gray
        case .running: return .blue
        case .paused: return .orange
        case .error: return .red
        case .disconnected: return .gray
        }
    }

    var statusIcon: String {
        switch status {
        case .idle: return "pause.circle"
        case .running: return "play.circle.fill"
        case .paused: return "pause.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .disconnected: return "wifi.slash"
        }
    }
}

struct ExecutorStatistics {
    var totalTasks: Int = 0
    var completedTasks: Int = 0
    var failedTasks: Int = 0
    var totalTokens: Int = 0
    var totalCost: Double = 0.0
    var averageTaskDuration: TimeInterval = 0

    var successRate: Double {
        guard totalTasks > 0 else { return 0 }
        return Double(completedTasks) / Double(totalTasks) * 100
    }

    var todayStats: DailyStatistics {
        // This would be calculated from tasks filtered by today's date
        DailyStatistics(
            tasksCompleted: completedTasks,
            tasksFailed: failedTasks,
            tokensUsed: totalTokens,
            estimatedCost: totalCost
        )
    }
}

struct DailyStatistics {
    var tasksCompleted: Int
    var tasksFailed: Int
    var tokensUsed: Int
    var estimatedCost: Double
}
