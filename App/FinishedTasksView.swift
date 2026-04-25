import SwiftUI
import WidgetKit

struct FinishedTasksView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var items: [TareaItem] = []

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView(
                        "Sin tareas finalizadas",
                        systemImage: "checkmark.seal",
                        description: Text("Las tareas con fecha de fin pasada aparecen aquí.")
                    )
                } else {
                    List {
                        ForEach(items) { item in
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle().fill(Color.gray.opacity(0.15))
                                    Text(item.icon).font(.title3)
                                }
                                .frame(width: 42, height: 42)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(.body).fontWeight(.medium)
                                    if let txt = item.endsAtText() {
                                        Text(txt)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text("\(item.category) · \(item.frequency.displayLabel)")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                Spacer()
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(.green)
                            }
                            .padding(.vertical, 2)
                            .swipeActions(edge: .leading) {
                                Button {
                                    resume(item)
                                } label: {
                                    Label("Reanudar", systemImage: "arrow.clockwise")
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    remove(item)
                                } label: {
                                    Label("Borrar", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Finalizadas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
        .onAppear(perform: refresh)
    }

    private func refresh() {
        items = TareasStore.finishedItems()
    }

    private func resume(_ item: TareaItem) {
        TareasStore.resumeTask(id: item.id)
        NotificationManager.rescheduleAll()
        WidgetCenter.shared.reloadAllTimelines()
        refresh()
    }

    private func remove(_ item: TareaItem) {
        NotificationManager.cancel(taskID: item.id)
        TareasStore.remove(id: item.id)
        WidgetCenter.shared.reloadAllTimelines()
        refresh()
    }
}
