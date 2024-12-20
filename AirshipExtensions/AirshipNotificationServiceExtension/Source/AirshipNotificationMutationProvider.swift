import UniformTypeIdentifiers

@preconcurrency
import UserNotifications

final class AirshipNotificationMutationProvider: Sendable {
    static let supportedExtensions = ["jpg", "jpeg", "png", "gif", "aif", "aiff", "mp3", "mpg", "mpeg", "mp4", "m4a", "wav", "avi"]

    func mutations(for args: MediaAttachmentPayload) async throws -> AirshipNotificationMutations? {
        let attachments = try await withThrowingTaskGroup(of: AirshipAttachment?.self) { [weak self, args] group in
            try Task.checkCancellation()

            var attachments: [AirshipAttachment] = []

            args.media.forEach { media in
                group.addTask { [weak self] in
                    try Task.checkCancellation()
                    return try await self?.load(
                        attachment: media,
                        defaultOptions: args.options,
                        thumbnailID: args.thumbnailID
                    )
                }
            }

            for try await result in group {
                try Task.checkCancellation()

                if let result = result {
                    attachments.append(result)
                }
            }

            return attachments
        }

        return AirshipNotificationMutations(
            title: args.textContent?.title,
            subtitle: args.textContent?.subtitle,
            body: args.textContent?.body,
            attachments: attachments
        )
    }

    private func load(
        attachment: MediaAttachmentPayload.ContentMedia,
        defaultOptions: MediaAttachmentPayload.PayloadOptions,
        thumbnailID: String?
    ) async throws -> AirshipAttachment {

        try Task.checkCancellation()

        let (localURL, response) = try await download(url: attachment.url)

        try Task.checkCancellation()

        var mimeType = response.mimeType
        if mimeType == nil, let httpResponse = response as? HTTPURLResponse {
            mimeType = httpResponse.allHeaderFields["Content-Type"] as? String
        }

        let identifier = attachment.urldID ?? ""
        let hideThumbnail = thumbnailID != nil && thumbnailID != identifier

        return try makeAttachement(
            localURL: localURL,
            remoteURL: attachment.url,
            mimeType: mimeType,
            options: defaultOptions.generateNotificationAttachmentOptions(hideThumbnail: hideThumbnail),
            identifier: identifier
        )
    }

    private func makeAttachement(
        localURL: URL,
        remoteURL: URL,
        mimeType: String?,
        options: [String: any Sendable],
        identifier: String
    ) throws -> AirshipAttachment {
        let fileURL = try correctFileExtension(for: localURL, original: remoteURL)

        var mutableOptions = options

        let hasExtension = Self.supportedExtensions.contains { item in
            return fileURL.lastPathComponent.lowercased().hasSuffix(item)
        }

        if !hasExtension, let hint = hintMimeType(for: fileURL, mimeType: mimeType) {
            mutableOptions[UNNotificationAttachmentOptionsTypeHintKey] = hint
        }

        return AirshipAttachment(identifier: identifier, url: fileURL, options: mutableOptions)
    }

    private func hintMimeType(for file: URL, mimeType: String?) -> String? {
        if
            let type = mimeType,
            let uti = UTType(mimeType: type),
            let fileExtension = uti.preferredFilenameExtension,
            Self.supportedExtensions.contains(fileExtension) {
            return uti.identifier
        }

        if let data = try? Data(contentsOf: file, options: .mappedRead) {
            return FileHeader.supportedHeaders.first(where: { $0.matches(data: data) })?.type
        }

        return nil
    }

    private func correctFileExtension(for localURL: URL, original: URL) throws -> URL {
        let destination = URL(fileURLWithPath: localURL.path.appending("-\(original.lastPathComponent)"))

        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }

        try FileManager.default.moveItem(at: localURL, to: destination)
        return destination
    }

    private func download(url: URL) async throws -> (URL, URLResponse) {
        let session = URLSession(
            configuration: .default,
            delegate: ChallengeResolver.shared,
            delegateQueue: nil)

        return try await session.download(from: url)
    }

    private struct FileHeader {
        let type: String
        let offset: Int
        let headers: [[UInt8]]

        func matches(data: Data) -> Bool {
            var result = false
            for expectedHeader in headers {
                if data.count < offset + expectedHeader.count { continue }

                var currentHeader = [UInt8](repeating: 0, count: expectedHeader.count)
                data.copyBytes(to: &currentHeader, from: offset..<(offset + expectedHeader.count))

                if currentHeader == expectedHeader {
                    result = true
                    break
                }
            }

            return result
        }

        static let supportedHeaders = [
            FileHeader(type: "public.jpeg", offset: 0, headers: [
                [0xFF, 0xD8, 0xFF, 0xE0],
                [0xFF, 0xD8, 0xFF, 0xE2],
                [0xFF, 0xD8, 0xFF, 0xE3]
            ]),
            FileHeader(type: "public.png", offset: 0, headers: [[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]]),
            FileHeader(type: "com.compuserve.gif", offset: 0, headers: [[0x47, 0x49, 0x46, 0x38]]),
            FileHeader(type: "public.aiff-audio", offset: 0, headers: [[0x46, 0x4F, 0x52, 0x4D, 0x00]]),
            FileHeader(type: "com.microsoft.waveform-audio", offset: 8, headers: [[0x57, 0x41, 0x56, 0x45]]),
            FileHeader(type: "public.avi", offset: 8, headers: [[0x41, 0x56, 0x49, 0x20]]),
            FileHeader(type: "public.mp3", offset: 0, headers: [[0x49, 0x44, 0x33]]),
            FileHeader(type: "public.mpeg-4", offset: 4, headers: [
                [0x66, 0x74, 0x79, 0x70, 0x6D, 0x70, 0x34, 0x31],
                [0x66, 0x74, 0x79, 0x70, 0x6D, 0x70, 0x34, 0x32],
                [0x66, 0x74, 0x79, 0x70, 0x6D, 0x6D, 0x70, 0x34],
                [0x66, 0x74, 0x79, 0x70, 0x69, 0x73, 0x6f, 0x6d]
            ]),
            FileHeader(type: "public.mpeg-4-audio", offset: 4, headers: [[0x66, 0x74, 0x79, 0x70, 0x4D, 0x34, 0x41, 0x20]]),
            FileHeader(type: "public.mpeg", offset: 0, headers: [
                [0x00, 0x00, 0x01, 0xBA],
                [0x00, 0x00, 0x01, 0xB3]
            ])
        ]
    }
}

struct AirshipNotificationMutations: Sendable {
    var title: String?
    var subtitle: String?
    var body: String?
    var attachments: [AirshipAttachment]

    func apply(to notificationContent: UNMutableNotificationContent) throws {
        try attachments
            .map { try $0.notificationAttachment }
            .forEach { notificationContent.attachments.append($0) }

        if let title = title {
            notificationContent.title = title
        }
        
        if let subtitle = subtitle {
            notificationContent.subtitle = subtitle
        }
        
        if let body = body {
            notificationContent.body = body
        }
    }
}


struct AirshipAttachment: Sendable {
    var identifier: String
    var url: URL
    var options: [String : any Sendable]

    var notificationAttachment: UNNotificationAttachment {
        get throws {
            try UNNotificationAttachment(
                identifier: self.identifier,
                url: self.url,
                options: self.options
            )
        }
    }
}
