//
//  LastTimeWidget.swift
//  LastTimeWidget
//
//  Created by Malik Jamal on 1/10/26.
//

import WidgetKit
import SwiftUI
import CoreData

struct Provider: TimelineProvider {
    typealias Entry = TaskEntry
    
    func placeholder(in context: Context) -> TaskEntry {
        TaskEntry(date: Date(), tasks: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (TaskEntry) -> ()) {
        let entry = TaskEntry(date: Date(), tasks: fetchTasks())
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<TaskEntry>) -> ()) {
        let tasks = fetchTasks()
        let entry = TaskEntry(date: Date(), tasks: tasks)
        
        // Update every minute for fresh data
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    func fetchTasks() -> [TaskData] {
        let context = PersistenceController.shared.container.viewContext
        let request = LogItem.fetchRequest()
        
        do {
            let allItems = try context.fetch(request)
            
            // Use the same sorting logic as the main app
            let sortedItems = allItems.sorted { item1, item2 in
                // Pinned tasks always come first
                if item1.isPinned && !item2.isPinned { return true }
                if item2.isPinned && !item1.isPinned { return false }
                
                let overdue1 = !item1.isPinned && isOverdue(item1)
                let overdue2 = !item2.isPinned && isOverdue(item2)
                
                // Overdue tasks come second
                if overdue1 && !overdue2 { return true }
                if overdue2 && !overdue1 { return false }
                
                let neverCompleted1 = !item1.isPinned && !isOverdue(item1) && item1.lastCompletedAt == nil
                let neverCompleted2 = !item2.isPinned && !isOverdue(item2) && item2.lastCompletedAt == nil
                
                // Never completed tasks come third
                if neverCompleted1 && !neverCompleted2 { return true }
                if neverCompleted2 && !neverCompleted1 { return false }
                
                // Within same category, use sortOrder
                if (item1.isPinned && item2.isPinned) || 
                   (overdue1 && overdue2) || 
                   (neverCompleted1 && neverCompleted2) {
                    return item1.sortOrder < item2.sortOrder
                }
                
                // Completed tasks (most recent first)
                let date1 = item1.lastCompletedAt ?? Date.distantPast
                let date2 = item2.lastCompletedAt ?? Date.distantPast
                return date1 > date2
            }
            
            return sortedItems.prefix(6).map { item in
                TaskData(
                    title: item.title ?? "Untitled",
                    lastCompleted: item.lastCompletedAt,
                    reminderDate: item.reminderDate,
                    isPinned: item.isPinned
                )
            }
        } catch {
            #if DEBUG
            print("⚠️ Widget failed to fetch tasks: \(error.localizedDescription)")
            #endif
            return []
        }
    }
    
    /// Check if a log item is overdue
    private func isOverdue(_ item: LogItem) -> Bool {
        guard let reminderDate = item.reminderDate else { return false }
        return Date() > reminderDate
    }
}

struct TaskData: Identifiable {
    let id = UUID()
    let title: String
    let lastCompleted: Date?
    let reminderDate: Date?
    let isPinned: Bool
    
    /// Cached overdue status
    var isOverdue: Bool {
        guard let reminderDate = reminderDate else { return false }
        return Date() > reminderDate
    }
    
    /// Cached status color based on completion and reminder state
    var statusColor: Color {
        // Check overdue status first (overdue takes precedence)
        if isOverdue {
            return .orange
        } else if lastCompleted == nil {
            return .gray
        } else {
            return .green
        }
    }
    
    var timeText: String {
        guard let lastCompleted = lastCompleted else {
            if isOverdue {
                return "Never completed - Overdue"
            }
            return "Never completed"
        }
        
        let seconds = Int(Date().timeIntervalSince(lastCompleted))
        let minutes = seconds / 60
        let hours = seconds / 3600
        
        if seconds < 60 {
            return "Just now"
        } else if minutes < 60 {
            return "\(minutes)m ago"
        } else if hours < 24 {
            return "\(hours)h ago"
        } else {
            let days = hours / 24
            return "\(days)d ago"
        }
    }
}

struct TaskEntry: TimelineEntry {
    let date: Date
    let tasks: [TaskData]
}

struct LastTimeWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(tasks: entry.tasks)
        case .systemMedium:
            MediumWidgetView(tasks: entry.tasks)
        default:
            MediumWidgetView(tasks: entry.tasks)
        }
    }
}

struct SmallWidgetView: View {
    let tasks: [TaskData]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                Text("Last Time")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }
            .accessibilityAddTraits(.isHeader)
            .padding(.top, 4)
            
            if tasks.isEmpty {
                Text("No tasks yet")
                    .font(.system(size: 9, design: .rounded))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(tasks.prefix(3)) { task in
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(task.statusColor.gradient)
                                .frame(width: 5, height: 5)
                            if task.isPinned {
                                Image(systemName: "pin.fill")
                                    .font(.system(size: 7))
                                    .foregroundStyle(.orange)
                            }
                            Text(task.title)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        
                        Text(task.timeText)
                            .font(.system(size: 9, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.bottom, 1)
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(EdgeInsets(top: 2, leading: 8, bottom: 8, trailing: 8))
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

struct MediumWidgetView: View {
    let tasks: [TaskData]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                Text("Last Time")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
            }
            .accessibilityAddTraits(.isHeader)
            .padding(.top, 4)
            
            if tasks.isEmpty {
                Text("No tasks yet")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else {
                HStack(alignment: .top, spacing: 8) {
                    // Left column - first 3 tasks
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(tasks.prefix(3)) { task in
                            taskRowView(task: task)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Right column - next 3 tasks
                    if tasks.count > 3 {
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(Array(tasks.dropFirst(3).prefix(3))) { task in
                                taskRowView(task: task)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(EdgeInsets(top: 2, leading: 10, bottom: 8, trailing: 10))
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
    
    @ViewBuilder
    private func taskRowView(task: TaskData) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Circle()
                    .fill(task.statusColor.gradient)
                    .frame(width: 6, height: 6)
                if task.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.orange)
                }
                Text(task.title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            
            Text(task.timeText)
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.leading, 10)
        }
        .padding(.vertical, 1)
    }
}

struct LastTimeWidget: Widget {
    let kind: String = "LastTimeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            LastTimeWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Last Time")
        .description("See your recent tasks at a glance")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
