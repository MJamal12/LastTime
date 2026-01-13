import SwiftUI
import PhotosUI
import CoreData

struct AddLogView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \LogItem.sortOrder, ascending: true)],
        animation: .default)
    private var logItems: FetchedResults<LogItem>
    
    private static let maxTitleLength = 100
    private static let photoCompressionQuality = 0.7
    private static let maxPhotoSizeBytes = 5_000_000 // 5MB limit
    
    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var enableReminder: Bool = false
    @State private var reminderDate: Date = Date()
    @State private var repeatInterval: RepeatInterval = .none
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var photoData: Data? = nil
    
    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        title.trimmingCharacters(in: .whitespacesAndNewlines).count <= Self.maxTitleLength
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title, prompt: Text("e.g., Locked door"))
                        .textInputAutocapitalization(.sentences)
                    
                    if !title.isEmpty {
                        Text("\(title.count)/\(Self.maxTitleLength)")
                            .font(.caption)
                            .foregroundStyle(title.count > Self.maxTitleLength ? .red : .secondary)
                    }
                    
                    TextField("Notes (Optional)", text: $notes, prompt: Text("Add details..."), axis: .vertical)
                        .lineLimit(3...6)
                        .textInputAutocapitalization(.sentences)
                }
                
                Section {
                    Toggle("Remind me", isOn: $enableReminder)
                    
                    if enableReminder {
                        DatePicker(
                            "Date",
                            selection: $reminderDate,
                            displayedComponents: [.date]
                        )
                        
                        DatePicker(
                            "Time",
                            selection: $reminderDate,
                            displayedComponents: [.hourAndMinute]
                        )
                        
                        Picker("Repeat", selection: $repeatInterval) {
                            ForEach(RepeatInterval.allCases) { interval in
                                Text(interval.rawValue).tag(interval)
                            }
                        }
                    }
                } header: {
                    Text("Reminder")
                }
                
                Section {
                    if let photoData = photoData,
                       let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity, maxHeight: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        Button("Remove", role: .destructive) {
                            self.photoData = nil
                            self.selectedPhoto = nil
                        }
                    } else {
                        PhotosPicker(
                            selection: $selectedPhoto,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            Label("Add Photo", systemImage: "photo")
                        }
                        .accessibilityLabel("Add photo")
                        .accessibilityHint("Double tap to select a photo from your library")
                        .onChange(of: selectedPhoto) { _, newValue in
                            Task {
                                if let data = try? await newValue?.loadTransferable(type: Data.self),
                                   let image = UIImage(data: data) {
                                    if let compressed = image.jpegData(compressionQuality: Self.photoCompressionQuality) {
                                        if compressed.count <= Self.maxPhotoSizeBytes {
                                            photoData = compressed
                                        } else {
                                            print("Photo too large, skipping")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addLogItem()
                    }
                    .disabled(!isValid)
                    .bold()
                    .foregroundStyle(isValid ? .blue : .gray)
                    .accessibilityLabel("Add new task")
                    .accessibilityHint(isValid ? "Double tap to create this task" : "Enter a title to enable")
                }
            }
        }
    }
    
    private func addLogItem() {
        guard isValid else { return }
        
        withAnimation {
            let newItem = LogItem(context: viewContext)
            newItem.id = UUID()
            newItem.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            newItem.createdAt = Date()
            newItem.lastCompletedAt = nil
            newItem.isPinned = false
            
            let minSortOrder = logItems.map { $0.sortOrder }.min() ?? 0
            newItem.sortOrder = minSortOrder - 1
            
            if !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                newItem.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            if enableReminder {
                newItem.reminderDate = reminderDate
                newItem.reminderRepeatInterval = repeatInterval.rawValue
                
                NotificationManager.shared.requestAuthorization { granted in
                    if granted {
                        NotificationManager.shared.scheduleNotification(for: newItem)
                    }
                }
            }
            
            if let photoData = photoData {
                newItem.optionalProofPhoto = photoData
            }
            
            PersistenceController.shared.save()
            dismiss()
        }
    }
}


