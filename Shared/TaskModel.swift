import Foundation
import SwiftUI

public let appGroupID = "group.com.tendr.app"
public let widgetKind = "TendrWidget"

public let defaultCategory = "Personal"
public let allCategoriesToken = "__all__"

public enum Frequency: Codable, Hashable {
    case everyHours(Int)
    case everyDays(Int)
    case weeklyOn(weekday: Int)   // 1=Domingo … 7=Sábado (Calendar.weekday)
    case monthlyOn(day: Int)      // 1...28

    public func nextDueDate(after lastCompleted: Date, calendar: Calendar = .current) -> Date {
        switch self {
        case .everyHours(let n):
            return lastCompleted.addingTimeInterval(TimeInterval(max(1, n)) * 3_600)

        case .everyDays(let n):
            return calendar.date(byAdding: .day, value: max(1, n), to: lastCompleted) ?? lastCompleted

        case .weeklyOn(let weekday):
            var comp = DateComponents()
            comp.weekday = max(1, min(7, weekday))
            return calendar.nextDate(
                after: lastCompleted,
                matching: comp,
                matchingPolicy: .nextTime
            ) ?? lastCompleted.addingTimeInterval(7 * 86_400)

        case .monthlyOn(let day):
            var comp = DateComponents()
            comp.day = max(1, min(28, day))
            return calendar.nextDate(
                after: lastCompleted,
                matching: comp,
                matchingPolicy: .nextTime
            ) ?? lastCompleted.addingTimeInterval(30 * 86_400)
        }
    }

    public var displayLabel: String {
        switch self {
        case .everyHours(let n):
            return n == 1 ? "Cada hora" : "Cada \(n) horas"
        case .everyDays(let n):
            return n == 1 ? "Cada día" : "Cada \(n) días"
        case .weeklyOn(let w):
            return "Cada \(Frequency.weekdayName(w).lowercased())"
        case .monthlyOn(let d):
            return "El día \(d) de cada mes"
        }
    }

    public static func weekdayName(_ w: Int) -> String {
        let names = ["Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado"]
        let idx = max(1, min(7, w)) - 1
        return names[idx]
    }
}

public struct TareaItem: Identifiable, Codable, Hashable {
    public var id: UUID
    public var name: String
    public var icon: String
    public var frequency: Frequency
    public var lastCompletedAt: Date
    public var category: String
    public var previousCompletedAt: Date?
    public var endsAt: Date?

