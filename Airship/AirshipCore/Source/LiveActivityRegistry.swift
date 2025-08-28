/* Copyright Airship and Contributors */

#if canImport(ActivityKit)



@preconcurrency
import Combine

/// Registers and watches live activities
actor LiveActivityRegistry {

    private nonisolated let liveActivityUpdatesSubject = CurrentValueSubject<Void, Never>(())

    /// A stream of registry updates
    let updates: AsyncStream<LiveActivityUpdate>

    private static let maxActiveTime: TimeInterval = 8 * 60 * 60
    private static let staleTokenAge: TimeInterval = 48 * 60 * 60

    private let liveActivityKey = "LiveaActivityRegister#tracked"
    private let startTokensKey = "LiveaActivityRegister#trackedStartTokens"

    private var restoreCalled: Bool = false

    private var liveActivityInfos: [LiveActivityInfo] {
        get {
            return self.dataStore.safeCodable(forKey: liveActivityKey) ?? []
        }
        set {
            self.dataStore.setSafeCodable(newValue, forKey: liveActivityKey)
        }

    }
    
    private var startTokenInfos: [String: StartTokenInfo] {
        get {
            return self.dataStore.safeCodable(forKey: startTokensKey) ?? [:]
        }
        set {
            self.dataStore.setSafeCodable(newValue, forKey: startTokensKey)
        }
    }

    private var liveActivityTaskMap: [String: Task<Void, Never>] = [:]
    private let updatesContinuation: AsyncStream<LiveActivityUpdate>.Continuation
    private let dataStore: PreferenceDataStore
    private let date: any AirshipDateProtocol

    init(
        dataStore: PreferenceDataStore,
        date: any AirshipDateProtocol = AirshipDate.shared
    ) {
        self.date = date
        self.dataStore = dataStore
        (self.updates, self.updatesContinuation) = AsyncStream<LiveActivityUpdate>.airshipMakeStreamWithContinuation()
    }

    /// For tests
    func stop() {
        self.updatesContinuation.finish()
        self.liveActivityTaskMap.values.forEach { task in
            task.cancel()
        }
    }

    /// Should be called for all live activities right after takeOff.
    /// - Parameters:
    ///     - activities: An array of activities
    func restoreTracking(
        activities: [any LiveActivityProtocol],
        startTokenTrackers: [any LiveActivityPushToStartTrackerProtocol]
    ) {
        guard !restoreCalled else {
            AirshipLogger.error("Restore called mulitple times. Ignoring.")
            return
        }
        restoreCalled = true

        /// Track push to start tokens
        startTokenTrackers.forEach { tracker in
            Task {
                await tracker.track { token in
                    await self.updateStartToken(attributeType: tracker.attributeType, token: token)
                }
            }
        }

        // Watch activities
        activities.forEach { activity in
            findLiveActivityInfos(id: activity.id).forEach { info in
                AirshipLogger.debug(
                    "Live activity restore: \(activity.id) name: \(info.name)"
                )
                watchActivity(activity, name: info.name)
            }
        }

        clearUntrackedActivities(
            currentActivityIDs: Set(activities.map { $0.id })
        )

        clearUntrackedStartTokens(
            currentAttributeTypes: Set(startTokenTrackers.map { $0.attributeType })
        )

        resendStaleStartTokens()
    }

    func updatesProcessed(updates: [LiveActivityUpdate]) {
        let setIds = updates.compactMap { update in
            return if case .liveActivity(id: let id, name: _, startTimeMS: _) = update.source {
                id
            } else {
                nil
            }
        }

        guard !setIds.isEmpty else {
            return
        }

        var infos = liveActivityInfos
        setIds.forEach { updateId in
            let index = infos.firstIndex(where: { info in
                info.id == updateId
            })

            if let index = index {
                infos[index].status = .registered
            }
        }

        self.liveActivityInfos = infos
        liveActivityUpdatesSubject.send()
    }

    @available(iOS 16.1, *)
    public nonisolated func registrationUpdates(
        name: String?,
        id: String?
    ) -> LiveActivityRegistrationStatusUpdates {

        return LiveActivityRegistrationStatusUpdates { previous in
            var async = self.liveActivityUpdatesSubject.values.map { _ in
                return await self.findLiveActivityInfos(id: id, name: name).last?.status ?? .notTracked
            }.makeAsyncIterator()

            while !Task.isCancelled {
                let status = await async.next()
                if status != previous {
                    return status
                }
            }

            return nil
        }
    }


    /// Adds a live activity to the registry. The activity will be monitored and
    /// automatically removed after its finished.
    func addLiveActivity(
        _ liveActivity: any LiveActivityProtocol,
        name: String
    ) {
        guard liveActivity.isUpdatable else {
            return
        }

        guard findLiveActivityInfos(id: liveActivity.id, name: name).isEmpty else {
            return
        }

        findLiveActivityInfos(name: name)
            .forEach { info in
                self.removeLiveActivity(id: info.id, name: info.name)
            }

        let info = LiveActivityInfo(
            id: liveActivity.id,
            name: name,
            token: liveActivity.pushTokenString,
            startDate: self.date.now,
            status: .pending
        )

        self.liveActivityInfos.append(info)

        if info.token != nil {
            yieldLiveActivityUpdate(
                info: info,
                action: .set
            )
        }

        watchActivity(liveActivity, name: info.name)
        liveActivityUpdatesSubject.send()
    }

    private func watchActivity(
        _ liveActivity: any LiveActivityProtocol,
        name: String
    ) {
        let task: Task<Void, Never> = Task {

            /// This will wait until the activity is no longer active
            await liveActivity.track { token in
                await self.updateLiveActivityToken(id: liveActivity.id, name: name, token: token)
            }

            self.removeLiveActivity(id: liveActivity.id, name: name)
        }

        liveActivityTaskMap[makeTaskID(id: liveActivity.id, name: name)] = task
    }


    private func clearUntrackedStartTokens(currentAttributeTypes: Set<String>) {
        let shouldClear = self.startTokenInfos.values.filter { info in
            !currentAttributeTypes.contains(info.attributeType)
        }

        shouldClear.forEach { info in
            self.updateStartToken(attributeType: info.attributeType, token: nil)
        }
    }

    /// Should be called after all activities have been restored.
    private func clearUntrackedActivities(currentActivityIDs: Set<String>) {
        let shouldClear = liveActivityInfos.filter { info in
            !currentActivityIDs.contains(info.id)
        }


        shouldClear.forEach { info in
            var date = self.date.now
            let maxActiveDate = info.startDate.advanced(by: Self.maxActiveTime)

            if date > maxActiveDate {
                date = maxActiveDate
            }

            removeLiveActivity(
                id: info.id,
                name: info.name,
                date: date
            )
        }

        liveActivityUpdatesSubject.send()
    }

    private func resendStaleStartTokens() {
        self.startTokenInfos.values.filter { info in
            self.date.now.timeIntervalSince(info.sentDate) > Self.staleTokenAge
        }.forEach { info in
            yieldStartTokenUpdate(attributeType: info.attributeType, token: info.token)
        }
    }

    private func updateStartToken(attributeType: String, token: String?) {
        let existing = self.startTokenInfos[attributeType]

        guard let token = token else {
            if (existing != nil) {
                self.startTokenInfos[attributeType] = nil
                yieldStartTokenUpdate(attributeType: attributeType, token: nil)
            }
            return
        }

        guard token != existing?.token else { return }

        self.startTokenInfos[attributeType] = StartTokenInfo(
            attributeType: attributeType,
            token: token,
            sentDate: self.date.now
        )

        yieldStartTokenUpdate(attributeType: attributeType, token: token)
    }

    private func updateLiveActivityToken(id: String, name: String, token: String) {
        var tracked = self.liveActivityInfos

        for index in 0..<tracked.count {
            if tracked[index].id == id && tracked[index].name == name {
                if tracked[index].token != token {
                    tracked[index].token = token
                    yieldLiveActivityUpdate(info: tracked[index], action: .set)
                }
                break
            }
        }

        self.liveActivityInfos = tracked
    }
    
    private func removeLiveActivity(
        id: String,
        name: String,
        date: Date? = nil
    ) {
        let taskID = makeTaskID(id: id, name: name)
        liveActivityTaskMap[taskID]?.cancel()
        liveActivityTaskMap[taskID] = nil

        self.liveActivityInfos.removeAll { info in
            if info.name == name && info.id == id {
                if info.token != nil {
                    yieldLiveActivityUpdate(info: info, action: .remove, date: date)
                }
                return true
            }

            return false
        }

        liveActivityUpdatesSubject.send()
    }

    private func yieldLiveActivityUpdate(
        info: LiveActivityInfo,
        action: LiveActivityUpdate.Action,
        date: Date? = nil
    ) {
        let actionDate = date ?? self.date.now
        
        let update = LiveActivityUpdate(
            action: action,
            source: .liveActivity(id: info.id, name: info.name, startTimeMS: info.startDate.millisecondsSince1970),
            actionTimeMS: actionDate.millisecondsSince1970, 
            token: action == .set ? info.token : nil)
        
        updatesContinuation.yield(update)
    }
    
    private func yieldStartTokenUpdate(
        attributeType: String,
        token: String?
    ) {
        let update = LiveActivityUpdate(
            action: token == nil ? .remove : .set,
            source: .startToken(attributeType: attributeType),
            actionTimeMS: self.date.now.millisecondsSince1970,
            token: token
        )

        updatesContinuation.yield(update)
    }
    

    private func findLiveActivityInfos(
        id: String? = nil,
        name: String? = nil
    ) -> [LiveActivityInfo] {
        return self.liveActivityInfos.filter { info in
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

private struct LiveActivityInfo: Codable, Sendable {
    var id: String
    var name: String
    var token: String?
    var startDate: Date
    var status: LiveActivityRegistrationStatus?
}

private struct StartTokenInfo: Codable, Sendable, Equatable {
    var attributeType: String
    var token: String
    var sentDate: Date
}

#endif
