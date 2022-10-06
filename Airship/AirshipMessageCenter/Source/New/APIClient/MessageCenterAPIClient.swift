/* Copyright Airship and Contributors */

import Foundation
import AirshipCore

/* Copyright Airship and Contributors */

import Foundation
import AirshipCore

/// Message Center API client protocol
protocol MessageCenterAPIClientProtocol {

    /// Retrieves the full message list from the server.
    /// - Parameters:
    ///   - user: The user credentials
    ///   - channel: The channel ID
    ///   - lastModified: The last modified time
    /// - Returns: The messages, or throws an error if there was an error or the message list has not changed since the last update.
    func retrieveMessageList(
        user: MessageCenterUser,
        channelID: String,
        lastModified: String?
    ) async throws -> AirshipHTTPResponse<[MessageCenterMessage]>

    /// Performs a batch delete request on the server.
    ///  - Parameters:
    ///    - messages: An array of messages.
    ///    - user: The user credentials
    ///    - channel: The channel ID
    /// - Returns: Returns an AirshipHTTPResponse
    func performBatchDelete(
        forMessages messages: [MessageCenterMessage],
        user: MessageCenterUser,
        channelID: String
    ) async throws -> AirshipHTTPResponse<Void>

    /// Performs a batch mark-as-read request on the server.
    /// - Parameters:
    ///   - messages: An NSArray of messages be marked as read.
    ///   - user: The user credentials
    ///   - channelID: The channel ID.
    /// - Returns: Returns an AirshipHTTPResponse
    func performBatchMarkAsRead(
        forMessages messages: [MessageCenterMessage],
        user: MessageCenterUser,
        channelID: String
    ) async throws -> AirshipHTTPResponse<Void>

    /// Create a user.
    /// - Parameters:
    ///   -  channelID: The channel ID
    /// - Returns: The user credentials, or throws an error if there was an error.
    func createUser(
        withChannelID channelID: String
    ) async throws -> AirshipHTTPResponse<MessageCenterUser>

    /// Update a user.
    /// - Parameters:
    ///   -  user: The user credentials
    ///   -  channelID: The channel ID
    /// - Returns: An airship http response.
    func updateUser(
        _ user: MessageCenterUser,
        channelID: String
    ) async throws -> AirshipHTTPResponse<Void>
}

struct MessageCenterAPIClient: MessageCenterAPIClientProtocol {

    private static let channelIDHeader = "X-UA-Channel-ID"
    private static let lastModifiedIDHeader = "If-Modified-Since"
    private static let lastMessageListModifiedTime = "UALastMessageListModifiedTime.%@"

    private let config: RuntimeConfig
    private let session: AirshipRequestSession

    init(config: RuntimeConfig, session: AirshipRequestSession) {
        self.config = config
        self.session = session
    }

    func retrieveMessageList(
        user: MessageCenterUser,
        channelID: String,
        lastModified: String?
    ) async throws -> AirshipHTTPResponse<[MessageCenterMessage]> {
        guard let deviceAPIURL = config.deviceAPIURL else {
            throw AirshipErrors.error("The deviceAPIURL is nil")
        }

        let urlString = "\(deviceAPIURL)\("/api/user/")\(user.username)\("/messages/")"
        var headers: [String: String] = [
            MessageCenterAPIClient.channelIDHeader: channelID
        ]

        if let lastModified = lastModified {
            headers[MessageCenterAPIClient.lastModifiedIDHeader] = lastModified
        }

        let request = AirshipRequest(
            url: URL(string: urlString),
            headers: headers,
            method: "GET",
            auth: .basic(user.username, user.password)
        )

        AirshipLogger.trace("Request to retrieve message list: \(urlString)")

        return try await self.session.performHTTPRequest(request) { data, response in
            guard response.isSuccess else { return nil }

            let parsed: MessageListResponse = try JSONUtils.decode(data: data)
            return parsed.messages
        }
    }

    func performBatchDelete(
            forMessages messages: [MessageCenterMessage],
            user: MessageCenterUser,
            channelID: String
    ) async throws -> AirshipHTTPResponse<Void> {
        guard let deviceAPIURL = config.deviceAPIURL else {
            throw AirshipErrors.error("The deviceAPIURL is nil")
        }

        let messageReportings = messages.compactMap{ $0.messageReporting }
        guard !messageReportings.isEmpty else {
            throw AirshipErrors.error("messages list is empty")
        }

        let urlString = "\(deviceAPIURL)\("/api/user/")\(user.username)\("/messages/delete/")"

        let body = MessageRequestBody(messages: messageReportings)

        let request = AirshipRequest(
            url: URL(string: urlString),
            headers: [
                "Accept": "application/vnd.urbanairship+json; version=3;",
                "Content-Type": "application/json",
                MessageCenterAPIClient.channelIDHeader: channelID
            ],
            method: "POST",
            auth: .basic(user.username, user.password),
            body: try JSONUtils.encode(object: body)
        )

        AirshipLogger.trace("Request to perform batch delete: \(urlString)  body: \(body)")
        return try await self.session.performHTTPRequest(request)
    }