    public init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        frequency: Frequency,
        lastCompletedAt: Date = Date(),
        category: String = defaultCategory,
        previousCompletedAt: Date? = nil,
        endsAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.frequency = frequency
        self.lastCompletedAt = lastCompletedAt
        self.category = category
        self.previousCompletedAt = previousCompletedAt
        self.endsAt = endsAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, icon, frequency, lastCompletedAt, category, previousCompletedAt, endsAt
    }

    private enum LegacyKeys: String, CodingKey {
        case intervalDays
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        icon = try c.decode(String.self, forKey: .icon)
        if let freq = try c.decodeIfPresent(Frequency.self, forKey: .frequency) {
            frequency = freq
        } else {
            let legacy = try decoder.container(keyedBy: LegacyKeys.self)
            let days = try legacy.decodeIfPresent(Int.self, forKey: .intervalDays) ?? 7
            frequency = .everyDays(days)
        }
        lastCompletedAt = try c.decode(Date.self, forKey: .lastCompletedAt)
        category = try c.decodeIfPresent(String.self, forKey: .category) ?? defaultCategory
        previousCompletedAt = try c.decodeIfPresent(Date.self, forKey: .previousCompletedAt)
        endsAt = try c.decodeIfPresent(Date.self, forKey: .endsAt)
    }

    public func isFinished(at date: Date = Date()) -> Bool {
        guard let endsAt else { return false }
        return date >= endsAt
    }

    public func endsAtText() -> String? {
        guard let endsAt else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "es")
        f.dateStyle = .medium
        return "Termina \(f.string(from: endsAt))"
    }

    public static let criticalThreshold: Double = 0.25

    public func dueDate() -> Date {
        frequency.nextDueDate(after: lastCompletedAt)
    }

    public func progress(at date: Date = Date()) -> Double {
        let total = dueDate().timeIntervalSince(lastCompletedAt)
        guard total > 0 else { return 0 }
        let elapsed = date.timeIntervalSince(lastCompletedAt)
        let remaining = total - elapsed
        return max(0, min(1, remaining / total))
    }

    public func isCritical(at date: Date = Date()) -> Bool {
        progress(at: date) <= Self.criticalThreshold
    }

    public func criticalDate() -> Date {
        let total = dueDate().timeIntervalSince(lastCompletedAt)
        return lastCompletedAt.addingTimeInterval(total * (1 - Self.criticalThreshold))
    }

    public func ringColor(at date: Date = Date()) -> Color {
        let p = progress(at: date)
        if p > 0.5 { return Color(red: 52/255, green: 199/255, blue: 89/255) }   // verde
        if p > 0.25 { return Color(red: 255/255, green: 204/255, blue: 0/255) }  // amarillo
        if p > 0.10 { return Color(red: 255/255, green: 149/255, blue: 0/255) }  // naranja
        return Color(red: 255/255, green: 59/255, blue: 48/255)                   // rojo
    }

    public func remainingText(at date: Date = Date()) -> String {
        let secs = dueDate().timeIntervalSince(date)
        if secs <= 0 { return "vencida" }
        let days = Int(secs / 86_400)
        if days >= 2 { return "en \(days) días" }
        if days == 1 { return "en 1 día" }
        let hours = Int(secs / 3_600)
        if hours >= 2 { return "en \(hours) h" }
        if hours == 1 { return "en 1 h" }
        let mins = Int(secs / 60)
        if mins >= 5 { return "en \(mins) min" }
        return "vence pronto"
    }
}

public enum TareasStore {
    private static let storageKey = "tareas.items.v1"
    private static let stylesKey = "tareas.categoryStyles.v1"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    public static func load() -> [TareaItem] {
        guard let data = defaults?.data(forKey: storageKey),
              let items = try? JSONDecoder().decode([TareaItem].self, from: data)
        else { return [] }
        return items
    }

    public static func save(_ items: [TareaItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults?.set(data, forKey: storageKey)
        for cat in Set(items.map { $0.category }) {
            ensureStyle(for: cat)
        }
    }

    public static func loadStyles() -> [CategoryStyle] {
        guard let data = defaults?.data(forKey: stylesKey),
              let styles = try? JSONDecoder().decode([CategoryStyle].self, from: data)
        else { return [] }
        return styles
    }

    public static func saveStyles(_ styles: [CategoryStyle]) {
        guard let data = try? JSONEncoder().encode(styles) else { return }
        defaults?.set(data, forKey: stylesKey)
    }

    public static func style(for name: String) -> CategoryStyle {
        if let existing = loadStyles().first(where: { $0.name == name }) {
            return existing
        }
        return defaultStyle(for: name)
    }

    public static func ensureStyle(for name: String) {
        var all = loadStyles()
        if all.contains(where: { $0.name == name }) { return }
        all.append(defaultStyle(for: name))
        saveStyles(all)
    }

    public static func upsertStyle(_ style: CategoryStyle) {
        var all = loadStyles()
        if let idx = all.firstIndex(where: { $0.name == style.name }) {
            all[idx] = style
        } else {
            all.append(style)
        }
        saveStyles(all)
    }

    private static func defaultStyle(for name: String) -> CategoryStyle {
        let hash = abs(name.unicodeScalars.reduce(0) { $0 &+ Int($1.value) })
        let colorHex = CategoryPalette.colors[hash % CategoryPalette.colors.count]
        let icon = inferredIcon(for: name)
            ?? CategoryPalette.icons[hash % CategoryPalette.icons.count]
        return CategoryStyle(name: name, icon: icon, colorHex: colorHex)
    }

    private static func inferredIcon(for name: String) -> String? {
        let lower = name.lowercased()
        if lower.contains("casa") || lower.contains("hogar") { return "🏠" }
        if lower.contains("personal") { return "👤" }
        if lower.contains("trabajo") || lower.contains("oficina") { return "💼" }
        if lower.contains("salud") || lower.contains("medic") { return "💊" }
        if lower.contains("masco") || lower.contains("perro") || lower.contains("gato") { return "🐾" }
        if lower.contains("auto") || lower.contains("coche") || lower.contains("carro") { return "🚗" }
        if lower.contains("estudi") || lower.contains("escuela") { return "📚" }
        if lower.contains("plant") || lower.contains("jardin") { return "🌱" }
        if lower.contains("compra") || lower.contains("super") { return "🛒" }
        if lower.contains("dinero") || lower.contains("finanz") { return "💰" }
        return nil
    }

    public static func upsert(_ item: TareaItem) {
        var items = load()
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            items[idx] = item
        } else {
            items.append(item)
        }
        save(items)
        let snapshot = item
        Task { @MainActor in CloudSyncManager.shared.taskUpserted(snapshot) }
    }

