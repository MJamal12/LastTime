import SwiftUI
import PhotosUI

struct EditLogView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject var logItem: LogItem
    
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
                            Label(photoData == nil && logItem.optionalProofPhoto == nil ? "Add Photo" : "Change Photo", systemImage: "photo")
                        }
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
            .navigationTitle("Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(!isValid)
                    .bold()
                    .foregroundStyle(isValid ? .blue : .gray)
                    .accessibilityLabel("Save changes")
                    .accessibilityHint(isValid ? "Double tap to save your changes" : "Enter a title to enable")
                }
            }
            .onAppear {
                loadCurrentValues()
            }
        }
    }
    
    private func loadCurrentValues() {
        title = logItem.title ?? ""
        notes = logItem.notes ?? ""
        
        if let reminderDate = logItem.reminderDate {
            enableReminder = true
            self.reminderDate = reminderDate
            
            if let intervalString = logItem.reminderRepeatInterval,
               let interval = RepeatInterval(rawValue: intervalString) {
                repeatInterval = interval
            }
        }
        
        if let existingPhoto = logItem.optionalProofPhoto {
            photoData = existingPhoto
        }
    }
    
    private func saveChanges() {
        guard isValid else { return }
        
        withAnimation {
            logItem.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                logItem.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                logItem.notes = nil
            }
            
            if enableReminder {
                logItem.reminderDate = reminderDate
                logItem.reminderRepeatInterval = repeatInterval.rawValue
                
                NotificationManager.shared.requestAuthorization { granted in
                    if granted {
                        NotificationManager.shared.scheduleNotification(for: logItem)
                    }
                }
            } else {
                logItem.reminderDate = nil
                logItem.reminderRepeatInterval = nil
                NotificationManager.shared.cancelNotification(for: logItem)
            }
            
            if let photoData = photoData {
                logItem.optionalProofPhoto = photoData
            } else if self.selectedPhoto == nil && photoData == nil {
                logItem.optionalProofPhoto = nil
            }
            
            PersistenceController.shared.save()
            dismiss()
        }
    }
}
