import Foundation
import CloudKit

public let cloudContainerID = "iCloud.com.tendr.app"
public let taskRecordType = "Tarea"

public extension TareaItem {
    init?(record: CKRecord) {
        guard
            let id = UUID(uuidString: record.recordID.recordName),
            let name = record["name"] as? String,
            let icon = record["icon"] as? String,
            let lastCompletedAt = record["lastCompletedAt"] as? Date,
            let category = record["category"] as? String,
            let frequencyData = record["frequency"] as? Data,
            let frequency = try? JSONDecoder().decode(Frequency.self, from: frequencyData)
        else { return nil }

        self.init(
            id: id,
            name: name,
            icon: icon,
            frequency: frequency,
            lastCompletedAt: lastCompletedAt,
            category: category,
            previousCompletedAt: record["previousCompletedAt"] as? Date,
            endsAt: record["endsAt"] as? Date
        )
    }

    func apply(to record: CKRecord) {
        record["name"] = name as CKRecordValue
        record["icon"] = icon as CKRecordValue
        record["lastCompletedAt"] = lastCompletedAt as CKRecordValue
        record["category"] = category as CKRecordValue
        if let data = try? JSONEncoder().encode(frequency) {
            record["frequency"] = data as CKRecordValue
        }
        if let prev = previousCompletedAt {
            record["previousCompletedAt"] = prev as CKRecordValue
        } else {
            record["previousCompletedAt"] = nil
        }
        if let endsAt {
            record["endsAt"] = endsAt as CKRecordValue
        } else {
            record["endsAt"] = nil
        }
    }
}

public enum CloudZone {
    public static func zoneID(for categoryName: String) -> CKRecordZone.ID {
        let slug = categoryName
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
        return CKRecordZone.ID(zoneName: "category-\(slug)", ownerName: CKCurrentUserDefaultName)
    }

    public static func categoryName(from zoneID: CKRecordZone.ID) -> String? {
        guard zoneID.zoneName.hasPrefix("category-") else { return nil }
        return String(zoneID.zoneName.dropFirst("category-".count))
    }
}
