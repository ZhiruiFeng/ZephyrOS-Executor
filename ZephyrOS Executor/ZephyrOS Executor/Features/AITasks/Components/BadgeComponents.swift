//
//  BadgeComponents.swift
//  ZephyrOS Executor
//
//  Badge components for AI Tasks view
//

import SwiftUI

struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.2)))
            .foregroundColor(color)
    }
}

struct ModeBadge: View {
    let mode: AITaskMode

    var body: some View {
        Text(mode.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(mode.color.opacity(0.2)))
            .foregroundColor(mode.color)
    }
}

struct PriorityBadge: View {
    let priority: TaskPriority

    var priorityColor: Color {
        switch priority {
        case .low: return .gray
        case .medium: return .blue
        case .normal: return .blue
        case .high: return .orange
        case .urgent: return .red
        }
    }

    var body: some View {
        Text(priority.rawValue.capitalized)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(priorityColor.opacity(0.2)))
            .foregroundColor(priorityColor)
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.blue : Color(nsColor: .controlBackgroundColor))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}
