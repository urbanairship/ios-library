/* Copyright Airship and Contributors */

import CoreData

#if canImport(AirshipCore)
import AirshipCore
#elseif canImport(AirshipKit)
import AirshipKit
#endif

final class PushDataManager: Sendable {

    private let maxAge = TimeInterval(172800)  // 2 days
    private let appKey: String
    private let coreData: UACoreData

    public init(appKey: String) {
        self.appKey = appKey
        self.coreData = UACoreData(
            name: "AirshipDebugPushData",
            modelURL: AirshipDebugResources.bundle
                .url(
                    forResource: "AirshipDebugPushData",
                    withExtension: "momd"
                )!,
            inMemory: false,
            stores: ["AirshipDebugPushData-\(appKey).sqlite"]
        )

        Task {
            await self.trimDatabase()
        }
    }

    private func trimDatabase() async {
        
        let storageDaysInterval = Date()
            .advanced(by: -self.maxAge)
            .timeIntervalSince1970

        do {
            try await coreData.perform(skipIfStoreNotCreated: true) { context in
                let fetchRequest: NSFetchRequest<any NSFetchRequestResult> = PushData.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "time < %f", storageDaysInterval)

                let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                try context.execute(batchDeleteRequest)
            }
        } catch {
            print("Failed to execute request: \(error)")
        }

    }

    public func savePushNotification(_ push: PushNotification) async {
        try? await coreData.perform { context in
            guard !self.pushExists(id: push.pushID, context: context) else {
                return
            }

            let persistedPush = PushData(
                entity: PushData.entity(),
                insertInto: context
            )
            persistedPush.pushID = push.pushID
            persistedPush.alert = push.alert
            persistedPush.data = push.description
            persistedPush.time = push.time
        }
    }

    private func pushExists(id: String, context: NSManagedObjectContext) -> Bool
    {
        let fetchRequest: NSFetchRequest = PushData.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "pushID = %@", id)
        var results: [NSManagedObject] = []
        do {
            results = try context.fetch(fetchRequest)
        } catch {
            print("error executing fetch request: \(error)")
        }
        return results.count > 0
    }

    func pushNotifications() async -> [PushNotification] {
        let result = try? await coreData.performWithResult { (context) -> [PushNotification] in
            let fetchRequest: NSFetchRequest = PushData.fetchRequest()
            fetchRequest.sortDescriptors = [
                NSSortDescriptor(key: "time", ascending: false)
            ]
            
            let result = try context.fetch(fetchRequest)
            let notifications = result.map {
                PushNotification(pushData: $0)
            }
            return notifications
        } 

        return result ?? []
    }
}
