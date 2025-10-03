//
//  ActionComponents.swift
//  ZephyrOS Executor
//
//  Action button and error banner components for AI Tasks view
//

import SwiftUI

struct AITaskActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let isLoading: Bool
    let action: () async -> Void

    var body: some View {
        Button(action: {
            _Concurrency.Task {
                await action()
            }
        }) {
            HStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: icon)
                }
                Text(title)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(color)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.white)
            Text(message)
                .font(.callout)
                .foregroundColor(.white)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color.red)
    }
}
