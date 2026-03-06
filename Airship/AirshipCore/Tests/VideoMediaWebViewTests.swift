/* Copyright Airship and Contributors */

#if !os(tvOS) && !os(watchOS)

import Testing
@testable import AirshipCore

@Suite
struct VideoMediaWebViewTests {

    // MARK: - Standard embed URLs

    @Test
    func testExtractsIDFromStandardEmbedURL() {
        let url = "https://www.youtube.com/embed/dQw4w9WgXcQ"
        #expect(VideoMediaWebView.retrieveYoutubeVideoID(url: url) == "dQw4w9WgXcQ")
    }

    @Test
    func testExtractsIDFromEmbedURLWithQueryParams() {
        let url = "https://www.youtube.com/embed/dQw4w9WgXcQ?autoplay=1&mute=1"
        #expect(VideoMediaWebView.retrieveYoutubeVideoID(url: url) == "dQw4w9WgXcQ")
    }

    @Test
    func testExtractsIDWithHyphensAndUnderscores() {
        let url = "https://www.youtube.com/embed/a1B2-c3_D4e"
        #expect(VideoMediaWebView.retrieveYoutubeVideoID(url: url) == "a1B2-c3_D4e")
    }

    // MARK: - Edge cases

    @Test
    func testReturnsNilForNonEmbedURL() {
        let url = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
        #expect(VideoMediaWebView.retrieveYoutubeVideoID(url: url) == nil)
    }

    @Test
    func testReturnsNilForEmptyString() {
        #expect(VideoMediaWebView.retrieveYoutubeVideoID(url: "") == nil)
    }

    @Test
    func testReturnsNilForUnrelatedURL() {
        let url = "https://vimeo.com/123456789"
        #expect(VideoMediaWebView.retrieveYoutubeVideoID(url: url) == nil)
    }

    @Test
    func testReturnsNilForEmbedWithNoID() {
        let url = "https://www.youtube.com/embed/"
        #expect(VideoMediaWebView.retrieveYoutubeVideoID(url: url) == nil)
    }

    @Test
    func testExtractsIDFromEmbedWithTrailingSlash() {
        let url = "https://www.youtube.com/embed/dQw4w9WgXcQ/"
        #expect(VideoMediaWebView.retrieveYoutubeVideoID(url: url) == "dQw4w9WgXcQ")
    }

    @Test
    func testExtractsIDFromEmbedWithFragment() {
        let url = "https://www.youtube.com/embed/dQw4w9WgXcQ#t=30"
        #expect(VideoMediaWebView.retrieveYoutubeVideoID(url: url) == "dQw4w9WgXcQ")
    }

    @Test
    func testExtractsIDFromEmbedWithTrailingSlashAndQueryParams() {
        let url = "https://www.youtube.com/embed/7sxVHYZ_PnA/?autoplay=1&controls=0&loop=1&mute=1"
        #expect(VideoMediaWebView.retrieveYoutubeVideoID(url: url) == "7sxVHYZ_PnA")
    }
}

#endif
