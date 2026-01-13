import Foundation

enum RepeatInterval: String, CaseIterable, Identifiable {
    case none = "None"
    case hourly = "Hourly"
    case daily = "Daily"
    case weekdays = "Weekdays"
    case weekends = "Weekends"
    case weekly = "Weekly"
    case biweekly = "Biweekly"
    case monthly = "Monthly"
    case every3Months = "Every 3 Months"
    case every6Months = "Every 6 Months"
    case yearly = "Yearly"
    
    var id: String { rawValue }
    
    func nextDate(from date: Date) -> Date? {
        let calendar = Calendar.current
        
        switch self {
        case .none:
            return nil
            
        case .hourly:
            return calendar.date(byAdding: .hour, value: 1, to: date)
            
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: date)
            
        case .weekdays:
            guard var nextDate = calendar.date(byAdding: .day, value: 1, to: date) else {
                return nil
            }
            while calendar.component(.weekday, from: nextDate) == 1 ||
                  calendar.component(.weekday, from: nextDate) == 7 {
                guard let advanced = calendar.date(byAdding: .day, value: 1, to: nextDate) else {
                    return nil
                }
                nextDate = advanced
            }
            return nextDate
            
        case .weekends:
            guard var nextDate = calendar.date(byAdding: .day, value: 1, to: date) else {
                return nil
            }
            while calendar.component(.weekday, from: nextDate) != 1 &&
                  calendar.component(.weekday, from: nextDate) != 7 {
                guard let advanced = calendar.date(byAdding: .day, value: 1, to: nextDate) else {
                    return nil
                }
                nextDate = advanced
            }
            return nextDate
            
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: date)
            
        case .biweekly:
            return calendar.date(byAdding: .weekOfYear, value: 2, to: date)
            
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date)
            
        case .every3Months:
            return calendar.date(byAdding: .month, value: 3, to: date)
            
        case .every6Months:
            return calendar.date(byAdding: .month, value: 6, to: date)
            
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: date)
        }
    }
}
