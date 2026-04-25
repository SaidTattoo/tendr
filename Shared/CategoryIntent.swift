import AppIntents
import WidgetKit

public struct CategoryEntity: AppEntity, Identifiable {
    public var id: String

    public init(id: String) {
        self.id = id
    }

    public var displayName: String {
        id == allCategoriesToken ? "Todas" : id
    }

    public static var typeDisplayRepresentation: TypeDisplayRepresentation = "Categoría"

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(stringLiteral: displayName)
    }

    public static var defaultQuery = CategoryQuery()
}

public struct CategoryQuery: EntityQuery {
    public init() {}

    public func entities(for identifiers: [CategoryEntity.ID]) async throws -> [CategoryEntity] {
        identifiers.map { CategoryEntity(id: $0) }
    }

    public func suggestedEntities() async throws -> [CategoryEntity] {
        let categories = TareasStore.categories()
        return [CategoryEntity(id: allCategoriesToken)]
            + categories.map { CategoryEntity(id: $0) }
    }

    public func defaultResult() async -> CategoryEntity? {
        CategoryEntity(id: allCategoriesToken)
    }
}

public struct CategoryFilterIntent: WidgetConfigurationIntent {
    public static var title: LocalizedStringResource = "Filtrar tareas"
    public static var description = IntentDescription("Elige qué categoría mostrar y si solo deben verse las críticas.")

    @Parameter(title: "Categoría")
    public var category: CategoryEntity?

    @Parameter(title: "Solo críticas", default: false)
    public var onlyCritical: Bool

    public init() {}

    public init(category: CategoryEntity?, onlyCritical: Bool = false) {
        self.category = category
        self.onlyCritical = onlyCritical
    }
}
