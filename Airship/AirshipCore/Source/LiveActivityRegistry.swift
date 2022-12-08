/* Copyright Airship and Contributors */

import Foundation

/// Registers and watches live activities
actor LiveActivityRegistry {

    /// A stream of registry updates
    let updates: AsyncStream<LiveActivityUpdate>

    private let maxActiveTime: TimeInterval = 288000.0  // 8 hours

    private let trackedKey = "LiveaActivityRegister#tracked"
    private var tracked: [LiveActivityInfo] {
        get {
            var stored: [LiveActivityInfo]?
            stored = try? self.dataStore.codable(forKey: trackedKey)
            return stored ?? []
        }
        set {
            try? self.dataStore.setCodable(newValue, forKey: trackedKey)
        }
    }

    private var taskMap: [String: Task<Void, Never>] = [:]
    private let updatesContinuation:
        AsyncStream<LiveActivityUpdate>.Continuation
    private let dataStore: PreferenceDataStore
    private let date: AirshipDate

    init(
        dataStore: PreferenceDataStore,
        date: AirshipDate = AirshipDate()
    ) {
        self.date = date
        self.dataStore = dataStore
        (self.updates, self.updatesContinuation) = AsyncStream<LiveActivityUpdate>.makeStreamWithContinuation()

    }

    /// For tests
    func stop() {
        self.updatesContinuation.finish()
        self.taskMap.values.forEach { task in
            task.cancel()
        }
    }

    /// Should be called for all live activities right after takeOff.
    /// - Parameters:
    ///     - activities: An array of activities
    func restoreTracking(activities: [LiveActivity]) {
        activities.forEach { activity in
            findInfos(id: activity.id)
                .forEach { info in
                    AirshipLogger.debug(
                        "Live activity restore: \(activity.id) name: \(info.name)"
                    )
                    watchActivity(activity, name: info.name)
                }
        }
    }

    /// Should be called after all activities have been restored.
    func clearUntracked() {
        tracked.filter { info in
            taskMap[makeTaskID(id: info.id, name: info.name)] == nil
        }
        .forEach { info in
            var date = self.date.now
            let maxActiveDate = info.startDate.addingTimeInterval(maxActiveTime)

            if date > maxActiveDate {
                date = maxActiveDate
            }

            removeLiveActivity(
                id: info.id,
                name: info.name,
                date: date
            )

        }
    }

    /// Adds a live activity to the registry. The activity will be monitored and
    /// automatically removed after its finished.
    func addLiveActivity(
        _ activity: LiveActivity,
        name: String
    ) {
        guard activity.isActive else {
            return
        }

        findInfos(name: name)
            .forEach { info in
                self.removeLiveActivity(id: info.id, name: info.name)
            }

        let info = LiveActivityInfo(
            id: activity.id,
            name: name,
            token: activity.pushTokenString,
            startDate: self.date.now
        )

        self.tracked.append(info)

        if info.token != nil {
            yieldUpdate(
                info: info,
                action: .set
            )
        }

        watchActivity(activity, name: info.name)
    }

    private func watchActivity(
        _ activity: LiveActivity,
        name: String
    ) {
        let task: Task<Void, Never> = Task {

            /// This will wait until the activity is no longer active
            await activity.track { token in
                self.updateToken(id: activity.id, name: name, token: token)
            }

            self.removeLiveActivity(id: activity.id, name: name)
        }

        taskMap[makeTaskID(id: activity.id, name: name)] = task
    }

    private func updateToken(id: String, name: String, token: String) {
        var tracked = self.tracked

        for index in 0..<tracked.count {
            if tracked[index].id == id && tracked[index].name == name {
                if tracked[index].token != token {
                    tracked[index].token = token
                    yieldUpdate(info: tracked[index], action: .set)
                }
                break
            }
        }

        self.tracked = tracked
    }

    private func removeLiveActivity(
        id: String,
        name: String,
        date: Date? = nil
    ) {
        let taskID = makeTaskID(id: id, name: name)
        taskMap[taskID]?.cancel()
        taskMap[taskID] = nil

        self.tracked.removeAll { info in
            if info.name == name && info.id == id {
                if info.token != nil {
                    yieldUpdate(info: info, action: .remove, date: date)
                }
                return true
            }

            return false
        }
    }

    private func yieldUpdate(
        info: LiveActivityInfo,
        action: LiveActivityUpdate.Action,
        date: Date? = nil
    ) {
        let actionDate = date ?? self.date.now
        updatesContinuation.yield(
            LiveActivityUpdate(
                action: action,
                id: info.id,
                name: info.name,
                token: action == .set ? info.token : nil,
                actionTimeMS: actionDate.millisecondsSince1970,
                startTimeMS: info.startDate.millisecondsSince1970
            )
        )
    }

    private func findInfos(id: String? = nil, name: String? = nil)
        -> [LiveActivityInfo]
    {
        return self.tracked.filter { info in
            if id != nil && info.id != id {
                return false
            }

            if name != nil && info.name != name {
                return false
            }

            return true
        }
    }

    private func makeTaskID(id: String, name: String) -> String {
        return id + name
    }
}

private struct LiveActivityInfo: Codable {
    var id: String
    var name: String
    var token: String?
    var startDate: Date
}

extension Date {
    fileprivate var millisecondsSince1970: UInt64 {
        UInt64((self.timeIntervalSince1970 * 1000.0).rounded())
    }
}
