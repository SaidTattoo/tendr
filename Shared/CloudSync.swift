import Foundation
import CloudKit

public extension Notification.Name {
    static let cloudSyncDidUpdate = Notification.Name("cloudSyncDidUpdate")
}

public enum CloudSyncError: Error {
    case unavailable
    case shareURLMissing
}

@inline(__always)
private func cloudLog(_ message: @autoclosure () -> String) {
    #if DEBUG
    print("[CloudSync] \(message())")
    #endif
}

@MainActor
public final class CloudSyncManager {
    public static let shared = CloudSyncManager()

    private let container: CKContainer
    private let privateDB: CKDatabase
    private let sharedDB: CKDatabase

    private var privateEngine: CKSyncEngine?
    private var sharedEngine: CKSyncEngine?

    private let privateStateKey = "tareas.cksync.private.v1"
    private let sharedStateKey = "tareas.cksync.shared.v1"
    private let zoneMapKey = "tareas.cksync.zoneMap.v1"

    /// category name → zoneID. Used to remember the actual ownerName of shared zones.
    private var zoneMap: [String: CKRecordZone.ID] = [:]

    private var defaults: UserDefaults? { UserDefaults(suiteName: appGroupID) }

    public private(set) var isAvailable: Bool = false

    private init() {
        self.container = CKContainer(identifier: cloudContainerID)
        self.privateDB = container.privateCloudDatabase
        self.sharedDB = container.sharedCloudDatabase
    }

    // MARK: - Lifecycle

    public func start() async {
        guard privateEngine == nil else { return }

        let status = (try? await container.accountStatus()) ?? .couldNotDetermine
        guard status == .available else {
            cloudLog("iCloud unavailable: \(status). Continuing local-only.")
            return
        }
        isAvailable = true

        zoneMap = loadZoneMap()

        privateEngine = CKSyncEngine(CKSyncEngine.Configuration(
            database: privateDB,
            stateSerialization: loadState(key: privateStateKey),
            delegate: self
        ))
        sharedEngine = CKSyncEngine(CKSyncEngine.Configuration(
            database: sharedDB,
            stateSerialization: loadState(key: sharedStateKey),
            delegate: self
        ))

        do {
            try await privateEngine?.fetchChanges()
        } catch {
            cloudLog("private fetch error: \(error)")
        }
        do {
            try await sharedEngine?.fetchChanges()
        } catch {
            cloudLog("shared fetch error: \(error)")
        }
    }

    // MARK: - Mutations

    public func taskUpserted(_ task: TareaItem) {
        guard isAvailable else { return }
        let zoneID = zone(for: task.category)
        let isPrivate = zoneID.ownerName == CKCurrentUserDefaultName
        let engine = isPrivate ? privateEngine : sharedEngine
        guard let engine else { return }

        if isPrivate {
            engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: zoneID))])
        }
        let recordID = CKRecord.ID(recordName: task.id.uuidString, zoneID: zoneID)
        engine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
    }

    public func taskDeleted(id: UUID, category: String) {
        guard isAvailable else { return }
        let zoneID = zone(for: category)
        let engine = zoneID.ownerName == CKCurrentUserDefaultName ? privateEngine : sharedEngine
        guard let engine else { return }
        let recordID = CKRecord.ID(recordName: id.uuidString, zoneID: zoneID)
        engine.state.add(pendingRecordZoneChanges: [.deleteRecord(recordID)])
    }

    private func zone(for category: String) -> CKRecordZone.ID {
        if let mapped = zoneMap[category] { return mapped }
        return CloudZone.zoneID(for: category)
    }

    // MARK: - Sharing (owner)

    public func shareCategoryURL(_ category: String) async throws -> URL {
        guard isAvailable, let engine = privateEngine else { throw CloudSyncError.unavailable }
        let zoneID = CloudZone.zoneID(for: category)
        engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: zoneID))])
        try await engine.sendChanges()

        if let existing = try await fetchExistingShare(in: zoneID), let url = existing.url {
            return url
        }

        let share = CKShare(recordZoneID: zoneID)
        share[CKShare.SystemFieldKey.title] = "Tareas · \(category)" as CKRecordValue
        share.publicPermission = .none

        let saved = try await privateDB.modifyRecords(saving: [share], deleting: [])
        guard let result = saved.saveResults[share.recordID] else {
            throw CloudSyncError.shareURLMissing
        }
        switch result {
        case .success(let savedRecord):
            guard let savedShare = savedRecord as? CKShare, let url = savedShare.url else {
                throw CloudSyncError.shareURLMissing
            }
            return url
        case .failure(let error):
            throw error
        }
    }

    private func fetchExistingShare(in zoneID: CKRecordZone.ID) async throws -> CKShare? {
        let shareID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zoneID)
        do {
            let record = try await privateDB.record(for: shareID)
            return record as? CKShare
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    // MARK: - Sharing (recipient)

    public func acceptShare(metadata: CKShare.Metadata) async {
        do {
            _ = try await container.accept(metadata)
            try await sharedEngine?.fetchChanges()
            NotificationCenter.default.post(name: .cloudSyncDidUpdate, object: nil)
        } catch {
            cloudLog("accept share error: \(error)")
        }
    }

    // MARK: - State persistence

    private func loadState(key: String) -> CKSyncEngine.State.Serialization? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: data)
    }

    private func saveState(_ state: CKSyncEngine.State.Serialization, key: String) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults?.set(data, forKey: key)
    }

    private struct PersistedZone: Codable {
        let zoneName: String
        let ownerName: String
    }

    private func loadZoneMap() -> [String: CKRecordZone.ID] {
        guard let data = defaults?.data(forKey: zoneMapKey),
              let raw = try? JSONDecoder().decode([String: PersistedZone].self, from: data)
        else { return [:] }
        return raw.mapValues { CKRecordZone.ID(zoneName: $0.zoneName, ownerName: $0.ownerName) }
    }

    private func saveZoneMap(_ map: [String: CKRecordZone.ID]) {
        let raw = map.mapValues { PersistedZone(zoneName: $0.zoneName, ownerName: $0.ownerName) }
        guard let data = try? JSONEncoder().encode(raw) else { return }
        defaults?.set(data, forKey: zoneMapKey)
    }
}

