/* Copyright Airship and Contributors */

import Testing
@testable
@_spi(AirshipInternal) import AirshipCore
import Foundation

@Suite struct ContactRemoteDataProviderDelegateTest {

    private let contact: TestContact = TestContact()
    private let client: TestRemoteDataAPIClient = TestRemoteDataAPIClient()
    private let config: RuntimeConfig = RuntimeConfig.testConfig()

    private let delegate: ContactRemoteDataProviderDelegate

    init() {
        delegate = ContactRemoteDataProviderDelegate(
            config: config,
            apiClient: client,
            contact: contact
        )
    }

    @Test
    func testIsRemoteDataInfoUpToDate() async throws {
        contact.contactIDInfo = ContactIDInfo(contactID: "some-contact-id", isStable: true, namedUserID: nil)

        let locale = Locale(identifier: "br")
        let randomValue = 1003

        let remoteDatInfo = RemoteDataInfo(
            url: try RemoteDataURLFactory.makeURL(
                config: config,
                path: "/api/remote-data-contact/ios/some-contact-id",
                locale: locale,
                randomValue: randomValue
            ),
            lastModifiedTime: "some time",
            source: .contact,
            contactID: "some-contact-id"
        )

        var isUpToDate = await self.delegate.isRemoteDataInfoUpToDate(
            remoteDatInfo,
            locale: locale,
            randomValue: randomValue
        )
        #expect(isUpToDate)

        // Different locale
        isUpToDate = await self.delegate.isRemoteDataInfoUpToDate(
            remoteDatInfo,
            locale: Locale(identifier: "en"),
            randomValue: randomValue
        )
        #expect(!(isUpToDate))

        // Different randomValue
        isUpToDate = await self.delegate.isRemoteDataInfoUpToDate(
            remoteDatInfo,
            locale: locale,
            randomValue: randomValue + 1
        )
        #expect(!(isUpToDate))

        // Different contact ID
        contact.contactIDInfo = ContactIDInfo(contactID: "some-other-contact-id", isStable: true, namedUserID: nil)
        isUpToDate = await self.delegate.isRemoteDataInfoUpToDate(
            remoteDatInfo,
            locale: locale,
            randomValue: randomValue
        )
        #expect(!(isUpToDate))

        // Unstable contact ID
        contact.contactIDInfo = ContactIDInfo(contactID: "some-contact-id", isStable: false, namedUserID: nil)
        isUpToDate = await self.delegate.isRemoteDataInfoUpToDate(
            remoteDatInfo,
            locale: locale,
            randomValue: randomValue
        )
        #expect(!(isUpToDate))
    }

    @Test
    func testFetch() async throws {
        contact.contactID = "some-contact-id"

        let locale = Locale(identifier: "br")
        let randomValue = 1003

        let remoteDatInfo = RemoteDataInfo(
            url: try RemoteDataURLFactory.makeURL(
                config: config,
                path: "/api/remote-data-contact/ios/some-contact-id",
                locale: locale,
                randomValue: randomValue
            ),
            lastModifiedTime: "some time",
            source: .contact,
            contactID: "some-contact-id"
        )

        client.lastModified = "some other time"
        client.fetchData = { url, auth, lastModified, info in
            #expect(remoteDatInfo.url == url)
            #expect(AirshipRequestAuth.contactAuthToken(identifier: "some-contact-id") == auth)
            #expect("some time" == lastModified)

            let expectedInfo = RemoteDataInfo(
                url: try RemoteDataURLFactory.makeURL(
                    config: self.config,
                    path: "/api/remote-data-contact/ios/some-contact-id",
                    locale: locale,
                    randomValue: randomValue
                ),
                lastModifiedTime: "some other time",
                source: .contact,
                contactID: "some-contact-id"
            )
            #expect(expectedInfo == info)

            return AirshipHTTPResponse(
                result: RemoteDataResult(
                    payloads: [],
                    remoteDataInfo: remoteDatInfo
                ),
                statusCode: 200,
                headers: [:]
            )
        }

        let result = try await self.delegate.fetchRemoteData(
            locale: locale,
            randomValue: randomValue,
            lastRemoteDataInfo: remoteDatInfo
        )

        #expect(result.statusCode == 200)
    }

    @Test
    func testFetchLastModifiedOutOfDate() async throws {
        contact.contactID = "some-other-contact-id"

        let locale = Locale(identifier: "br")
        let randomValue = 1003

        let remoteDatInfo = RemoteDataInfo(
            url: try RemoteDataURLFactory.makeURL(
                config: config,
                path: "/api/remote-data-contact/ios/some-contact-id",
                locale: locale,
                randomValue: randomValue
            ),
            lastModifiedTime: "some time",
            source: .contact,
            contactID: "some-contact-id"
        )

        client.fetchData = { _, _, lastModified, _ in
            #expect(lastModified == nil)
            return AirshipHTTPResponse(
                result: nil,
                statusCode: 400,
                headers: [:]
            )
        }

        let result = try await self.delegate.fetchRemoteData(
            locale: locale,
            randomValue: randomValue + 1,
            lastRemoteDataInfo: remoteDatInfo
        )

        #expect(result.statusCode == 400)
    }
}
