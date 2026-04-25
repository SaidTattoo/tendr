import AppIntents

public struct TareaEntity: AppEntity, Identifiable {
    public var id: UUID
    public var name: String
    public var icon: String

    public init(id: UUID, name: String, icon: String) {
        self.id = id
        self.name = name
        self.icon = icon
    }

    public init(_ item: TareaItem) {
        self.id = item.id
        self.name = item.name
        self.icon = item.icon
    }

    public static var typeDisplayRepresentation: TypeDisplayRepresentation = "Tarea"

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(icon) \(name)")
    }

    public static var defaultQuery = TareaQuery()
}

public struct TareaQuery: EntityQuery {
    public init() {}

    public func entities(for identifiers: [UUID]) async throws -> [TareaEntity] {
        TareasStore.load()
            .filter { identifiers.contains($0.id) }
            .map(TareaEntity.init)
    }

    public func suggestedEntities() async throws -> [TareaEntity] {
        TareasStore.sortedByUrgency()
            .prefix(30)
            .map(TareaEntity.init)
    }
}
