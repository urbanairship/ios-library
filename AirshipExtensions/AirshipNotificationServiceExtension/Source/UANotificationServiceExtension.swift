/* Copyright Airship and Contributors */

import UserNotifications
import UniformTypeIdentifiers

#if !TARGET_OS_TV
@objc
open class UANotificationServiceExtension: UNNotificationServiceExtension {
    private enum Const {
        static let AirshipMediaAttachment = "com.urbanairship.media_attachment"
        static let AccengageMediaAttachment = "a4sid"
        static let SupportedExtensions = ["jpg", "jpeg", "png", "gif", "aif", "aiff", "mp3", "mpg", "mpeg", "mp4", "m4a", "wav", "avi"]
    }
    
    private var loadingTasks: TaskGroup<UNNotificationAttachment?>?
    private var bestAttemptContent: UNMutableNotificationContent?
    private var deliverHandler: ((UNNotificationContent) -> Void)?
    
    open override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {

        let userInfo = request.content.userInfo
        guard
            let source = userInfo[Const.AirshipMediaAttachment] ?? userInfo[Const.AccengageMediaAttachment],
            let payloadInfo = source as? [String: Any]
        else {
            contentHandler(request.content)
            return
        }
        
        guard
            let data = try? JSONSerialization.data(withJSONObject: payloadInfo),
            let payload = try? JSONDecoder().decode(MediaAttachmentPayload.self, from: data)
        else {
            print("Unable to parse attachment: \(payloadInfo)")
            contentHandler(request.content)
            return
        }
        
        self.bestAttemptContent = request.content.mutableCopy() as? UNMutableNotificationContent
        self.deliverHandler = contentHandler
        
        Task {
            await withTaskGroup(of: UNNotificationAttachment?.self) { [weak self, loader = self.load] group in
                self?.loadingTasks = group
                var attachemnts: [UNNotificationAttachment] = []
                
                payload.media.forEach { media in
                    group.addTask {
                        return await loader(media, payload.options, payload.thumbnailID)
                    }
                }
                
                for await result in group {
                    if let result = result {
                        attachemnts.append(result)
                        self?.bestAttemptContent?.attachments = attachemnts
                    }
                }
            }
            
            if let body = payload.textContent?.body {
                self.bestAttemptContent?.body = body;
            }

            if let title = payload.textContent?.title {
                self.bestAttemptContent?.title = title;
            }

            if let subtitle = payload.textContent?.subtitle {
                self.bestAttemptContent?.subtitle = subtitle;
            }
            
            if let content = self.bestAttemptContent {
                contentHandler(content)
            }
            
            self.bestAttemptContent = nil
            self.loadingTasks = nil
            self.deliverHandler = nil
        }
    }
    
    private func load(attachment: MediaAttachmentPayload.ContentMedia, 
                      defaultOptions: MediaAttachmentPayload.PayloadOptions,
                      thumbnailID: String?
    ) async -> UNNotificationAttachment? {
        
        if Task.isCancelled { return nil }
        
        do {
            let (localURL, response) = try await download(url: attachment.url)
            
            if Task.isCancelled { return nil }
            
            var mimeType = response.mimeType
            if mimeType == nil, let httpResponse = response as? HTTPURLResponse {
                mimeType = httpResponse.allHeaderFields["Content-Type"] as? String
            }
            
            let identifier = attachment.urldID ?? ""
            let hideThumbnail = thumbnailID != nil && thumbnailID != identifier
            
            return makeAttachement(
                localURL: localURL,
                remoteURL: attachment.url,
                mimeType: mimeType,
                options: defaultOptions.generateNotificationAttachmentOptions(hideThumbnail: hideThumbnail),
                identifier: identifier)
            
        } catch {
            print("Failed to download file \(attachment.url), \(error)")
            return nil
        }
    }
    
    private func makeAttachement(localURL: URL, remoteURL: URL, mimeType: String?, options: [String: Any], identifier: String) -> UNNotificationAttachment? {
        
        guard let fileURL = try? correctFileExtension(for: localURL, original: remoteURL) else {
            print("Failed to generate notification attachment for \(localURL) \(remoteURL)")
            return nil
        }
        
        var mutableOptions = options
        
        let hasExtension = Const.SupportedExtensions.contains { item in
            return fileURL.lastPathComponent.lowercased().hasSuffix(item)
        }
        
        if !hasExtension, let hint = hintMimeType(for: fileURL, mimeType: mimeType) {
            mutableOptions[UNNotificationAttachmentOptionsTypeHintKey] = hint
        }
        
        do {
            return try UNNotificationAttachment(identifier: identifier, url: fileURL, options: mutableOptions)
        } catch {
            print("Failed to generate UNNotificationAttachment \(error), \(fileURL), \(localURL), \(remoteURL)")
            return nil
        }
    }
    
    private func hintMimeType(for file: URL, mimeType: String?) -> String? {
        if
            let type = mimeType,
            let uti = UTType(mimeType: type),
            let fileExtension = uti.preferredFilenameExtension,
            Const.SupportedExtensions.contains(fileExtension) {
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
        if #available(macOS 12.0, iOS 15.0, watchOS 8.0, *) {
            return try await URLSession.shared.download(from: url)
        } else {
            let (data, response) = try await URLSession.shared.data(from: url)
            let tmpUrl = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try data.write(to: tmpUrl)
            return (tmpUrl, response)
        }
    }
    
    open override func serviceExtensionTimeWillExpire() {
        self.loadingTasks?.cancelAll()
        
        if
            let content = self.bestAttemptContent,
            let handler = self.deliverHandler {
            
            handler(content)
        }
    }
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

public extension UNNotificationRequest {

    // Checks if the request is from Airship
    var isAirship: Bool {
        return containsAirshipMediaAttachments ||
        self.content.userInfo["com.urbanairship.metadata"] != nil ||
        self.content.userInfo["_"] != nil
    }

    /// Checks if the request is from Airship and contains media attachments
    var containsAirshipMediaAttachments: Bool {
        return self.content.userInfo["com.urbanairship.media_attachment"] != nil
    }
}

#endif