extension CloudSyncManager: CKSyncEngineDelegate {
    public func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        let isPrivate = (syncEngine === privateEngine)
        let stateKey = isPrivate ? privateStateKey : sharedStateKey

        switch event {
        case .stateUpdate(let update):
            saveState(update.stateSerialization, key: stateKey)

        case .fetchedRecordZoneChanges(let changes):
            await applyFetched(changes: changes)

        case .fetchedDatabaseChanges(let changes):
            await applyDatabaseChanges(changes, isPrivate: isPrivate)

        case .accountChange(let change):
            cloudLog("account change: \(change)")

        default:
            break
        }
    }

    public func nextRecordZoneChangeBatch(
        _ context: CKSyncEngine.SendChangesContext,
        syncEngine: CKSyncEngine
    ) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let scope = context.options.scope
        let pending = syncEngine.state.pendingRecordZoneChanges.filter { scope.contains($0) }
        let items = TareasStore.load()

        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: pending) { recordID in
            guard let task = items.first(where: { $0.id.uuidString == recordID.recordName }) else {
                return nil
            }
            let record = CKRecord(recordType: taskRecordType, recordID: recordID)
            task.apply(to: record)
            return record
        }
    }

    private func applyFetched(changes: CKSyncEngine.Event.FetchedRecordZoneChanges) async {
        var items = TareasStore.load()
        var changed = false

        for modification in changes.modifications {
            guard let task = TareaItem(record: modification.record) else { continue }
            if let idx = items.firstIndex(where: { $0.id == task.id }) {
                items[idx] = task
            } else {
                items.append(task)
            }
            changed = true

            // Remember the zone in case we need to write back.
            zoneMap[task.category] = modification.record.recordID.zoneID
        }

        for deletion in changes.deletions {
            if let id = UUID(uuidString: deletion.recordID.recordName),
               items.contains(where: { $0.id == id }) {
                items.removeAll { $0.id == id }
                changed = true
            }
        }

        if changed {
            saveZoneMap(zoneMap)
            TareasStore.save(items)
            NotificationCenter.default.post(name: .cloudSyncDidUpdate, object: nil)
        }
    }

    private func applyDatabaseChanges(_ changes: CKSyncEngine.Event.FetchedDatabaseChanges, isPrivate: Bool) async {
        for modification in changes.modifications {
            let zoneID = modification.zoneID
            if let category = CloudZone.categoryName(from: zoneID) {
                zoneMap[category] = zoneID
            }
        }
        for deletion in changes.deletions {
            if let category = CloudZone.categoryName(from: deletion.zoneID) {
                zoneMap.removeValue(forKey: category)
            }
        }
        saveZoneMap(zoneMap)
    }
}
