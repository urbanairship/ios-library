/* Copyright Airship and Contributors */

import CoreData


#if canImport(AirshipCore)
import AirshipCore
#elseif canImport(AirshipKit)
import AirshipKit
#endif

class PushDataManager {

    // The number of days push payloads will be stored by default.
    private let maxAge = TimeInterval(864000) // 10 days

    private let appKey: String

    public init(appKey: String) {
        self.appKey = appKey
        self.coreData = UACoreData(
            modelURL: DebugResources.bundle().url(
                forResource: "AirshipDebugPushData",
                withExtension:"momd"
            )!,
            inMemory: false,
            stores: ["AirshipDebugPushData-\(appKey).sqlite"]
        )
        
        self.trimDatabase()
    }

    private let coreData: UACoreData

    private func trimDatabase() {
        coreData.performBlockIfStoresExist { isSafe, context in
            guard isSafe else { return }

            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = PushData.fetchRequest()

            let storageDaysInterval = Date()
                .addingTimeInterval(
                    -self.maxAge
                )
                .timeIntervalSince1970

            fetchRequest.predicate = NSPredicate(format:"time < %f", storageDaysInterval)
            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

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

            let persistedPush = PushData(entity: PushData.entity(), insertInto:context)
            persistedPush.pushID = push.pushID
            persistedPush.alert = push.alert
            persistedPush.data = push.description
            persistedPush.time = push.time
            UACoreData.safeSave(context)
        }
    }
    
    private func pushExists(id: String, context: NSManagedObjectContext) -> Bool {
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

                var pushes: [PushNotification] = []
                var pushDatas: [Any] = []
                let sort = NSSortDescriptor(key: "time", ascending: false)
                let sortDescriptors = [sort]
                let fetchRequest:NSFetchRequest = PushData.fetchRequest()
                fetchRequest.sortDescriptors = sortDescriptors
                do {
                    pushDatas = try context.fetch(fetchRequest)
                } catch {
                    if let error = error as NSError? {
                        print("ERROR: error fetching push payload list - \(error), \(error.userInfo)")
                    }
                }

                for pushData in pushDatas {
                    guard let data = pushData as? PushData, data.data != nil else {
                        continue
                    }

                    let push = PushNotification(pushData:data)
                    pushes.append(push)
                }

                continuation.resume(returning: pushes)
            }
        }
    }
}
