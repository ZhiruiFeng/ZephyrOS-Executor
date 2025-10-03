//
//  AITasksHeader.swift
//  ZephyrOS Executor
//
//  Header component for AI Tasks view
//

import SwiftUI

struct AITasksHeader: View {
    @Binding var selectedFilter: AITaskFilter
    @Binding var selectedTab: AITaskTab
    @Binding var searchText: String
    let onRefresh: () async -> Void
    @State private var isRefreshing = false

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Task Grantor")
                        .font(.system(size: 28, weight: .bold))
                    Text("Design and assign tasks to AI agents with clear objectives")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search tasks...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .frame(width: 250)

                // Refresh button
                Button(action: {
                    isRefreshing = true
                    _Concurrency.Task {
                        await onRefresh()
                        isRefreshing = false
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                        .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                }
                .buttonStyle(.plain)
                .disabled(isRefreshing)
            }

            // Tabs and filters
            HStack(spacing: 12) {
                // Tabs
                HStack(spacing: 4) {
                    ForEach(AITaskTab.allCases, id: \.self) { tab in
                        Button(action: { selectedTab = tab }) {
                            Text(tab.rawValue)
                                .font(.caption)
                                .fontWeight(selectedTab == tab ? .semibold : .regular)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(selectedTab == tab ? Color.blue : Color.clear)
                                )
                                .foregroundColor(selectedTab == tab ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )

                Divider()
                    .frame(height: 20)

                // Filters
                HStack(spacing: 8) {
                    ForEach(AITaskFilter.allCases, id: \.self) { filter in
                        FilterChip(
                            title: filter.rawValue,
                            isSelected: selectedFilter == filter,
                            action: { selectedFilter = filter }
                        )
                    }
                }

                Spacer()
            }
        }
    }
}
