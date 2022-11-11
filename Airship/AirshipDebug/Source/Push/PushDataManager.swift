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

        self.trimDatabase()
    }

    private func trimDatabase() {
        coreData.performBlockIfStoresExist { isSafe, context in
            guard isSafe else { return }

            let fetchRequest: NSFetchRequest<NSFetchRequestResult> =
                PushData.fetchRequest()

            let storageDaysInterval = Date()
                .addingTimeInterval(
                    -self.maxAge
                )
                .timeIntervalSince1970

            fetchRequest.predicate = NSPredicate(
                format: "time < %f",
                storageDaysInterval
            )
            let batchDeleteRequest = NSBatchDeleteRequest(
                fetchRequest: fetchRequest
            )

            do {
                _ = try context.execute(batchDeleteRequest)
            } catch {
                print("Failed to execute request: \(error)")
            }
        }
    }

    public func savePushNotification(_ push: PushNotification) {
        coreData.safePerform { isSafe, context in
            guard isSafe,
                !self.pushExists(id: push.pushID, context: context)
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
        return await withUnsafeContinuation { continuation in
            coreData.safePerform { isSafe, context in
                guard isSafe else {
                    continuation.resume(returning: [])
                    return
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
                    continuation.resume(returning: notifications)
                } catch {
                    if let error = error as NSError? {
                        print(
                            "ERROR: error fetching push payload list - \(error), \(error.userInfo)"
                        )
                    }
                    continuation.resume(returning: [])
                }
            }
        }
    }
}
