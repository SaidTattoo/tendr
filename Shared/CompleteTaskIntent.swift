import AppIntents
import WidgetKit

public struct CompleteTaskIntent: AppIntent {
    public static var title: LocalizedStringResource = "Marcar como hecha"
    public static var description = IntentDescription("Reinicia el ciclo de la tarea.")

    @Parameter(title: "ID")
    public var taskID: String

    public init() {}

    public init(taskID: String) {
        self.taskID = taskID
    }

    public func perform() async throws -> some IntentResult {
        if let uuid = UUID(uuidString: taskID) {
            TareasStore.markCompleted(id: uuid)
            NotificationManager.rescheduleAll()
            WidgetCenter.shared.reloadAllTimelines()
        }
        return .result()
    }
}
