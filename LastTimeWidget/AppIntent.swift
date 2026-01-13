//
//  AppIntent.swift
//  LastTimeWidget
//
//  Created by Malik Jamal on 1/10/26.
//

import WidgetKit
import AppIntents
import CoreData

struct TaskEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Task"
    static var defaultQuery = TaskEntityQuery()
    
    var id: UUID
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }
    
    var title: String
}

struct TaskEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [TaskEntity] {
        let context = PersistenceController.shared.container.viewContext
        let request = LogItem.fetchRequest()
        request.predicate = NSPredicate(format: "id IN %@", identifiers)
        
        let items = try context.fetch(request)
        return items.compactMap { item in
            guard let id = item.id, let title = item.title else { return nil }
            return TaskEntity(id: id, title: title)
        }
    }
    
    func suggestedEntities() async throws -> [TaskEntity] {
        let context = PersistenceController.shared.container.viewContext
        let request = LogItem.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \LogItem.isPinned, ascending: false),
            NSSortDescriptor(keyPath: \LogItem.lastCompletedAt, ascending: false)
        ]
        request.fetchLimit = 20
        
        let items = try context.fetch(request)
        return items.compactMap { item in
            guard let id = item.id, let title = item.title else { return nil }
            return TaskEntity(id: id, title: title)
        }
    }
    
    func entities(matching string: String) async throws -> [TaskEntity] {
        let context = PersistenceController.shared.container.viewContext
        let request = LogItem.fetchRequest()
        request.predicate = NSPredicate(format: "title CONTAINS[cd] %@", string)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \LogItem.isPinned, ascending: false),
            NSSortDescriptor(keyPath: \LogItem.lastCompletedAt, ascending: false)
        ]
        
        let items = try context.fetch(request)
        return items.compactMap { item in
            guard let id = item.id, let title = item.title else { return nil }
            return TaskEntity(id: id, title: title)
        }
    }
}

struct LogTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Task"
    static var description = IntentDescription("Mark a task as completed")
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Task", requestValueDialog: "Which task do you want to log?")
    var task: TaskEntity
    
    static var parameterSummary: some ParameterSummary {
        Summary("Log \\(\\.$task)")
    }
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = PersistenceController.shared.container.viewContext
        let request = LogItem.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", task.id as CVarArg)
        
        do {
            let items = try context.fetch(request)
            
            guard let logItem = items.first else {
                return .result(dialog: "I couldn't find that task")
            }
            
            logItem.lastCompletedAt = Date()
            
            if let repeatInterval = logItem.reminderRepeatInterval, repeatInterval == "None" || repeatInterval.isEmpty {
                logItem.reminderDate = nil
                logItem.reminderRepeatInterval = nil
            }
            
            try context.save()
            
            WidgetCenter.shared.reloadAllTimelines()
            
            NotificationCenter.default.post(name: NSNotification.Name("DataDidChange"), object: nil)
            
            return .result(dialog: "Logged '\(logItem.title ?? "task")'")
        } catch {
            return .result(dialog: "Sorry, I couldn't log that task")
        }
    }
}

struct AddTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Task"
    static var description = IntentDescription("Add a new task to track")
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Task Name", requestValueDialog: "What's the name of the task?")
    var taskName: String
    
    static var parameterSummary: some ParameterSummary {
        Summary("Add task \\(\\.$taskName)")
    }
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = PersistenceController.shared.container.viewContext
        
        let logItem = LogItem(context: context)
        logItem.id = UUID()
        logItem.title = taskName
        logItem.createdAt = Date()
        
        let request = LogItem.fetchRequest()
        let allItems = try? context.fetch(request)
        let minSortOrder = allItems?.map { $0.sortOrder }.min() ?? 0
        logItem.sortOrder = minSortOrder - 1
        
        do {
            try context.save()
            
            WidgetCenter.shared.reloadAllTimelines()
            
            NotificationCenter.default.post(name: NSNotification.Name("DataDidChange"), object: nil)
            
            return .result(dialog: "Added '\(taskName)' to your tasks")
        } catch {
            return .result(dialog: "Sorry, I couldn't add that task")
        }
    }
}

struct CheckTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Task"
    static var description = IntentDescription("Check when you last completed a task")
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Task", requestValueDialog: "Which task do you want to check?")
    var task: TaskEntity
    
    static var parameterSummary: some ParameterSummary {
        Summary("When did I last \\(\\.$task)?")
    }
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = PersistenceController.shared.container.viewContext
        let request = LogItem.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", task.id as CVarArg)
        
        do {
            let items = try context.fetch(request)
            
            guard let logItem = items.first else {
                return .result(dialog: "I couldn't find that task")
            }
            
            guard let lastCompleted = logItem.lastCompletedAt else {
                return .result(dialog: "You haven't completed '\(logItem.title ?? "this task")' yet")
            }
            
            let timeAgo = formatTimeAgo(from: lastCompleted)
            return .result(dialog: "You last completed '\(logItem.title ?? "this task")' \(timeAgo)")
        } catch {
            return .result(dialog: "Sorry, I couldn't check that task")
        }
    }
    
    private func formatTimeAgo(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        let minutes = seconds / 60
        let hours = seconds / 3600
        let days = hours / 24
        
        if seconds < 60 {
            return "just now"
        } else if minutes < 60 {
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else if hours < 24 {
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else {
            return "\(days) day\(days == 1 ? "" : "s") ago"
        }
    }
}

struct LastTimeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogTaskIntent(),
            phrases: [
                "Log \(.applicationName)"
            ],
            shortTitle: "Log Task",
            systemImageName: "checkmark.circle.fill"
        )
        
        AppShortcut(
            intent: AddTaskIntent(),
            phrases: [
                "Add new task \(.applicationName)"
            ],
            shortTitle: "Add Task",
            systemImageName: "plus.circle.fill"
        )
        
        AppShortcut(
            intent: CheckTaskIntent(),
            phrases: [
                "Check task \(.applicationName)"
            ],
            shortTitle: "Check Task",
            systemImageName: "clock.fill"
        )
    }
}
