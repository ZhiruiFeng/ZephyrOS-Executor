//
//  AITasksHelpers.swift
//  ZephyrOS Executor
//
//  Helper enums and views for AI Tasks
//

import SwiftUI

// MARK: - Enums

enum AITaskFilter: String, CaseIterable {
    case all = "All"
    case planOnly = "Plan Only"
    case dryRun = "Dry Run"
    case execute = "Execute"
}

enum AITaskTab: String, CaseIterable {
    case pending = "Pending"
    case history = "History"
}

// MARK: - Setup Required View

struct SetupRequiredView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "gearshape.2")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("Configuration Required")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Please configure your ZMemory API URL in Settings to use AI Tasks")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Text("1.")
                        .fontWeight(.semibold)
                    Text("Open Settings from the sidebar")
                }
                HStack(alignment: .top, spacing: 12) {
                    Text("2.")
                        .fontWeight(.semibold)
                    Text("Enter your ZMemory API URL (e.g., http://localhost:3000)")
                }
                HStack(alignment: .top, spacing: 12) {
                    Text("3.")
                        .fontWeight(.semibold)
                    Text("Sign in with Google OAuth if not already signed in")
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