    func performBatchMarkAsRead(
        forMessages messages: [MessageCenterMessage],
        user: MessageCenterUser,
        channelID: String
    ) async throws -> AirshipHTTPResponse<Void> {

        guard let deviceAPIURL = config.deviceAPIURL else {
            throw AirshipErrors.error("The deviceAPIURL is nil")
        }

        let messageReportings = messages.compactMap{ $0.messageReporting }
        guard !messageReportings.isEmpty else {
            throw AirshipErrors.error("messages list is empty")
        }

        let urlString = "\(deviceAPIURL)\("/api/user/")\(user.username)\("/messages/unread/")"

        let headers: [String: String] = [
            "Accept": "application/vnd.urbanairship+json; version=3;",
            "Content-Type": "application/json",
            MessageCenterAPIClient.channelIDHeader: channelID
        ]

        let body = MessageRequestBody(messages: messageReportings)
        let bodyData = try JSONUtils.encode(object: body)
        let request = AirshipRequest(
            url: URL(string: urlString),
            headers: headers,
            method: "POST",
            auth: .basic(user.username, user.password),
            body: bodyData
        )

        AirshipLogger.trace("Request to perfom batch mark messages as read: \(urlString) body: \(body)")

        return try await self.session.performHTTPRequest(request)
    }

    func createUser(
        withChannelID channelID: String
    ) async throws -> AirshipHTTPResponse<MessageCenterUser> {

        guard let deviceAPIURL = config.deviceAPIURL else {
            throw AirshipErrors.error("The deviceAPIURL is nil")
        }

        let urlString = "\(deviceAPIURL)\("/api/user/")"
        let headers: [String: String] = [
            "Accept": "application/vnd.urbanairship+json; version=3;",
            "Content-Type": "application/json",
            MessageCenterAPIClient.channelIDHeader: channelID
        ]

        let body = CreateUserRequestBody(iOSChannels: [channelID])
        let request = AirshipRequest(
            url: URL(string: urlString),
            headers: headers,
            method: "POST",
            auth: .basic(config.appKey, config.appSecret),
            body: try JSONUtils.encode(object: body)
        )

        AirshipLogger.trace("Request to perfom batch create user: \(urlString) body: \(body)")

        return try await self.session.performHTTPRequest(request) { data, response in
            guard response.isSuccess else { return nil }

            let response: MessageCenterUser = try JSONUtils.decode(data: data)
            return response
        }
    }

    func updateUser(
        _ user: MessageCenterUser,
        channelID: String
    ) async throws -> AirshipHTTPResponse<Void> {

        guard let deviceAPIURL = config.deviceAPIURL else {
            throw AirshipErrors.error("The deviceAPIURL is nil")
        }

        let urlString = "\(deviceAPIURL)\("/api/user/")\(user.username)"
        let headers: [String: String] = [
            "Accept": "application/vnd.urbanairship+json; version=3;",
            "Content-Type": "application/json"
        ]

        let body = UpdateUserRequestBody(
            iOSChannels: UpdateUserRequestBody.UserOperation(
                add: [channelID]
            )
        )

        let bodyData = try JSONUtils.encode(object: body)
        let request = AirshipRequest(
            url: URL(string: urlString),
            headers: headers,
            method: "POST",
            auth: .basic(config.appKey, config.appSecret),
            body: bodyData
        )
        AirshipLogger.trace("Request to perfom batch update user: \(urlString) body: \(body)")

        return try await self.session.performHTTPRequest(request)
    }
}


fileprivate struct MessageRequestBody: Encodable {
    let messages: [AirshipJSON]
}

fileprivate struct UpdateUserRequestBody: Encodable {
    var iOSChannels: UserOperation

    private enum CodingKeys: String, CodingKey {
        case iOSChannels = "ios_channels"
    }

    fileprivate struct UserOperation: Encodable {
        var add: [String]
    }
}

fileprivate struct CreateUserRequestBody: Encodable {
    var iOSChannels: [String]

    private enum CodingKeys: String, CodingKey {
        case iOSChannels = "ios_channels"
    }
}

fileprivate struct MessageListResponse: Decodable {
    let messages: [MessageCenterMessage]
}

extension HTTPURLResponse {
    var isSuccess: Bool {
        return self.statusCode >= 200 && self.statusCode <= 299
    }
}
