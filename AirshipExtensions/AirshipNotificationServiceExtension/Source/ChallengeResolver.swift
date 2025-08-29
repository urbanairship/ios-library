/* Copyright Airship and Contributors */

public import Foundation

/**
 * Authentication challenge resolver class
 * @note For internal use only. :nodoc:
 */
public final class ChallengeResolver: NSObject, Sendable  {
    
    public static let shared = ChallengeResolver()
    
    @MainActor
    var resolver: ChallengeResolveClosure?
    
    private override init() {}
    
    public func resolve(
        _ challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        guard
            let resolver = await self.resolver,
            challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
            challenge.protectionSpace.serverTrust != nil
        else {
            return (.performDefaultHandling, nil)
        }
        
        return resolver(challenge)
    }
}

extension ChallengeResolver: URLSessionTaskDelegate {
    
    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {

        return await self.resolve(challenge)
    }
    
    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        return await self.resolve(challenge)
    }
    
}


public typealias ChallengeResolveClosure = @Sendable (URLAuthenticationChallenge) -> (URLSession.AuthChallengeDisposition, URLCredential?)
