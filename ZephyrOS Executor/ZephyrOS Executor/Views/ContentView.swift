//
//  ContentView.swift
//  ZephyrOS Executor
//
//  Main content view with sidebar navigation
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var executorManager: ExecutorManager
    @State private var selectedTab: SidebarItem = .dashboard

    var body: some View {
        NavigationSplitView {
            // Sidebar
            SidebarView(selection: $selectedTab)
                .frame(minWidth: 200)
        } detail: {
            // Main content area
            Group {
                switch selectedTab {
                case .dashboard:
                    DashboardView()
                case .tasks:
                    TaskQueueView()
                case .logs:
                    LogsView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
    }
}

enum SidebarItem: String, CaseIterable {
    case dashboard = "Dashboard"
    case tasks = "Tasks"
    case logs = "Logs"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .dashboard: return "gauge.badge.plus"
        case .tasks: return "checklist"
        case .logs: return "list.bullet.rectangle"
        case .settings: return "gearshape.fill"
        }
    }
}

struct SidebarView: View {
    @Binding var selection: SidebarItem

    var body: some View {
        List(SidebarItem.allCases, id: \.self, selection: $selection) { item in
            Label(item.rawValue, systemImage: item.icon)
                .tag(item)
        }
        .listStyle(.sidebar)
        .navigationTitle("ZephyrOS Executor")
    }
}
