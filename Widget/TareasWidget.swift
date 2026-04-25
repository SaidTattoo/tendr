import WidgetKit
import SwiftUI
import AppIntents

struct TareasEntry: TimelineEntry {
    let date: Date
    let items: [TareaItem]
    let categoryLabel: String
    let onlyCritical: Bool
}

struct TareasProvider: AppIntentTimelineProvider {
    typealias Entry = TareasEntry
    typealias Intent = CategoryFilterIntent

    func placeholder(in context: Context) -> TareasEntry {
        TareasEntry(date: Date(), items: Self.placeholderItems(), categoryLabel: "Mis tareas", onlyCritical: false)
    }

    func snapshot(for configuration: CategoryFilterIntent, in context: Context) async -> TareasEntry {
        let id = configuration.category?.id ?? allCategoriesToken
        let items = TareasStore.filtered(by: id)
        let display = items.isEmpty ? Self.placeholderItems() : items
        return TareasEntry(
            date: Date(),
            items: display,
            categoryLabel: Self.label(for: id),
            onlyCritical: configuration.onlyCritical
        )
    }

    func timeline(for configuration: CategoryFilterIntent, in context: Context) async -> Timeline<TareasEntry> {
        let id = configuration.category?.id ?? allCategoriesToken
        let items = TareasStore.filtered(by: id)
        let label = Self.label(for: id)
        let now = Date()
        var entries: [TareasEntry] = []

        for hour in 0..<24 {
            let date = now.addingTimeInterval(TimeInterval(hour) * 3_600)
            entries.append(TareasEntry(
                date: date,
                items: items,
                categoryLabel: label,
                onlyCritical: configuration.onlyCritical
            ))
        }

        let refresh = now.addingTimeInterval(24 * 3_600)
        return Timeline(entries: entries, policy: .after(refresh))
    }

    private static func label(for id: String) -> String {
        id == allCategoriesToken ? "Mis tareas" : id
    }

    private static func placeholderItems() -> [TareaItem] {
        let now = Date()
        return [
            .init(name: "Regar planta", icon: "🌱", frequency: .everyDays(7),
                  lastCompletedAt: now.addingTimeInterval(-2 * 86_400),
                  category: "Casa"),
            .init(name: "Limpiar arenero", icon: "🐱", frequency: .weeklyOn(weekday: 7),
                  lastCompletedAt: now.addingTimeInterval(-2 * 86_400),
                  category: "Casa"),
            .init(name: "Tomar vitamina", icon: "💊", frequency: .everyHours(8),
                  lastCompletedAt: now.addingTimeInterval(-6 * 3_600),
                  category: "Personal"),
        ]
    }
}

struct TareasWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: widgetKind,
            intent: CategoryFilterIntent.self,
            provider: TareasProvider()
        ) { entry in
            TareasWidgetView(entry: entry)
                .containerBackground(.regularMaterial, for: .widget)
        }
        .configurationDisplayName("Tareas")
        .description("Tiempo restante de tus tareas recurrentes.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryCircular, .accessoryRectangular, .accessoryInline
        ])
    }
}
