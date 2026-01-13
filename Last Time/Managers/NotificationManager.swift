import Foundation
import UserNotifications
import CoreData

class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {}
    
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            completion(granted)
        }
    }
    
    func scheduleNotification(for logItem: LogItem) {
        guard let reminderDate = logItem.reminderDate,
              let itemId = logItem.id else {
            return
        }
        
        cancelNotification(for: logItem)
        
        guard reminderDate > Date() else {
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Last Time Reminder"
        content.body = logItem.title ?? "Task reminder"
        content.sound = .default
        
        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: itemId.uuidString,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error.localizedDescription)")
            }
        }
    }
    
    func cancelNotification(for logItem: LogItem) {
        guard let itemId = logItem.id else { return }
        
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [itemId.uuidString]
        )
    }
    
    func rescheduleIfNeeded(for logItem: LogItem) {
        guard let repeatIntervalString = logItem.reminderRepeatInterval,
              let repeatInterval = RepeatInterval(rawValue: repeatIntervalString),
              repeatInterval != .none,
              let currentReminderDate = logItem.reminderDate,
              let nextDate = repeatInterval.nextDate(from: currentReminderDate) else {
            return
        }
        
        let context = PersistenceController.shared.container.viewContext
        context.perform {
            logItem.reminderDate = nextDate
            PersistenceController.shared.save()
            
            self.scheduleNotification(for: logItem)
        }
    }
}
