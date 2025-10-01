//
//  Task.swift
//  ZephyrOS Executor
//
//  Task data model
//

import Foundation
import SwiftUI

enum TaskStatus: String, Codable {
    case pending
    case accepted
    case inProgress = "in_progress"
    case completed
    case failed
}

enum TaskPriority: String, Codable {
    case low
    case normal
    case high
}

struct Task: Identifiable, Codable, Equatable {
    let id: String
    var description: String
    var context: [String: AnyCodable]
    var status: TaskStatus
    var priority: TaskPriority
    var progress: Int
    var createdAt: Date
    var acceptedAt: Date?
    var completedAt: Date?
    var failedAt: Date?
    var agent: String?
    var result: TaskResult?
    var error: String?

    var statusColor: Color {
        switch status {
        case .pending: return .gray
        case .accepted: return .blue
        case .inProgress: return .blue
        case .completed: return .green
        case .failed: return .red
        }
    }

    var statusIcon: String {
        switch status {
        case .pending: return "clock"
        case .accepted: return "checkmark.circle"
        case .inProgress: return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }

    var elapsedTime: TimeInterval? {
        guard let acceptedAt = acceptedAt else { return nil }
        let endTime = completedAt ?? failedAt ?? Date()
        return endTime.timeIntervalSince(acceptedAt)
    }
}

struct TaskResult: Codable, Equatable {
    var response: String
    var usage: TokenUsage?
    var model: String
    var executionTimeSeconds: Double

    enum CodingKeys: String, CodingKey {
        case response
        case usage
        case model
        case executionTimeSeconds = "execution_time_seconds"
    }
}

struct TokenUsage: Codable, Equatable {
    var inputTokens: Int
    var outputTokens: Int
    var totalTokens: Int

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case totalTokens = "total_tokens"
    }
}

// Helper for encoding/decoding Any values
struct AnyCodable: Codable, Equatable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            value = arrayValue.map { $0.value }
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            value = dictValue.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let arrayValue as [Any]:
            try container.encode(arrayValue.map { AnyCodable($0) })
        case let dictValue as [String: Any]:
            try container.encode(dictValue.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }

    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        String(describing: lhs.value) == String(describing: rhs.value)
    }
}
