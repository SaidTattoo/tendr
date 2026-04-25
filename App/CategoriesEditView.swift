import SwiftUI
import UIKit
import WidgetKit

struct CategoriesEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var styles: [CategoryStyle] = []
    @State private var editing: CategoryStyle?
    @State private var shareURL: URL?
    @State private var sharingCategory: String?
    @State private var shareError: String?

    var body: some View {
        NavigationStack {
            List {
                ForEach(styles, id: \.name) { style in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(style.color)
                            Text(style.icon).font(.title3)
                        }
                        .frame(width: 36, height: 36)

                        Text(style.name).font(.body)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { editing = style }
                    .swipeActions(edge: .leading) {
                        Button {
                            share(category: style.name)
                        } label: {
                            Label("Compartir", systemImage: "person.2")
                        }
                        .tint(.blue)
                    }
                }
            }
            .navigationTitle("Categorías")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .sheet(item: $editing) { style in
                CategoryStyleEditor(
                    style: style,
                    onSave: { updated in
                        TareasStore.upsertStyle(updated)
                        refresh()
                        WidgetCenter.shared.reloadAllTimelines()
                    },
                    onShare: {
                        share(category: style.name)
                    }
                )
            }
            .sheet(item: shareURLWrapper) { wrapped in
                ActivityView(activityItems: [wrapped.url])
            }
            .alert("No se puede compartir",
                   isPresented: Binding(
                    get: { shareError != nil },
                    set: { if !$0 { shareError = nil } }
                   ),
                   actions: {
                       Button("OK", role: .cancel) { shareError = nil }
                   },
                   message: { Text(shareError ?? "") })
            .onAppear(perform: refresh)
        }
    }

    private struct URLWrapper: Identifiable {
        let url: URL
        var id: String { url.absoluteString }
    }

    private var shareURLWrapper: Binding<URLWrapper?> {
        Binding(
            get: { shareURL.map { URLWrapper(url: $0) } },
            set: { if $0 == nil { shareURL = nil } }
        )
    }

    private func share(category: String) {
        sharingCategory = category
        Task {
            do {
                let url = try await CloudSyncManager.shared.shareCategoryURL(category)
                await MainActor.run {
                    shareURL = url
                    sharingCategory = nil
                }
            } catch CloudSyncError.unavailable {
                await MainActor.run {
                    shareError = "iCloud no está configurado o no hay sesión activa. Verifica que estás iniciado en iCloud y que el contenedor está activo."
                    sharingCategory = nil
                }
            } catch {
                await MainActor.run {
                    shareError = "No se pudo crear el link: \(error.localizedDescription)"
                    sharingCategory = nil
                }
            }
        }
    }

    private func refresh() {
        let known = Set(styles.map { $0.name })
        var loaded = TareasStore.loadStyles()
        for cat in TareasStore.categories() where !known.contains(cat) {
            TareasStore.ensureStyle(for: cat)
        }
        loaded = TareasStore.loadStyles().sorted { $0.name < $1.name }
        styles = loaded
    }
}

extension CategoryStyle: Identifiable {
    public var id: String { name }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct CategoryStyleEditor: View {
    let style: CategoryStyle
    let onSave: (CategoryStyle) -> Void
    let onShare: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var icon: String
    @State private var colorHex: String

    init(style: CategoryStyle,
         onSave: @escaping (CategoryStyle) -> Void,
         onShare: @escaping () -> Void) {
        self.style = style
        self.onSave = onSave
        self.onShare = onShare
        _icon = State(initialValue: style.icon)
        _colorHex = State(initialValue: style.colorHex)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle().fill(Color(hex: colorHex) ?? .gray)
                            Text(icon).font(.system(size: 32))
                        }
                        .frame(width: 64, height: 64)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(style.name).font(.title3).fontWeight(.semibold)
                            Text("Vista previa").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }

                Section("Icono") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(CategoryPalette.icons, id: \.self) { emoji in
                            Text(emoji)
                                .font(.title)
                                .frame(width: 44, height: 44)
                                .background(icon == emoji ? Color.accentColor.opacity(0.25) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .onTapGesture { icon = emoji }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(CategoryPalette.colors, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex) ?? .gray)
                                .frame(width: 38, height: 38)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: colorHex == hex ? 3 : 0)
                                )
                                .onTapGesture { colorHex = hex }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    Button {
                        onShare()
                        dismiss()
                    } label: {
                        Label("Compartir con la familia", systemImage: "person.2.fill")
                    }
                } footer: {
                    Text("Genera un link de iCloud para que otras personas vean y editen las tareas de esta categoría.")
                        .font(.footnote)
                }
            }
            .navigationTitle(style.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        onSave(CategoryStyle(name: style.name, icon: icon, colorHex: colorHex))
                        dismiss()
                    }
                }
            }
        }
    }
}
