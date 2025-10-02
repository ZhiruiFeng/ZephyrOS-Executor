//
//  TimelineAndCostComponents.swift
//  ZephyrOS Executor
//
//  Timeline and cost components for AI Tasks view
//

import SwiftUI

struct TimelineSection: View {
    let task: AITask

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Timeline", systemImage: "clock")
                .font(.headline)

            VStack(spacing: 8) {
                TimelineRow(icon: "plus.circle", label: "Assigned", date: task.assignedAt)
                if let startedAt = task.startedAt {
                    TimelineRow(icon: "play.circle", label: "Started", date: startedAt)
                }
                if let completedAt = task.completedAt {
                    TimelineRow(icon: "checkmark.circle.fill", label: "Completed", date: completedAt)
                }
                if let dueAt = task.dueAt {
                    TimelineRow(icon: "bell", label: "Due", date: dueAt, isWarning: Date() > dueAt && !task.isCompleted)
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
    }
}

struct TimelineRow: View {
    let icon: String
    let label: String
    let date: Date
    var isWarning: Bool = false

    var body: some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.callout)
                .foregroundColor(isWarning ? .orange : .primary)
            Spacer()
            Text(date, style: .relative)
                .font(.callout)
                .foregroundColor(.secondary)
        }
    }
}

struct CostSection: View {
    let task: AITask

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Cost Tracking", systemImage: "dollarsign.circle")
                .font(.headline)

            HStack(spacing: 16) {
                if let estimated = task.estimatedCostUSD {
                    CostCard(title: "Estimated", amount: estimated, color: .blue)
                }
                if let actual = task.actualCostUSD {
                    CostCard(title: "Actual", amount: actual, color: .green)
                }
            }
        }
    }
}

struct CostCard: View {
    let title: String
    let amount: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text("$\(String(format: "%.4f", amount))")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}