    public static func remove(id: UUID) {
        var items = load()
        let category = items.first(where: { $0.id == id })?.category ?? defaultCategory
        items.removeAll { $0.id == id }
        save(items)
        Task { @MainActor in CloudSyncManager.shared.taskDeleted(id: id, category: category) }
    }

    public static let undoWindow: TimeInterval = 3_600

    public static func markCompleted(id: UUID, at date: Date = Date()) {
        var items = load()
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        let recentlyCompleted = date.timeIntervalSince(items[idx].lastCompletedAt) < undoWindow
        if !recentlyCompleted {
            items[idx].previousCompletedAt = items[idx].lastCompletedAt
        }
        items[idx].lastCompletedAt = date
        save(items)
        let snapshot = items[idx]
        Task { @MainActor in CloudSyncManager.shared.taskUpserted(snapshot) }
    }

    public static func undoCompletion(id: UUID) {
        var items = load()
        guard let idx = items.firstIndex(where: { $0.id == id }),
              let prev = items[idx].previousCompletedAt else { return }
        items[idx].lastCompletedAt = prev
        items[idx].previousCompletedAt = nil
        save(items)
        let snapshot = items[idx]
        Task { @MainActor in CloudSyncManager.shared.taskUpserted(snapshot) }
    }

    public static func mostRecentUndoable(at date: Date = Date()) -> TareaItem? {
        let cutoff = date.addingTimeInterval(-undoWindow)
        return load()
            .filter { $0.previousCompletedAt != nil && $0.lastCompletedAt >= cutoff }
            .max { $0.lastCompletedAt < $1.lastCompletedAt }
    }

    public static func sortedByUrgency(at date: Date = Date(), includeFinished: Bool = false) -> [TareaItem] {
        let items = load()
        let scoped = includeFinished ? items : items.filter { !$0.isFinished(at: date) }
        return scoped.sorted { $0.progress(at: date) < $1.progress(at: date) }
    }

    public static func finishedItems(at date: Date = Date()) -> [TareaItem] {
        load()
            .filter { $0.isFinished(at: date) }
            .sorted { ($0.endsAt ?? .distantPast) > ($1.endsAt ?? .distantPast) }
    }

    public static func resumeTask(id: UUID) {
        var items = load()
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].endsAt = nil
        items[idx].lastCompletedAt = Date()
        items[idx].previousCompletedAt = nil
        save(items)
        let snapshot = items[idx]
        Task { @MainActor in CloudSyncManager.shared.taskUpserted(snapshot) }
    }

    public static func categories() -> [String] {
        let set = Set(load().map { $0.category })
        let sorted = set.sorted()
        if sorted.isEmpty { return [defaultCategory] }
        return sorted
    }

    public static func filtered(by category: String?, at date: Date = Date()) -> [TareaItem] {
        let items = sortedByUrgency(at: date)
        guard let category, category != allCategoriesToken else { return items }
        return items.filter { $0.category == category }
    }
}
