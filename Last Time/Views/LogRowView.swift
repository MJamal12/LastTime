import SwiftUI
import CoreData
import Combine

struct LogRowView: View {
    let logItem: LogItem
    let onTap: () -> Void
    var onLongPress: (() -> Void)? = nil
    
    @State private var currentTime = Date()
    @State private var timer: AnyCancellable?
    @State private var isPressing = false
    
    var body: some View {
        ZStack {
            HStack(spacing: 16) {
                // Status indicator
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                    .shadow(color: statusColor.opacity(0.4), radius: 3, x: 0, y: 1)
                
                // Title and time info
                VStack(alignment: .leading, spacing: 6) {
                    Text(logItem.title ?? "Untitled")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    if let reminderDate = logItem.reminderDate {
                        HStack(spacing: 6) {
                            Image(systemName: isOverdue ? "bell.badge.fill" : "bell.fill")
                                .font(.caption2)
                            Text("Due: \(TimeFormatter.completionDateString(from: reminderDate))")
                                .font(.system(.caption, design: .rounded, weight: .medium))
                        }
                        .foregroundStyle(isOverdue ? .orange : .blue)
                    }
                    
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(lastCompletedText)
                            .font(.system(.subheadline, design: .rounded))
                    }
                    .foregroundStyle(isOverdue ? .orange : .secondary)
                    
                    if let lastCompleted = logItem.lastCompletedAt {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                            Text(TimeFormatter.completionDateString(from: lastCompleted))
                                .font(.system(.caption, design: .rounded))
                        }
                        .foregroundStyle(.secondary)
                    }
                    
                    if let notes = logItem.notes, !notes.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "pencil")
                                .font(.caption2)
                            Text(notes)
                                .font(.system(.caption, design: .rounded))
                                .lineLimit(1)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // Optional photo thumbnail
                if let photoData = logItem.optionalProofPhoto,
                   let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .shadow(color: Color.primary.opacity(0.08), radius: 8, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        isOverdue ? Color.orange.opacity(0.3) : Color.primary.opacity(0.06),
                        lineWidth: isOverdue ? 2 : 1
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .scaleEffect(isPressing ? 1.05 : 1.0)
        .brightness(isPressing ? 0.05 : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressing)
        .onAppear {
            timer = Timer.publish(every: 1, on: .main, in: .common)
                .autoconnect()
                .sink { _ in
                    currentTime = Date()
                }
        }
        .onDisappear {
            timer?.cancel()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture(minimumDuration: 0.5, pressing: { pressing in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressing = pressing
            }
        }, perform: {
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
            onLongPress?()
        })
        .accessibilityLabel("\(logItem.title ?? "Untitled"), last completed \(lastCompletedText)")
        .accessibilityHint("Tap to log now, long press to undo last completion")
    }
    
    private var statusColor: Color {
        _ = currentTime
        
        if isOverdue {
            return .orange
        } else if logItem.lastCompletedAt == nil {
            return .gray
        } else {
            return .green
        }
    }
    
    private var lastCompletedText: String {
        guard let lastCompleted = logItem.lastCompletedAt else {
            if isOverdue {
                return "Never completed - Overdue"
            }
            return "Never completed"
        }
        
        _ = currentTime
        return TimeFormatter.relativeTimeString(from: lastCompleted)
    }
    
    private var isOverdue: Bool {
        _ = currentTime
        
        guard let reminderDate = logItem.reminderDate else {
            return false
        }
        
        return Date() > reminderDate
    }
}


