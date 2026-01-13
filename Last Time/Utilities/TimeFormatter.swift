import Foundation

struct TimeFormatter {
    private static let secondsInMinute = 60
    private static let secondsInHour = 3600
    private static let secondsInDay = 86400
    private static let daysInWeek = 7
    private static let daysInMonth = 30
    private static let monthsInYear = 12
    
    static func relativeTimeString(from date: Date) -> String {
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date, to: now)
        
        let totalSeconds = Int(now.timeIntervalSince(date))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if totalSeconds <= 5 {
            return "Just now"
        }
        
        if totalSeconds < 60 {
            return "\(seconds) seconds ago"
        }
        
        if totalSeconds < 3600 {
            return minutes == 1 ? "1 minute ago" : "\(minutes) minutes ago"
        }
        
        if hours < 24 && calendar.isDateInToday(date) {
            if minutes == 0 {
                return hours == 1 ? "1 hour ago" : "\(hours) hours ago"
            } else if hours == 1 {
                return minutes == 1 ? "1 hour and 1 minute ago" : "1 hour and \(minutes) minutes ago"
            } else {
                return minutes == 1 ? "\(hours) hours and 1 minute ago" : "\(hours) hours and \(minutes) minutes ago"
            }
        }
        
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "Today at \(formatter.string(from: date))"
        }
        
        if calendar.isDateInYesterday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "Yesterday at \(formatter.string(from: date))"
        }
        
        if let days = components.day, days < 7 {
            return days == 1 ? "1 day ago" : "\(days) days ago"
        }
        
        if let days = components.day, days < 30 {
            let weeks = days / 7
            return weeks == 1 ? "1 week ago" : "\(weeks) weeks ago"
        }
        
        if let months = components.month, months < 12 {
            return months == 1 ? "1 month ago" : "\(months) months ago"
        }
        
        if let years = components.year, years > 0 {
            return years == 1 ? "1 year ago" : "\(years) years ago"
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    static func completionDateString(from date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        
        if calendar.isDateInToday(date) {
            formatter.timeStyle = .short
            return "Today at \(formatter.string(from: date))"
        }
        
        if calendar.isDateInYesterday(date) {
            formatter.timeStyle = .short
            return "Yesterday at \(formatter.string(from: date))"
        }
        
        if let daysAgo = calendar.dateComponents([.day], from: date, to: Date()).day, daysAgo < 7 {
            formatter.dateFormat = "EEE 'at' h:mm a"
            return formatter.string(from: date)
        }
        
        if calendar.component(.year, from: date) == calendar.component(.year, from: Date()) {
            formatter.dateFormat = "MMM d 'at' h:mm a"
            return formatter.string(from: date)
        }
        
        formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return formatter.string(from: date)
    }
}
