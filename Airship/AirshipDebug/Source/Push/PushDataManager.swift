/* Copyright Airship and Contributors */

import CoreData

#if canImport(AirshipCore)
import AirshipCore
#elseif canImport(AirshipKit)
import AirshipKit
#endif

class PushDataManager {

    private let maxAge = TimeInterval(172800)  // 2 days
    private let appKey: String
    private let coreData: UACoreData

    public init(appKey: String) {
        self.appKey = appKey
        self.coreData = UACoreData(
            modelURL: DebugResources.bundle()
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
            .addingTimeInterval(-self.maxAge)
            .timeIntervalSince1970
        
        await coreData.performBlockIfStoresExist { isSafe, context in
            guard isSafe else { return }

            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = PushData.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "time < %f", storageDaysInterval)
            
            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

            do {
                _ = try context.execute(batchDeleteRequest)
            } catch {
                print("Failed to execute request: \(error)")
            }
        }
    }

    public func savePushNotification(_ push: PushNotification) async {
        await coreData.safePerform { [isExists = self.pushExists] isSafe, context in
            guard 
                isSafe,
                !isExists(push.pushID, context)
            else {
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
            UACoreData.safeSave(context)
        }
    }

    @Sendable
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
        return await coreData.safePerform { (isSafe, context) -> [PushNotification] in
            guard isSafe else {
                return []
            }
            
            let fetchRequest: NSFetchRequest = PushData.fetchRequest()
            fetchRequest.sortDescriptors = [
                NSSortDescriptor(key: "time", ascending: false)
            ]
            
            do {
                let result = try context.fetch(fetchRequest)
                let notifications = result.map {
                    PushNotification(pushData: $0)
                }
                return notifications
            } catch {
                if let error = error as NSError? {
                    print(
                        "ERROR: error fetching push payload list - \(error), \(error.userInfo)"
                    )
                }
                return []
            }
        } ?? []
    }
}
