/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipCore

final class ChallengeResolverTest: XCTestCase {
    
    @MainActor
    override func tearDown() async throws {
        ChallengeResolver.shared.resolver = nil
    }
    
    func testResolverReturnsDefaultIfNotConfigured() async {
        await assertResolve(disposition: .performDefaultHandling, credentials: nil)
    }
    
    @MainActor
    func testResolverClosure() async {
        let credentials = URLCredential()
        ChallengeResolver.shared.resolver = { _ in
            return (URLSession.AuthChallengeDisposition.cancelAuthenticationChallenge, credentials)
        }
        
        let challenge = URLAuthenticationChallenge(
            protectionSpace: AirshipProtectionSpace(
                host: "urbanairship.com",
                port: 443,
                protocol: "https",
                realm: nil,
                authenticationMethod: NSURLAuthenticationMethodServerTrust),
            proposedCredential: nil,
            previousFailureCount: 0,
            failureResponse: nil,
            error: nil,
            sender: ChallengeSender())
        
        await assertResolve(
            disposition: .cancelAuthenticationChallenge,
            credentials: credentials,
            challenge: challenge
        )
    }
    
    @MainActor
    func testResolverClosureNotCalledOnNonServerTrust() async {
        let credentials = URLCredential()
        ChallengeResolver.shared.resolver = { _ in
            return (URLSession.AuthChallengeDisposition.cancelAuthenticationChallenge, credentials)
        }
        
        let challenge = URLAuthenticationChallenge(
            protectionSpace: AirshipProtectionSpace(
                host: "urbanairship.com",
                port: 443,
                protocol: "https",
                realm: nil,
                authenticationMethod: NSURLAuthenticationMethodClientCertificate),
            proposedCredential: nil,
            previousFailureCount: 0,
            failureResponse: nil,
            error: nil,
            sender: ChallengeSender())
        
        await assertResolve(
            disposition: .performDefaultHandling,
            credentials: nil,
            challenge: challenge
        )
    }
    
    @MainActor
    func testResolverClosureNotCalledOnNoPublicKey() async {
        let credentials = URLCredential()
        ChallengeResolver.shared.resolver = { _ in
            return (URLSession.AuthChallengeDisposition.cancelAuthenticationChallenge, credentials)
        }
        
        let protectionSpace = AirshipProtectionSpace(
            host: "urbanairship.com",
            port: 443,
            protocol: "https",
            realm: nil,
            authenticationMethod: NSURLAuthenticationMethodServerTrust)
        protectionSpace.useAirshipCert = false
        
        let challenge = URLAuthenticationChallenge(
            protectionSpace: protectionSpace,
            proposedCredential: nil,
            previousFailureCount: 0,
            failureResponse: nil,
            error: nil,
            sender: ChallengeSender())
        
        await assertResolve(
            disposition: .performDefaultHandling,
            credentials: nil,
            challenge: challenge
        )
    }
    
    private func assertResolve(
        disposition: URLSession.AuthChallengeDisposition,
        credentials: URLCredential? = nil,
        challenge: URLAuthenticationChallenge? = nil
    ) async {
        let actual = await ChallengeResolver.shared.resolve(challenge ?? URLAuthenticationChallenge())
        
        XCTAssertEqual(disposition, actual.0)
        XCTAssertEqual(credentials, actual.1)
    }
}

private class ChallengeSender: NSObject, URLAuthenticationChallengeSender {
    func use(_ credential: URLCredential, for challenge: URLAuthenticationChallenge) { }
    
    func continueWithoutCredential(for challenge: URLAuthenticationChallenge) { }
    
    func cancel(_ challenge: URLAuthenticationChallenge) { }
}

private class AirshipProtectionSpace: URLProtectionSpace {
    var useAirshipCert: Bool = true
    
    private func airshipCert() -> SecTrust? {
        guard
            let certFilePath = Bundle(for: type(of: self)).path(forResource: "airship", ofType: "der"),
            let data = NSData(contentsOfFile: certFilePath),
            let cert = SecCertificateCreateWithData(nil, data)
        else {
            return nil
        }
        
        var trust: SecTrust?
        SecTrustCreateWithCertificates(cert, SecPolicyCreateBasicX509(), &trust)
        return trust
    }
    
    override var serverTrust: SecTrust? {
        return useAirshipCert ? airshipCert() : nil
    }
}
