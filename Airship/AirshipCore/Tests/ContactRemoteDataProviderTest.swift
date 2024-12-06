/* Copyright Airship and Contributors */

import XCTest
@testable
import AirshipCore

final class ContactRemoteDataProviderDelegateTest: XCTestCase {

    private let contact: TestContact = TestContact()
    private let client: TestRemoteDataAPIClient = TestRemoteDataAPIClient()
    private let config: RuntimeConfig = RuntimeConfig.testConfig()

    private var delegate: ContactRemoteDataProviderDelegate!

    override func setUpWithError() throws {
        delegate = ContactRemoteDataProviderDelegate(
            config: config,
            apiClient: client,
            contact: contact
        )
    }

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
        XCTAssertTrue(isUpToDate)

        // Different locale
        isUpToDate = await self.delegate.isRemoteDataInfoUpToDate(
            remoteDatInfo,
            locale: Locale(identifier: "en"),
            randomValue: randomValue
        )
        XCTAssertFalse(isUpToDate)

        // Different randomValue
        isUpToDate = await self.delegate.isRemoteDataInfoUpToDate(
            remoteDatInfo,
            locale: locale,
            randomValue: randomValue + 1
        )
        XCTAssertFalse(isUpToDate)

        // Different contact ID
        contact.contactIDInfo = ContactIDInfo(contactID: "some-other-contact-id", isStable: true, namedUserID: nil)
        isUpToDate = await self.delegate.isRemoteDataInfoUpToDate(
            remoteDatInfo,
            locale: locale,
            randomValue: randomValue
        )
        XCTAssertFalse(isUpToDate)

        // Unstable contact ID
        contact.contactIDInfo = ContactIDInfo(contactID: "some-contact-id", isStable: false, namedUserID: nil)
        isUpToDate = await self.delegate.isRemoteDataInfoUpToDate(
            remoteDatInfo,
            locale: locale,
            randomValue: randomValue
        )
        XCTAssertFalse(isUpToDate)
    }

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
            XCTAssertEqual(remoteDatInfo.url, url)
            XCTAssertEqual(AirshipRequestAuth.contactAuthToken(identifier: "some-contact-id"), auth)
            XCTAssertEqual("some time", lastModified)

            XCTAssertEqual(
                RemoteDataInfo(
                    url: try RemoteDataURLFactory.makeURL(
                        config: self.config,
                        path: "/api/remote-data-contact/ios/some-contact-id",
                        locale: locale,
                        randomValue: randomValue
                    ),
                    lastModifiedTime: "some other time",
                    source: .contact,
                    contactID: "some-contact-id"
                ),
                info
            )

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

        XCTAssertEqual(result.statusCode, 200)
    }

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
            XCTAssertNil(lastModified)
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

        XCTAssertEqual(result.statusCode, 400)
    }
}
