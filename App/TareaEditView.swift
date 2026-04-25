import SwiftUI

enum TareaEditMode {
    case create
    case edit(TareaItem)
}

private enum FreqType: String, CaseIterable, Identifiable {
    case hourly, daily, weekly, monthly
    var id: String { rawValue }
    var label: String {
        switch self {
        case .hourly: return "Horas"
        case .daily: return "Días"
        case .weekly: return "Semanal"
        case .monthly: return "Mensual"
        }
    }
}

struct TareaEditView: View {
    let mode: TareaEditMode
    let existingCategories: [String]
    let onSave: (TareaItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var icon: String
    @State private var lastCompletedAt: Date
    @State private var category: String
    @State private var newCategory: String = ""
    @State private var existingID: UUID?

    @State private var freqType: FreqType
    @State private var freqHours: Int
    @State private var freqDays: Int
    @State private var freqWeekday: Int
    @State private var freqMonthDay: Int

    @State private var hasEnd: Bool
    @State private var endsAt: Date

    private let iconOptions = ["🌱","💊","🐱","🛏️","🚗","📚","🧺","🧹","🪥","💧","🍽️","🐶","💪","🧴","🧼","📞"]

    init(mode: TareaEditMode, existingCategories: [String], onSave: @escaping (TareaItem) -> Void) {
        self.mode = mode
        self.existingCategories = existingCategories
        self.onSave = onSave
        let oneWeekFromNow = Date().addingTimeInterval(7 * 86_400)
        switch mode {
        case .create:
            _name = State(initialValue: "")
            _icon = State(initialValue: "🌱")
            _lastCompletedAt = State(initialValue: Date())
            _category = State(initialValue: existingCategories.first ?? defaultCategory)
            _existingID = State(initialValue: nil)
            _freqType = State(initialValue: .daily)
            _freqHours = State(initialValue: 8)
            _freqDays = State(initialValue: 7)
            _freqWeekday = State(initialValue: 2) // Lunes
            _freqMonthDay = State(initialValue: 1)
            _hasEnd = State(initialValue: false)
            _endsAt = State(initialValue: oneWeekFromNow)
        case .edit(let item):
            _name = State(initialValue: item.name)
            _icon = State(initialValue: item.icon)
            _lastCompletedAt = State(initialValue: item.lastCompletedAt)
            _category = State(initialValue: item.category)
            _existingID = State(initialValue: item.id)
            switch item.frequency {
            case .everyHours(let n):
                _freqType = State(initialValue: .hourly)
                _freqHours = State(initialValue: n)
                _freqDays = State(initialValue: 7); _freqWeekday = State(initialValue: 2); _freqMonthDay = State(initialValue: 1)
            case .everyDays(let n):
                _freqType = State(initialValue: .daily)
                _freqDays = State(initialValue: n)
                _freqHours = State(initialValue: 8); _freqWeekday = State(initialValue: 2); _freqMonthDay = State(initialValue: 1)
            case .weeklyOn(let w):
                _freqType = State(initialValue: .weekly)
                _freqWeekday = State(initialValue: w)
                _freqHours = State(initialValue: 8); _freqDays = State(initialValue: 7); _freqMonthDay = State(initialValue: 1)
            case .monthlyOn(let d):
                _freqType = State(initialValue: .monthly)
                _freqMonthDay = State(initialValue: d)
                _freqHours = State(initialValue: 8); _freqDays = State(initialValue: 7); _freqWeekday = State(initialValue: 2)
            }
            _hasEnd = State(initialValue: item.endsAt != nil)
            _endsAt = State(initialValue: item.endsAt ?? oneWeekFromNow)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Nombre") {
                    TextField("Ej. Regar planta", text: $name)
                }

                Section("Categoría") {
                    Picker("Categoría", selection: $category) {
                        ForEach(categoryOptions, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                    .pickerStyle(.menu)

                    HStack {
                        TextField("Nueva categoría…", text: $newCategory)
                            .textInputAutocapitalization(.words)
                        Button("Añadir") {
                            let trimmed = newCategory.trimmingCharacters(in: .whitespaces)
                            guard !trimmed.isEmpty else { return }
                            category = trimmed
                            newCategory = ""
                        }
                        .disabled(newCategory.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                Section("Icono") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(iconOptions, id: \.self) { emoji in
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

                Section("Frecuencia") {
                    Picker("Tipo", selection: $freqType) {
                        ForEach(FreqType.allCases) { t in
                            Text(t.label).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch freqType {
                    case .hourly:
                        Stepper(value: $freqHours, in: 1...23) {
                            Text(freqHours == 1 ? "Cada hora" : "Cada \(freqHours) horas")
                        }
                    case .daily:
                        Stepper(value: $freqDays, in: 1...365) {
                            Text(freqDays == 1 ? "Cada día" : "Cada \(freqDays) días")
                        }
                    case .weekly:
                        Picker("Día de la semana", selection: $freqWeekday) {
                            ForEach(1...7, id: \.self) { w in
                                Text(Frequency.weekdayName(w)).tag(w)
                            }
                        }
                        .pickerStyle(.menu)
                    case .monthly:
                        Stepper(value: $freqMonthDay, in: 1...28) {
                            Text("El día \(freqMonthDay) de cada mes")
                        }
                    }
                }

                Section("Duración") {
                    Toggle("Tiene fecha de fin", isOn: $hasEnd)
                    if hasEnd {
                        DatePicker("Termina", selection: $endsAt, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                    }
                }

                Section("Última vez completada") {
                    DatePicker("Fecha", selection: $lastCompletedAt, displayedComponents: [.date, .hourAndMinute])
                }

                if existingID != nil {
                    Section {
                        Button {
                            lastCompletedAt = Date()
                        } label: {
                            Label("Marcar como hecho ahora", systemImage: "checkmark.circle.fill")
                        }
                    }
                }
            }
            .navigationTitle(existingID == nil ? "Nueva tarea" : "Editar tarea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        let item = TareaItem(
                            id: existingID ?? UUID(),
                            name: name.trimmingCharacters(in: .whitespaces),
                            icon: icon,
                            frequency: buildFrequency(),
                            lastCompletedAt: lastCompletedAt,
                            category: category.trimmingCharacters(in: .whitespaces).isEmpty
                                ? defaultCategory : category,
                            endsAt: hasEnd ? endsAt : nil
                        )
                        onSave(item)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private var categoryOptions: [String] {
        var opts = existingCategories
        if !opts.contains(category) { opts.append(category) }
        if !opts.contains(defaultCategory) { opts.insert(defaultCategory, at: 0) }
        return opts
    }

    private func buildFrequency() -> Frequency {
        switch freqType {
        case .hourly:  return .everyHours(freqHours)
        case .daily:   return .everyDays(freqDays)
        case .weekly:  return .weeklyOn(weekday: freqWeekday)
        case .monthly: return .monthlyOn(day: freqMonthDay)
        }
    }
}
