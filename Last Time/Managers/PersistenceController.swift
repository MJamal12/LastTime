import CoreData
import Foundation
import WidgetKit

class PersistenceController {
    static let shared = PersistenceController()
    private var storeObserver: NSObjectProtocol?
    
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let viewContext = controller.container.viewContext
        
        let sampleTitles = [
            "Locked door",
            "Took meds",
            "Changed bedsheets",
            "Watered plants",
            "Cleaned bathroom"
        ]
        
        for (index, title) in sampleTitles.enumerated() {
            let logItem = LogItem(context: viewContext)
            logItem.id = UUID()
            logItem.title = title
            logItem.createdAt = Date()
            logItem.lastCompletedAt = Date().addingTimeInterval(-Double(index + 1) * 3600)
            logItem.isPinned = false
            logItem.sortOrder = -1
        }
        
        do {
            try viewContext.save()
        } catch {
            fatalError("Failed to create preview data")
        }
        
        return controller
    }()
    
    let container: NSPersistentCloudKitContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "Last_Time")
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else {
            if let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.malik.Last-Time") {
                let storeURL = appGroupURL.appendingPathComponent("Last_Time.sqlite")
                let description = NSPersistentStoreDescription(url: storeURL)
                description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
                description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
                container.persistentStoreDescriptions = [description]
            }
        }
        
        container.loadPersistentStores { _, error in
            if let error = error {
                print("Core Data store failed to load: \(error.localizedDescription)")
                #if DEBUG
                fatalError("Core Data store failed to load: \(error.localizedDescription)")
                #endif
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        if !inMemory {
            migrateExistingData()
        }
        
        let viewContext = container.viewContext
        let coordinator = container.persistentStoreCoordinator
        storeObserver = NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: coordinator,
            queue: .main
        ) { _ in
            Task { @MainActor in
                viewContext.perform {
                    try? viewContext.setQueryGenerationFrom(.current)
                    viewContext.refreshAllObjects()
                }
            }
        }
    }
    
    deinit {
        if let observer = storeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    func save() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
                WidgetCenter.shared.reloadAllTimelines()
            } catch let error as NSError {
                context.rollback()
                
                // Check for specific error cases
                if error.code == NSPersistentStoreSaveConflictsError {
                    print("Save conflict detected, rolling back")
                } else if error.domain == NSCocoaErrorDomain && error.code == NSFileWriteOutOfSpaceError {
                    print("Out of storage space")
                } else {
                    print("Failed to save context: \\(error.localizedDescription)")
                }
                
                #if DEBUG
                fatalError("Core Data save error: \(error)")
                #endif
            }
        }
    }
    
    private func migrateExistingData() {
        let context = container.viewContext
        let request = LogItem.fetchRequest()
        
        do {
            let items = try context.fetch(request)
            var needsSave = false
            
            for item in items {
                if item.sortOrder == 0 {
                    item.sortOrder = -1
                    needsSave = true
                }
            }
            
            if needsSave {
                try context.save()
            }
        } catch {
            print("Migration warning: \(error.localizedDescription)")
        }
    }
}
