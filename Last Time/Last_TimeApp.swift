import SwiftUI
import UserNotifications
import CoreData

@main
struct Last_TimeApp: App {
    let persistenceController = PersistenceController.shared
    
    init() {
        requestNotificationPermissions()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
}
