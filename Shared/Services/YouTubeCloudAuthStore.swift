import CloudKit
import Foundation

enum YouTubeCloudAuthStore {
    private static let containerIdentifier = "iCloud.com.janchalupa.YouTube"
    private static let recordType = "YouTubeAuthState"
    private static let recordName = "current"
    private static let cookiesKey = "cookies"
    private static let updatedAtKey = "updatedAt"

    static func save(cookies: String) async {
        guard !cookies.isEmpty else {
            await delete()
            return
        }

        do {
            let database = CKContainer(identifier: containerIdentifier).privateCloudDatabase
            let recordID = CKRecord.ID(recordName: recordName)
            let record: CKRecord

            do {
                record = try await database.record(for: recordID)
            } catch let error as CKError where error.code == .unknownItem {
                record = CKRecord(recordType: recordType, recordID: recordID)
            }

            record[cookiesKey] = cookies as CKRecordValue
            record[updatedAtKey] = Date() as CKRecordValue
            _ = try await database.save(record)
        } catch {
            print("YouTubeCloudAuthStore: save failed: \(error.localizedDescription)")
        }
    }

    static func loadCookies() async -> String? {
        do {
            let database = CKContainer(identifier: containerIdentifier).privateCloudDatabase
            let recordID = CKRecord.ID(recordName: recordName)
            let record = try await database.record(for: recordID)
            return record[cookiesKey] as? String
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        } catch {
            print("YouTubeCloudAuthStore: load failed: \(error.localizedDescription)")
            return nil
        }
    }

    static func delete() async {
        do {
            let database = CKContainer(identifier: containerIdentifier).privateCloudDatabase
            let recordID = CKRecord.ID(recordName: recordName)
            _ = try await database.deleteRecord(withID: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            return
        } catch {
            print("YouTubeCloudAuthStore: delete failed: \(error.localizedDescription)")
        }
    }
}
