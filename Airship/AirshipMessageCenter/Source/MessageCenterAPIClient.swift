/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Message Center API client protocol
protocol MessageCenterAPIClientProtocol: Sendable {

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
    ///   - messages: An Array of messages be marked as read.
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

struct MessageCenterAPIClient: MessageCenterAPIClientProtocol, Sendable {

    private static let channelIDHeader = "X-UA-Channel-ID"
    private static let lastModifiedIDHeader = "If-Modified-Since"

    private let config: RuntimeConfig
    private let session: any AirshipRequestSession

    init(config: RuntimeConfig, session: any AirshipRequestSession) {
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

        let urlString =
            "\(deviceAPIURL)\("/api/user/")\(user.username)\("/messages/")"
        var headers: [String: String] = [
            MessageCenterAPIClient.channelIDHeader: channelID,
            "Accept": "application/vnd.urbanairship+json; version=3;"
        ]

        if let lastModified = lastModified {
            headers[MessageCenterAPIClient.lastModifiedIDHeader] = lastModified
        }

        let request = AirshipRequest(
            url: URL(string: urlString),
            headers: headers,
            method: "GET",
            auth: .basic(username: user.username, password: user.password)
        )

        AirshipLogger.trace("Request to retrieve message list: \(urlString)")

        return try await self.session.performHTTPRequest(request) { data, response in
            guard response.isSuccess else { return nil }

            let json = try AirshipJSON.from(data: data)
            AirshipLogger.error("Message Center Response: \(try! json.toString())")
            let parsed: MessageListResponse = try AirshipJSONUtils.decode(data: data)
            return try parsed.convertMessages()
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

        let messageReportings = messages.compactMap { message in
            message.messageReporting
        }

        guard !messageReportings.isEmpty else {
            throw AirshipErrors.error("No reporting")
        }

        let urlString =
            "\(deviceAPIURL)\("/api/user/")\(user.username)\("/messages/delete/")"

        let body = UpdateMessagseRequestBody(messages: messageReportings)

        let request = AirshipRequest(
            url: URL(string: urlString),
            headers: [
                "Accept": "application/vnd.urbanairship+json; version=3;",
                "Content-Type": "application/json",
                MessageCenterAPIClient.channelIDHeader: channelID,
            ],
            method: "POST",
            auth: .basic(username: user.username, password: user.password),
            body: try AirshipJSONUtils.encode(object: body)
        )

        AirshipLogger.trace(
            "Request to perform batch delete: \(urlString)  body: \(body)"
        )
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

        let messageReportings = messages.compactMap { message in
            message.messageReporting
        }

        guard !messageReportings.isEmpty else {
            throw AirshipErrors.error("No reporting")
        }

        let urlString =
            "\(deviceAPIURL)\("/api/user/")\(user.username)\("/messages/unread/")"

        let headers: [String: String] = [
            "Accept": "application/vnd.urbanairship+json; version=3;",
            "Content-Type": "application/json",
            MessageCenterAPIClient.channelIDHeader: channelID,
        ]

        let body = UpdateMessagseRequestBody(messages: messageReportings)
        let request = AirshipRequest(
            url: URL(string: urlString),
            headers: headers,
            method: "POST",
            auth: .basic(username: user.username, password: user.password),
            body: try AirshipJSONUtils.encode(object: body)
        )

        AirshipLogger.trace(
            "Request to perfom batch mark messages as read: \(urlString) body: \(body)"
        )

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
            MessageCenterAPIClient.channelIDHeader: channelID,
        ]

        let body = CreateUserRequestBody(iOSChannels: [channelID])
        let request = AirshipRequest(
            url: URL(string: urlString),
            headers: headers,
            method: "POST",
            auth: .channelAuthToken(identifier: channelID),
            body: try AirshipJSONUtils.encode(object: body)
        )

        AirshipLogger.trace(
            "Request to perfom batch create user: \(urlString) body: \(body)"
        )

        return try await self.session.performHTTPRequest(request) {
            data,
            response in
            guard response.isSuccess else { return nil }

            let response: MessageCenterUser = try AirshipJSONUtils.decode(data: data)
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
            "Content-Type": "application/json",
        ]

        let body = UpdateUserRequestBody(
            iOSChannels: UpdateUserRequestBody.UserOperation(
                add: [channelID]
            )
        )

        let bodyData = try AirshipJSONUtils.encode(object: body)
        let request = AirshipRequest(
            url: URL(string: urlString),
            headers: headers,
            method: "POST",
            auth: .basic(username: user.username, password: user.password),
            body: bodyData
        )
        AirshipLogger.trace(
            "Request to perfom batch update user: \(urlString) body: \(body)"
        )

        return try await self.session.performHTTPRequest(request)
    }
}

private struct UpdateMessagseRequestBody: Encodable {
    let messages: [AirshipJSON]
}

private struct UpdateUserRequestBody: Encodable {
    var iOSChannels: UserOperation

    private enum CodingKeys: String, CodingKey {
        case iOSChannels = "ios_channels"
    }

    fileprivate struct UserOperation: Encodable {
        var add: [String]
    }
}

private struct CreateUserRequestBody: Encodable {
    var iOSChannels: [String]

    private enum CodingKeys: String, CodingKey {
        case iOSChannels = "ios_channels"
    }
}

private struct MessageListResponse: Decodable {
    let messages: [Message]

    struct Message: Codable {
        let messageID: String
        let messageBodyURL: URL
        let messageReporting: AirshipJSON
        let messageURL: URL
        let contentType: String
        /// String instead of Date because they might be nonstandard ISO dates
        let messageSent: String
        let messageExpiration: String?
        let title: String
        let extra: AirshipJSON?
        let icons: AirshipJSON?
        let unread: Bool

        private enum CodingKeys: String, CodingKey {
            case messageID = "message_id"
            case title = "title"
            case contentType = "content_type"
            case messageBodyURL = "message_body_url"
            case messageURL = "message_url"
            case unread = "unread"
            case messageSent = "message_sent"
            case messageExpiration = "message_expiry"
            case extra = "extra"
            case icons = "icons"
            case messageReporting = "message_reporting"
        }
    }
}

extension MessageListResponse {
    fileprivate func convertMessages() throws -> [MessageCenterMessage] {
        return try self.messages.map { responseMessage in
            let rawJSONData = try AirshipJSONUtils.encode(object: responseMessage)
            let rawJSON = try JSONSerialization.jsonObject(with: rawJSONData)
            return MessageCenterMessage(
                title: responseMessage.title,
                id: responseMessage.messageID,
                extra: responseMessage.extra?.unWrap() as? [String: String]
                    ?? [:],
                bodyURL: responseMessage.messageBodyURL,
                expirationDate: try responseMessage.messageExpiration?.toDate(),
                messageReporting: responseMessage.messageReporting.unWrap()
                    as? [String: AnyHashable] ?? [:],
                unread: responseMessage.unread,
                sentDate: try responseMessage.messageSent.toDate(),
                messageURL: responseMessage.messageURL,
                rawMessageObject: rawJSON as? [String: AnyHashable] ?? [:]
            )
        }
    }
}

extension HTTPURLResponse {
    fileprivate var isSuccess: Bool {
        return self.statusCode >= 200 && self.statusCode <= 299
    }
}

extension String {
    fileprivate func toDate() throws -> Date {
        guard let date = AirshipDateFormatter.date(fromISOString: self) else {
            throw AirshipErrors.error("Invalid date \(self)")
        }
        return date
    }
}
