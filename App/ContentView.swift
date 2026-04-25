import SwiftUI
import WidgetKit

struct ContentView: View {
    @State private var items: [TareaItem] = []
    @State private var showingAdd = false
    @State private var editing: TareaItem?
    @State private var tick = Date()
    @State private var selectedCategory: String = allCategoriesToken
    @State private var undoCandidate: TareaItem?
    @State private var showingFinished = false
    @State private var showingCategories = false
    @State private var finishedCount = 0
    @Environment(\.scenePhase) private var scenePhase

    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView(
                        "Sin tareas",
                        systemImage: "checkmark.circle",
                        description: Text("Toca + para crear tu primera tarea recurrente.")
                    )
                } else {
                    List {
                        ForEach(visibleCategories(), id: \.self) { cat in
                            Section {
                                ForEach(items.filter { $0.category == cat }) { item in
                                    TareaRow(item: item, now: tick)
                                        .contentShape(Rectangle())
                                        .onTapGesture { editing = item }
                                        .swipeActions(edge: .leading) {
                                            Button { complete(item) } label: {
                                                Label("Hecho", systemImage: "checkmark")
                                            }
                                            .tint(.green)
                                        }
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                remove(item)
                                            } label: {
                                                Label("Borrar", systemImage: "trash")
                                            }
                                        }
                                        .contextMenu {
                                            Button {
                                                complete(item)
                                            } label: {
                                                Label("Marcar hecho", systemImage: "checkmark.circle")
                                            }
                                            Menu("Posponer") {
                                                Button("1 hora") { snooze(item, hours: 1) }
                                                Button("3 horas") { snooze(item, hours: 3) }
                                                Button("1 día") { snooze(item, hours: 24) }
                                            }
                                            Button {
                                                skip(item)
                                            } label: {
                                                Label("Saltar este ciclo", systemImage: "forward")
                                            }
                                            Divider()
                                            Button(role: .destructive) {
                                                remove(item)
                                            } label: {
                                                Label("Borrar", systemImage: "trash")
                                            }
                                        }
                                }
                            } header: {
                                CategoryHeader(style: TareasStore.style(for: cat))
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Tareas")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button {
                            selectedCategory = allCategoriesToken
                        } label: {
                            Label("Todas", systemImage: selectedCategory == allCategoriesToken ? "checkmark" : "list.bullet")
                        }
                        Divider()
                        ForEach(allCategories(), id: \.self) { cat in
                            Button {
                                selectedCategory = cat
                            } label: {
                                let style = TareasStore.style(for: cat)
                                HStack {
                                    Text(style.icon)
                                    Text(cat)
                                    if selectedCategory == cat {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                        Divider()
                        Button {
                            showingCategories = true
                        } label: {
                            Label("Editar categorías…", systemImage: "paintpalette")
                        }
                    } label: {
                        Label(filterLabel, systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                if finishedCount > 0 {
                    ToolbarItem(placement: .bottomBar) {
                        Button {
                            showingFinished = true
                        } label: {
                            Label("Finalizadas (\(finishedCount))", systemImage: "checkmark.seal")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                TareaEditView(mode: .create, existingCategories: allCategories()) { newItem in
                    TareasStore.upsert(newItem)
                    refresh()
                }
            }
            .sheet(item: $editing) { item in
                TareaEditView(mode: .edit(item), existingCategories: allCategories()) { updated in
                    TareasStore.upsert(updated)
                    refresh()
                }
            }
            .sheet(isPresented: $showingFinished, onDismiss: refresh) {
                FinishedTasksView()
            }
            .sheet(isPresented: $showingCategories, onDismiss: refresh) {
                CategoriesEditView()
            }
        }
        .onAppear(perform: refresh)
        .onReceive(timer) { now in
            tick = now
            undoCandidate = TareasStore.mostRecentUndoable(at: now)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refresh() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .cloudSyncDidUpdate)) { _ in
            refresh()
        }
        .safeAreaInset(edge: .bottom) {
            if let candidate = undoCandidate {
                UndoBanner(item: candidate) {
                    undo(candidate)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.horizontal)
                .padding(.bottom, 4)
            }
        }
        .animation(.spring(duration: 0.3), value: undoCandidate?.id)
    }

    private func undo(_ item: TareaItem) {
        TareasStore.undoCompletion(id: item.id)
        refresh()
    }

    private var filterLabel: String {
        selectedCategory == allCategoriesToken ? "Todas" : selectedCategory
    }

    private func allCategories() -> [String] {
        TareasStore.categories()
    }

    private func visibleCategories() -> [String] {
        if selectedCategory == allCategoriesToken {
            let used = Set(items.map { $0.category })
            return allCategories().filter { used.contains($0) }
        }
        return [selectedCategory]
    }

    private func refresh() {
        let all = TareasStore.sortedByUrgency()
        if selectedCategory == allCategoriesToken {
            items = all
        } else {
            items = all.filter { $0.category == selectedCategory }
        }
        undoCandidate = TareasStore.mostRecentUndoable(at: tick)
        finishedCount = TareasStore.finishedItems().count
        NotificationManager.rescheduleAll()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func complete(_ item: TareaItem) {
        TareasStore.markCompleted(id: item.id)
        refresh()
    }

    private func snooze(_ item: TareaItem, hours: Int) {
        TareasStore.snooze(id: item.id, by: TimeInterval(hours) * 3_600)
        refresh()
    }

    private func skip(_ item: TareaItem) {
        TareasStore.skipCycle(id: item.id)
        refresh()
    }

    private func remove(_ item: TareaItem) {
        NotificationManager.cancel(taskID: item.id)
        TareasStore.remove(id: item.id)
        refresh()
    }
}

struct TareaRow: View {
    let item: TareaItem
    let now: Date

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: item.progress(at: now))
                    .stroke(item.ringColor(at: now),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(item.icon).font(.title3)
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.body).fontWeight(.medium)
                Text("\(item.remainingText(at: now)) · \(Int(item.progress(at: now) * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let endsText = item.endsAtText() {
                    Label(endsText, systemImage: "calendar.badge.clock")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .labelStyle(.titleAndIcon)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct CategoryHeader: View {
    let style: CategoryStyle

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle().fill(style.color)
                Text(style.icon).font(.caption)
            }
            .frame(width: 22, height: 22)
            Text(style.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Spacer()
        }
        .textCase(nil)
    }
}

struct UndoBanner: View {
    let item: TareaItem
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 1) {
                Text("Marcaste “\(item.icon) \(item.name)”").font(.callout).lineLimit(1)
                Text("hace \(relativeTimeText(from: item.lastCompletedAt))")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Deshacer", action: onUndo)
                .font(.callout.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.primary.opacity(0.05), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
    }

    private func relativeTimeText(from date: Date) -> String {
        let secs = Int(Date().timeIntervalSince(date))
        if secs < 60 { return "unos segundos" }
        let mins = secs / 60
        if mins < 60 { return "\(mins) min" }
        return "\(mins / 60) h"
    }
}

#Preview {
    ContentView()
}
