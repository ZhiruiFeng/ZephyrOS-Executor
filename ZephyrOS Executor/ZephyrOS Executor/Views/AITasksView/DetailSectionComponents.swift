//
//  DetailSectionComponents.swift
//  ZephyrOS Executor
//
//  Detail section components for AI Tasks view
//

import SwiftUI

struct InfoCard: View {
    let icon: String
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(content)
                .font(.callout)
                .fontWeight(.medium)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct DetailSection: View {
    let title: String
    let icon: String
    let content: String
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.headline)

            Text(content)
                .font(.body)
                .lineLimit(isExpanded ? nil : 3)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)

            if content.count > 150 {
                Button(isExpanded ? "Show less" : "Show more") {
                    isExpanded.toggle()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
    }
}

struct GuardrailsSection: View {
    let guardrails: AITaskGuardrails

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Guardrails", systemImage: "shield")
                .font(.headline)

            VStack(spacing: 8) {
                if let costCap = guardrails.costCapUSD {
                    GuardrailRow(icon: "dollarsign.circle", label: "Cost Cap", value: "$\(String(format: "%.2f", costCap))")
                }
                if let timeCap = guardrails.timeCapMin {
                    GuardrailRow(icon: "clock", label: "Time Cap", value: "\(timeCap) min")
                }
                if let requiresApproval = guardrails.requiresHumanApproval {
                    GuardrailRow(
                        icon: requiresApproval ? "person.fill.checkmark" : "person.fill.xmark",
                        label: "Human Approval",
                        value: requiresApproval ? "Required" : "Not Required"
                    )
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
    }
}

struct GuardrailRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.callout)
            Spacer()
            Text(value)
                .font(.callout)
                .foregroundColor(.secondary)
        }
    }
}

struct ExecutionResultSection: View {
    let result: AITaskExecutionResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Execution Result", systemImage: "terminal")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                if let output = result.output {
                    ResultBlock(title: "Output", content: output, color: .green)
                }
                if let error = result.error {
                    ResultBlock(title: "Error", content: error, color: .red)
                }
                if let logs = result.logs {
                    ResultBlock(title: "Logs", content: logs, color: .blue)
                }
            }
        }
    }
}

struct ResultBlock: View {
    let title: String
    let content: String
    let color: Color
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Text(title)
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(color)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                ScrollView {
                    Text(content)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 200)
                .padding(8)
                .background(color.opacity(0.1))
                .cornerRadius(6)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}
