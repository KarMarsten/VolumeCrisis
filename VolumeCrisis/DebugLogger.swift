import Foundation
import SwiftUI

class DebugLogger: ObservableObject {
    static let shared = DebugLogger()
    
    @Published var isEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "debugLoggerEnabled")
        }
    }
    
    @Published var logs: [DebugLogEntry] = []
    private let maxLogs = 500 // Keep last 500 logs
    
    private init() {
        isEnabled = UserDefaults.standard.bool(forKey: "debugLoggerEnabled")
        if UserDefaults.standard.object(forKey: "debugLoggerEnabled") == nil {
            isEnabled = true // Default to enabled
        }
    }
    
    func log(_ message: String, level: LogLevel = .info, category: LogCategory = .general) {
        let entry = DebugLogEntry(
            timestamp: Date(),
            message: message,
            level: level,
            category: category
        )
        
        DispatchQueue.main.async {
            self.logs.append(entry)
            if self.logs.count > self.maxLogs {
                self.logs.removeFirst()
            }
        }
        
        // Also print to console if enabled
        if isEnabled {
            let emoji = level.emoji
            let categoryPrefix = category.rawValue.uppercased()
            print("\(emoji) [\(categoryPrefix)] \(message)")
        }
    }
    
    func clear() {
        DispatchQueue.main.async {
            self.logs.removeAll()
        }
    }
    
    func getRecentLogs(count: Int = 50) -> [DebugLogEntry] {
        return Array(logs.suffix(count))
    }
}

struct DebugLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String
    let level: LogLevel
    let category: LogCategory
}

enum LogLevel {
    case debug
    case info
    case warning
    case error
    case success
    
    var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .success: return "✅"
        }
    }
    
    var color: Color {
        switch self {
        case .debug: return .gray
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .success: return .green
        }
    }
    
    var name: String {
        switch self {
        case .debug: return "Debug"
        case .info: return "Info"
        case .warning: return "Warning"
        case .error: return "Error"
        case .success: return "Success"
        }
    }
}

enum LogCategory: String {
    case general = "General"
    case volume = "Volume"
    case audio = "Audio"
    case ui = "UI"
    case background = "Background"
    case enforcement = "Enforcement"
    case slider = "Slider"
}

// Convenience functions for easier logging
func debugLog(_ message: String, level: LogLevel = .info, category: LogCategory = .general) {
    DebugLogger.shared.log(message, level: level, category: category)
}

