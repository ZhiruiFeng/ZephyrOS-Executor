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
                case .aiTasks:
                    AITasksView()
                case .executor:
                    ExecutorConfigurationView()
                case .logs:
                    LogsView()
                case .profile:
                    ProfileView()
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
    case aiTasks = "AI Tasks"
    case executor = "Executor"
    case logs = "Logs"
    case profile = "Profile"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .dashboard: return "gauge.badge.plus"
        case .tasks: return "checklist"
        case .aiTasks: return "sparkles"
        case .executor: return "server.rack"
        case .logs: return "list.bullet.rectangle"
        case .profile: return "person.circle.fill"
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
