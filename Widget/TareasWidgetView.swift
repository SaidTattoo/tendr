import SwiftUI
import WidgetKit
import AppIntents

struct TareasWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TareasEntry

    private var visibleItems: [TareaItem] {
        var items = entry.items.filter { !$0.isFinished(at: entry.date) }
        if entry.onlyCritical {
            items = items.filter { $0.isCritical(at: entry.date) }
        }
        return items
    }

    var body: some View {
        switch family {
        case .systemSmall:           SmallView(entry: entry, items: visibleItems)
        case .systemMedium:          ListView(entry: entry, items: visibleItems, maxRows: 4)
        case .systemLarge:           ListView(entry: entry, items: visibleItems, maxRows: 8)
        case .accessoryCircular:     CircularLockView(item: visibleItems.first, now: entry.date)
        case .accessoryRectangular:  RectangularLockView(item: visibleItems.first, now: entry.date)
        case .accessoryInline:       InlineLockView(item: visibleItems.first, now: entry.date)
        default:                     ListView(entry: entry, items: visibleItems, maxRows: 4)
        }
    }
}

private struct CircularLockView: View {
    let item: TareaItem?
    let now: Date

    var body: some View {
        if let item {
            Gauge(value: item.progress(at: now)) {
                Text(item.icon)
            } currentValueLabel: {
                Text("\(Int(item.progress(at: now) * 100))")
                    .font(.caption2)
            }
            .gaugeStyle(.accessoryCircularCapacity)
        } else {
            Image(systemName: "checkmark.seal.fill")
                .font(.title2)
        }
    }
}

private struct RectangularLockView: View {
    let item: TareaItem?
    let now: Date

    var body: some View {
        if let item {
            HStack(spacing: 6) {
                Gauge(value: item.progress(at: now)) {
                    Text(item.icon)
                }
                .gaugeStyle(.accessoryCircularCapacity)

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.name).font(.headline).lineLimit(1)
                    Text(item.remainingText(at: now))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        } else {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                Text("Todo al día").font(.headline)
            }
        }
    }
}

private struct InlineLockView: View {
    let item: TareaItem?
    let now: Date

    var body: some View {
        if let item {
            Text("\(item.icon) \(item.name) · \(item.remainingText(at: now))")
        } else {
            Text("✓ Tareas al día")
        }
    }
}

private struct SmallView: View {
    let entry: TareasEntry
    let items: [TareaItem]

    var body: some View {
        if let item = items.first {
            VStack(spacing: 6) {
                HStack(spacing: 4) {
                    Circle().fill(item.ringColor(at: entry.date)).frame(width: 6, height: 6)
                    Text(headerLabel).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    Spacer()
                }
                BigRing(item: item, now: entry.date)
                    .frame(maxHeight: .infinity)
                Text(item.name).font(.caption).fontWeight(.semibold).lineLimit(1)
                Text(item.remainingText(at: entry.date))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        } else {
            EmptyState(onlyCritical: entry.onlyCritical)
        }
    }

    private var headerLabel: String {
        entry.onlyCritical ? "Crítica" : entry.categoryLabel
    }
}

private struct BigRing: View {
    let item: TareaItem
    let now: Date

    var body: some View {
        ZStack {
            Circle().stroke(Color.gray.opacity(0.2), lineWidth: 10)
            Circle()
                .trim(from: 0, to: item.progress(at: now))
                .stroke(item.ringColor(at: now),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text("\(Int(item.progress(at: now) * 100))%")
                    .font(.title3).fontWeight(.bold)
                Text(item.icon).font(.title3)
            }
        }
    }
}

private struct ListView: View {
    let entry: TareasEntry
    let items: [TareaItem]
    let maxRows: Int

    var body: some View {
        if items.isEmpty {
            EmptyState(onlyCritical: entry.onlyCritical)
        } else {
            let visible = Array(items.prefix(maxRows))
            let overflow = items.count - visible.count

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Circle().fill(.green).frame(width: 6, height: 6)
                    Text(headerLabel).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    Spacer()
                    if overflow > 0 {
                        Text("+\(overflow)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                VStack(spacing: 6) {
                    ForEach(visible) { item in
                        Row(item: item, now: entry.date)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var headerLabel: String {
        if entry.onlyCritical {
            return "Críticas · \(entry.categoryLabel)"
        }
        return entry.categoryLabel
    }
}

private struct Row: View {
    let item: TareaItem
    let now: Date

    var body: some View {
        let categoryStyle = TareasStore.style(for: item.category)
        HStack(spacing: 10) {
            ZStack {
                Circle().stroke(Color.gray.opacity(0.2), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: item.progress(at: now))
                    .stroke(item.ringColor(at: now),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(item.icon).font(.callout)
            }
            .frame(width: 32, height: 32)
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(categoryStyle.color)
                    .frame(width: 10, height: 10)
                    .overlay(Circle().stroke(.background, lineWidth: 1.5))
                    .offset(x: 2, y: 2)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(item.name).font(.caption).fontWeight(.semibold).lineLimit(1)
                Text("\(item.remainingText(at: now)) · \(Int(item.progress(at: now) * 100))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)

            Button(intent: CompleteTaskIntent(task: TareaEntity(item))) {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(item.ringColor(at: now).opacity(0.85)))
            }
            .buttonStyle(.plain)
        }
    }
}

private struct EmptyState: View {
    let onlyCritical: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: onlyCritical ? "checkmark.seal.fill" : "checkmark.circle")
                .font(.title)
                .foregroundStyle(.green.opacity(0.7))
            Text(onlyCritical ? "Todo al día" : "Sin tareas")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
