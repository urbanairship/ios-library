
import Testing
@_spi(AirshipInternal) import AirshipBasement

@testable
import AirshipCore
import Foundation

@Suite struct ChannelAPIClientTest {
    private let config: RuntimeConfig = .testConfig()
    private let session = TestAirshipRequestSession()
    private let client: ChannelAPIClient
    private let encoder = JSONEncoder()

    init() {
        self.client = ChannelAPIClient(
            config: self.config,
            session: self.session
        )
    }

    @Test
    func testCreate() async throws {
        let payload = ChannelRegistrationPayload()

        self.session.data = (try? AirshipJSON.wrap([
            "channel_id": "some-channel-id"
        ]).toData()) ?? Data()

        self.session.response = HTTPURLResponse(
            url: URL(string: "https://neat")!,
            statusCode: 200,
            httpVersion: "",
            headerFields: [String: String]()
        )

        let response = try await self.client.createChannel(payload: payload)
        #expect("some-channel-id" == response.result!.channelID)
        #expect(
            "https://device-api.urbanairship.com/api/channels/some-channel-id" ==
            response.result!.location.absoluteString
        )

        let request = self.session.lastRequest!
        #expect("POST" == request.method)
        #expect(AirshipRequestAuth.generatedAppToken == request.auth)
        #expect("https://device-api.urbanairship.com/api/channels/" == request.url?.absoluteString)
        #expect(try! AirshipJSON.wrap(payload) == AirshipJSON.from(data: request.body))
    }

    @Test
    func testCreateInvalidResponse() async throws {
        let payload = ChannelRegistrationPayload()

        self.session.data = (try? AirshipJSON.wrap([
            "not-right": "some-channel-id"
        ]).toData()) ?? Data()

        self.session.response = HTTPURLResponse(
            url: URL(string: "https://neat")!,
            statusCode: 200,
            httpVersion: "",
            headerFields: [String: String]()
        )

        do {
            _ = try await self.client.createChannel(payload: payload)
            Issue.record("Should throw")
        } catch {}
    }

    @Test
    func testCreateError() async throws {
        let payload = ChannelRegistrationPayload()
        self.session.error = AirshipErrors.error("Error!")
        do {
            _ = try await self.client.createChannel(payload: payload)
            Issue.record("Should throw")
        } catch {}
    }

    @Test
    func testCreateFailed() async throws {
        let payload = ChannelRegistrationPayload()
        self.session.response = HTTPURLResponse(
            url: URL(string: "https://neat")!,
            statusCode: 400,
            httpVersion: "",
            headerFields: [String: String]()
        )

        let response = try await self.client.createChannel(payload: payload)
        #expect(400 == response.statusCode)
    }

    @Test
    func testUpdate() async throws {
        let payload = ChannelRegistrationPayload()

        self.session.response = HTTPURLResponse(
            url: URL(string: "https://neat")!,
            statusCode: 200,
            httpVersion: "",
            headerFields: [String: String]()
        )

        let response = try await self.client.updateChannel(
            "some-channel-id",
            payload: payload
        )

        #expect("some-channel-id" == response.result!.channelID)
        #expect(
            "https://device-api.urbanairship.com/api/channels/some-channel-id" ==
            response.result!.location.absoluteString
        )

        let request = self.session.lastRequest!
        #expect("PUT" == request.method)

        #expect(AirshipRequestAuth.channelAuthToken(identifier: "some-channel-id") == request.auth)
        #expect(try! AirshipJSON.wrap(payload) == AirshipJSON.from(data: request.body))
        #expect("https://device-api.urbanairship.com/api/channels/some-channel-id" == request.url?.absoluteString)

    }
    @Test
    func testUpdateError() async throws {
        let payload = ChannelRegistrationPayload()
        self.session.error = AirshipErrors.error("Error!")
        do {
            _ = try await self.client.updateChannel(
                "some-channel-id",
                payload: payload
            )
            Issue.record("Should throw")
        } catch {}
    }

    @Test
    func testUpdateFailed() async throws {
        let payload = ChannelRegistrationPayload()
        self.session.response = HTTPURLResponse(
            url: URL(string: "https://neat")!,
            statusCode: 400,
            httpVersion: "",
            headerFields: [String: String]()
        )

        let response = try await self.client.updateChannel(
            "some-channel-id",
            payload: payload
        )
        #expect(400 == response.statusCode)
    }

}
