import AppIntents
import WidgetKit

public struct CompleteTaskIntent: AppIntent {
    public static var title: LocalizedStringResource = "Marcar tarea como hecha"
    public static var description = IntentDescription("Reinicia el ciclo de la tarea.")

    @Parameter(title: "Tarea")
    public var task: TareaEntity

    public init() {}

    public init(task: TareaEntity) {
        self.task = task
    }

    public init(taskID: String) {
        self.task = TareaEntity(id: UUID(uuidString: taskID) ?? UUID(), name: "", icon: "")
    }

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        TareasStore.markCompleted(id: task.id)
        NotificationManager.rescheduleAll()
        WidgetCenter.shared.reloadAllTimelines()
        return .result(dialog: "Listo, \(task.name) marcada como hecha.")
    }
}

public struct SnoozeTaskIntent: AppIntent {
    public static var title: LocalizedStringResource = "Posponer tarea"
    public static var description = IntentDescription("Pospone una tarea unas horas sin marcarla como hecha.")

    @Parameter(title: "Tarea")
    public var task: TareaEntity

    @Parameter(title: "Horas", default: 1, controlStyle: .stepper, inclusiveRange: (1, 48))
    public var hours: Int

    public init() {}

    public init(task: TareaEntity, hours: Int = 1) {
        self.task = task
        self.hours = hours
    }

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        TareasStore.snooze(id: task.id, by: TimeInterval(hours) * 3_600)
        NotificationManager.rescheduleAll()
        WidgetCenter.shared.reloadAllTimelines()
        let unidad = hours == 1 ? "hora" : "horas"
        return .result(dialog: "\(task.name) pospuesta \(hours) \(unidad).")
    }
}

public struct SkipCycleIntent: AppIntent {
    public static var title: LocalizedStringResource = "Saltar este ciclo"
    public static var description = IntentDescription("Reinicia el contador sin contar como completada.")

    @Parameter(title: "Tarea")
    public var task: TareaEntity

    public init() {}

    public init(task: TareaEntity) {
        self.task = task
    }

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        TareasStore.skipCycle(id: task.id)
        NotificationManager.rescheduleAll()
        WidgetCenter.shared.reloadAllTimelines()
        return .result(dialog: "Saltaste este ciclo de \(task.name).")
    }
}

public struct TendrShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CompleteTaskIntent(),
            phrases: [
                "Marcar \(\.$task) como hecha en \(.applicationName)",
                "Completar \(\.$task) en \(.applicationName)",
                "\(\.$task) hecha en \(.applicationName)"
            ],
            shortTitle: "Marcar como hecha",
            systemImageName: "checkmark.circle"
        )
        AppShortcut(
            intent: SnoozeTaskIntent(),
            phrases: [
                "Posponer \(\.$task) en \(.applicationName)",
                "Snooze \(\.$task) en \(.applicationName)"
            ],
            shortTitle: "Posponer tarea",
            systemImageName: "clock.arrow.circlepath"
        )
        AppShortcut(
            intent: SkipCycleIntent(),
            phrases: [
                "Saltar ciclo de \(\.$task) en \(.applicationName)",
                "Saltar \(\.$task) en \(.applicationName)"
            ],
            shortTitle: "Saltar ciclo",
            systemImageName: "forward"
        )
    }
}
