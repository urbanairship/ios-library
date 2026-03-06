/* Copyright Airship and Contributors */

import Foundation

public actor AirshipImageLoader {
    private static let retryDelay: UInt64 = 10 * 1_000_000_000
    private static let maxRetries: Int = 10
    
    private let imageProvider: (any AirshipImageProvider)?
    
    public init(
        imageProvider: (any AirshipImageProvider)? = nil
    ) {
        self.imageProvider = imageProvider
    }
    
    func load(
        url urlString: String
    ) async throws -> AirshipImageData {
        
        guard let url = URL(string: urlString) else {
            throw AirshipErrors.error("Invalid URL")
        }
        
        // Check Cache/Provider first
        if let cachedData = imageProvider?.get(url: url) {
            return cachedData
        }
        
        // Route to appropriate loading logic
        if url.isFileURL {
            return try await loadImageFromFile(url: url)
        } else {
            return try await fetchImageWithRetry(url: url)
        }
    }
    
    private func loadImageFromFile(
        url: URL
    ) async throws -> AirshipImageData {
        // Moving file I/O to a background task to avoid blocking the actor
        return try await Task.detached(priority: .userInitiated) {
            let data = try Data(contentsOf: url)
            return try AirshipImageData(data: data)
        }.value
    }
    
    private func fetchImageWithRetry(
        url: URL
    ) async throws -> AirshipImageData {
        var lastError: (any Error)?
        
        for attempt in 0..<Self.maxRetries {
            do {
                let (data, response) = try await URLSession.airshipSecureSession.data(from: url)
                
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    throw AirshipErrors.error("Invalid server response")
                }
                
                return try AirshipImageData(data: data)
            } catch {
                lastError = error
                AirshipLogger.debug("Failed to fetch image \(url) attempt \(attempt + 1)/\(Self.maxRetries): \(error)")
                
                if attempt < Self.maxRetries - 1 {
                    try await Task.sleep(nanoseconds: Self.retryDelay)
                }
            }
        }
        
        AirshipLogger.debug("Failed to fetch image \(url) after \(Self.maxRetries) attempts")
        throw lastError ?? AirshipErrors.error("Failed to fetch after \(Self.maxRetries) attempts")
    }
}
