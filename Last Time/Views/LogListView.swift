import SwiftUI
import CoreData

struct LogListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.scenePhase) private var scenePhase
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \LogItem.lastCompletedAt, ascending: false)],
        animation: .default)
    private var logItems: FetchedResults<LogItem>
    
    @State private var showingAddView = false
    @State private var editingLogItem: LogItem? = nil
    @State private var listRefreshTrigger = 0
    @State private var isSelecting = false
    @State private var isPinning = false
    @State private var isReordering = false
    @State private var selectedItems = Set<NSManagedObjectID>()
    @State private var completedTasksSortMethod: CompletedSortMethod = .mostRecent
    @State private var undoData: [NSManagedObjectID: UndoInfo] = [:]
    @State private var showUndoHintFor: NSManagedObjectID? = nil
    
    struct UndoInfo {
        let previousCompletedAt: Date?
        let previousReminderDate: Date?
        let previousRepeatInterval: String?
    }
    
    enum CompletedSortMethod: String, CaseIterable {
        case mostRecent = "Most Recent"
        case leastRecent = "Least Recent"
        case alphabetical = "A-Z"
        case reverseAlphabetical = "Z-A"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(.systemBackground),
                        Color(.systemBackground).opacity(0.8)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                if logItems.isEmpty {
                    emptyStateView
                } else {
                    listView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if isSelecting || isPinning || isReordering {
                        Button("Cancel") {
                            isSelecting = false
                            isPinning = false
                            isReordering = false
                            selectedItems.removeAll()
                        }
                        .foregroundStyle(.secondary)
                    } else {
                        Menu {
                            Button {
                                isSelecting = true
                            } label: {
                                Label("Select Tasks", systemImage: "checkmark.circle")
                            }
                            
                            Button {
                                isPinning = true
                            } label: {
                                Label("Pin Tasks", systemImage: "pin.fill")
                            }
                            
                            Button {
                                isReordering = true
                            } label: {
                                Label("Reorder Tasks", systemImage: "arrow.up.arrow.down")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                                .foregroundStyle(.blue.gradient)
                        }
                        .accessibilityLabel("More options")
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image("AppLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 28, height: 28)
                        Text("Last Time")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSelecting {
                        Button("Delete") {
                            deleteSelectedItems()
                        }
                        .disabled(selectedItems.isEmpty)
                        .foregroundStyle(selectedItems.isEmpty ? .gray : .red)
                    } else if isPinning {
                        Button(isPinningAny ? "Unpin" : "Pin") {
                            togglePinSelectedItems()
                        }
                        .disabled(selectedItems.isEmpty)
                        .foregroundStyle(selectedItems.isEmpty ? .gray : .orange)
                    } else if isReordering {
                        Button("Done") {
                            isReordering = false
                        }
                        .bold()
                        .foregroundStyle(.blue)
                    } else {
                        Button(action: { showingAddView = true }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.blue.gradient)
                                .accessibilityLabel("Add new log item")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddView) {
                AddLogView()
            }
            .sheet(item: $editingLogItem) { logItem in
                EditLogView(logItem: logItem)
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .active {
                    listRefreshTrigger += 1
                }
            }
        }
    }
    
    private var listView: some View {
        List {
            ForEach(Array(groupedTasks.keys.sorted()), id: \.self) { category in
                if let tasks = groupedTasks[category], !tasks.isEmpty {
                    taskSection(for: category, tasks: tasks)
                }
            }
        }
        .id(listRefreshTrigger)
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, .constant(isReordering ? .active : .inactive))
    }
    
    private func taskSection(for category: Int, tasks: [LogItem]) -> some View {
        Section {
            ForEach(tasks) { logItem in
                taskRow(for: logItem)
            }
            .onMove { source, destination in
                if isReordering && category != 3 {
                    moveSectionItems(from: source, to: destination, in: category)
                }
            }
            .onDelete { indexSet in
                if !isReordering {
                    deleteSectionItems(offsets: indexSet, in: category)
                }
            }
            .moveDisabled(category == 3)
        } header: {
            sectionHeader(for: category)
        }
    }
    
    private func taskRow(for logItem: LogItem) -> some View {
        HStack(spacing: 12) {
            if isSelecting || isPinning {
                selectionIndicator(for: logItem)
            }
            
            HStack(spacing: 8) {
                if logItem.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                
                LogRowView(logItem: logItem, onTap: {
                    if isSelecting || isPinning {
                        toggleSelection(for: logItem)
                    } else if !isReordering {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            logAction(logItem)
                        }
                    }
                }, onLongPress: {
                    if !isSelecting && !isPinning && !isReordering {
                        undoLastCompletion(for: logItem)
                    }
                })
            }
        }
        .overlay(
            Group {
                if showUndoHintFor == logItem.objectID {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.uturn.backward.circle.fill")
                            .font(.caption)
                        Text("Hold to undo")
                            .font(.system(.caption, design: .rounded, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.accentColor)
                    )
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    .transition(.scale.combined(with: .opacity))
                }
            }
        )
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if !isSelecting && !isPinning && !isReordering {
                Button {
                    editingLogItem = logItem
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(.blue)
            }
        }
    }
    
    private func selectionIndicator(for logItem: LogItem) -> some View {
        Image(systemName: selectedItems.contains(logItem.objectID) ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(selectedItems.contains(logItem.objectID) ? .blue : .gray)
            .font(.title3)
            .onTapGesture {
                toggleSelection(for: logItem)
            }
    }
    
    private func sectionHeader(for category: Int) -> some View {
        HStack {
            Text(categoryTitle(for: category))
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(nil)
            
            if category == 3 && isReordering {
                sortMenu
            }
        }
    }
    
    private var sortMenu: some View {
        Menu {
            Picker("Sort By", selection: $completedTasksSortMethod) {
                ForEach(CompletedSortMethod.allCases, id: \.self) { method in
                    Text(method.rawValue).tag(method)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text("Sort")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 10))
            }
            .foregroundStyle(.blue)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(.blue.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "clock.badge.checkmark")
                    .font(.system(size: 40))
                    .foregroundStyle(.blue.gradient)
            }
            
            VStack(spacing: 8) {
                Text("No Tasks Yet")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                
                Text("Tap + to start tracking")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var sortedLogItems: [LogItem] {
        logItems.sorted { item1, item2 in
            if item1.isPinned && !item2.isPinned { return true }
            if item2.isPinned && !item1.isPinned { return false }
            
            let overdue1 = !item1.isPinned && item1.isOverdue
            let overdue2 = !item2.isPinned && item2.isOverdue
            
            if overdue1 && !overdue2 { return true }
            if overdue2 && !overdue1 { return false }
            
            let neverCompleted1 = !item1.isPinned && !item1.isOverdue && item1.lastCompletedAt == nil
            let neverCompleted2 = !item2.isPinned && !item2.isOverdue && item2.lastCompletedAt == nil
            
            if neverCompleted1 && !neverCompleted2 { return true }
            if neverCompleted2 && !neverCompleted1 { return false }
            
            let completed1 = !item1.isPinned && !item1.isOverdue && item1.lastCompletedAt != nil
            let completed2 = !item2.isPinned && !item2.isOverdue && item2.lastCompletedAt != nil
            
            if (item1.isPinned && item2.isPinned) || 
               (overdue1 && overdue2) || 
               (neverCompleted1 && neverCompleted2) {
                return item1.sortOrder < item2.sortOrder
            } else if completed1 && completed2 {
                return sortCompletedTasks(item1, item2)
            }
            
            return false
        }
    }
    
    private func sortCompletedTasks(_ item1: LogItem, _ item2: LogItem) -> Bool {
        switch completedTasksSortMethod {
        case .mostRecent:
            guard let date1 = item1.lastCompletedAt, let date2 = item2.lastCompletedAt else {
                return false
            }
            return date1 > date2
        case .leastRecent:
            guard let date1 = item1.lastCompletedAt, let date2 = item2.lastCompletedAt else {
                return false
            }
            return date1 < date2
        case .alphabetical:
            return (item1.title ?? "") < (item2.title ?? "")
        case .reverseAlphabetical:
            return (item1.title ?? "") > (item2.title ?? "")
        }
    }
    
    private var groupedTasks: [Int: [LogItem]] {
        var groups: [Int: [LogItem]] = [:]
        for item in sortedLogItems {
            let category = getCategory(for: item)
            if groups[category] == nil {
                groups[category] = []
            }
            groups[category]?.append(item)
        }
        return groups
    }
    
    private func categoryTitle(for category: Int) -> String {
        switch category {
        case 0: return "Pinned Tasks"
        case 1: return "Overdue Tasks"
        case 2: return "Uncompleted Tasks"
        case 3: return "Completed Tasks"
        default: return ""
        }
    }
    
    private var isPinningAny: Bool {
        selectedItems.contains { objectID in
            if let logItem = try? viewContext.existingObject(with: objectID) as? LogItem {
                return logItem.isPinned
            }
            return false
        }
    }
    
    private func toggleSelection(for logItem: LogItem) {
        if selectedItems.contains(logItem.objectID) {
            selectedItems.remove(logItem.objectID)
        } else {
            selectedItems.insert(logItem.objectID)
        }
    }
    
    private func deleteSelectedItems() {
        withAnimation {
            selectedItems.forEach { objectID in
                if let logItem = try? viewContext.existingObject(with: objectID) as? LogItem {
                    NotificationManager.shared.cancelNotification(for: logItem)
                    viewContext.delete(logItem)
                }
            }
            
            PersistenceController.shared.save()
            selectedItems.removeAll()
            isSelecting = false
        }
    }
    
    private func togglePinSelectedItems() {
        withAnimation {
            let shouldPin = !isPinningAny
            
            selectedItems.forEach { objectID in
                if let logItem = try? viewContext.existingObject(with: objectID) as? LogItem {
                    logItem.isPinned = shouldPin
                }
            }
            
            PersistenceController.shared.save()
            selectedItems.removeAll()
            isPinning = false
        }
    }
    
    private func moveSectionItems(from source: IndexSet, to destination: Int, in category: Int) {
        guard let tasks = groupedTasks[category] else { return }
        
        var items = sortedLogItems
        
        guard let sourceIndex = source.first,
              sourceIndex < tasks.count else { return }
        
        let movingItem = tasks[sourceIndex]
        
        guard let fullListSourceIndex = items.firstIndex(where: { $0.objectID == movingItem.objectID }) else { return }
        
        let categoryStartIndex = items.firstIndex(where: { getCategory(for: $0) == category }) ?? 0
        let fullListDestination = categoryStartIndex + destination
        
        items.move(fromOffsets: IndexSet(integer: fullListSourceIndex), toOffset: fullListDestination)
        
        for (index, item) in items.enumerated() {
            item.sortOrder = Int32(index)
        }
        
        PersistenceController.shared.save()
    }
    
    private func deleteSectionItems(offsets: IndexSet, in category: Int) {
        guard let tasks = groupedTasks[category] else { return }
        
        withAnimation {
            offsets.map { tasks[$0] }.forEach { logItem in
                NotificationManager.shared.cancelNotification(for: logItem)
                viewContext.delete(logItem)
            }
            
            PersistenceController.shared.save()
        }
    }
    
    private func moveItems(from source: IndexSet, to destination: Int) {
        var items = sortedLogItems
        
        guard let sourceIndex = source.first,
              sourceIndex < items.count else { return }
        
        let movingItem = items[sourceIndex]
        
        let movingItemCategory = getCategory(for: movingItem)
        
        let categoryItems = items.enumerated().filter { getCategory(for: $0.element) == movingItemCategory }
        guard !categoryItems.isEmpty else { return }
        
        let categoryStartIndex = categoryItems.first!.offset
        let categoryEndIndex = categoryItems.last!.offset
        
        let constrainedDestination = min(max(destination, categoryStartIndex), categoryEndIndex + 1)
        
        items.move(fromOffsets: source, toOffset: constrainedDestination)
        
        for (index, item) in items.enumerated() {
            item.sortOrder = Int32(index)
        }
        
        PersistenceController.shared.save()
    }
    
    private func getCategory(for item: LogItem) -> Int {
        if item.isPinned { return 0 }
        if item.isOverdue { return 1 }
        if item.lastCompletedAt == nil { return 2 }
        return 3 // completed
    }
    
    private func logAction(_ logItem: LogItem) {
        guard viewContext.hasChanges == false || !viewContext.hasChanges else {
            // Wait for pending changes
            return
        }
        
        withAnimation {
            undoData[logItem.objectID] = UndoInfo(
                previousCompletedAt: logItem.lastCompletedAt,
                previousReminderDate: logItem.reminderDate,
                previousRepeatInterval: logItem.reminderRepeatInterval
            )
            
            logItem.lastCompletedAt = Date()
            
            if let repeatIntervalString = logItem.reminderRepeatInterval,
               let repeatInterval = RepeatInterval(rawValue: repeatIntervalString),
               repeatInterval != .none {
                NotificationManager.shared.rescheduleIfNeeded(for: logItem)
            } else if logItem.reminderDate != nil {
                logItem.reminderDate = nil
                logItem.reminderRepeatInterval = nil
                NotificationManager.shared.cancelNotification(for: logItem)
            }
            
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            PersistenceController.shared.save()
            
            showUndoHintFor = logItem.objectID
            
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                withAnimation {
                    if showUndoHintFor == logItem.objectID {
                        showUndoHintFor = nil
                    }
                }
            }
        }
    }
    
    private func undoLastCompletion(for logItem: LogItem) {
        guard let undo = undoData[logItem.objectID] else { return }
        
        showUndoHintFor = nil
        
        withAnimation {
            logItem.lastCompletedAt = undo.previousCompletedAt
            logItem.reminderDate = undo.previousReminderDate
            logItem.reminderRepeatInterval = undo.previousRepeatInterval
            
            if undo.previousReminderDate != nil {
                NotificationManager.shared.scheduleNotification(for: logItem)
            } else {
                NotificationManager.shared.cancelNotification(for: logItem)
            }
            
            undoData.removeValue(forKey: logItem.objectID)
            
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            
            PersistenceController.shared.save()
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { sortedLogItems[$0] }.forEach { logItem in
                NotificationManager.shared.cancelNotification(for: logItem)
                viewContext.delete(logItem)
            }
            
            PersistenceController.shared.save()
        }
    }
}

extension LogItem {
    var isOverdue: Bool {
        guard let reminderDate = reminderDate else {
            return false
        }
        
        return Date() > reminderDate
    }
}
