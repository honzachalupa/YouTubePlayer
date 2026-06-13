import XCTest
import YouTubeKit
@testable import iOS

final class NativePlaybackSupportTests: XCTestCase {
    func testResolvedCountryCodeFallsBackWhenLocaleHasNoRegion() {
        let resolved = NativePlaybackSupport.resolvedCountryCode(
            selectedLocaleCountryCode: "en",
            languageCode: "en",
            fallbackRegionCode: "CZ"
        )

        XCTAssertEqual(resolved, "CZ")
    }

    func testVideoInfosHeadersUseAndroidClientAndVisitorDataHeader() {
        let headers = NativePlaybackSupport.makeVideoInfosHeaders(
            languageCode: "cs",
            countryCode: "CZ"
        )

        XCTAssertEqual(headers.url.absoluteString, "https://www.youtube.com/youtubei/v1/player")
        XCTAssertEqual(headers.method, .POST)
        XCTAssertEqual(headers.customHeaders?["X-Goog-Visitor-Id"], .visitorData)
        XCTAssertTrue(headers.headers.contains(where: { $0.name == "X-Youtube-Client-Name" && $0.content == "3" }))
        XCTAssertTrue(headers.headers.contains(where: { $0.name == "X-Youtube-Client-Version" && $0.content == NativePlaybackSupport.androidClientVersion }))

        let request = HeadersList.setHeadersAgentFor(
            content: headers,
            data: [
                .query: "video123",
                .visitorData: "visitor-token"
            ]
        )

        let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""

        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Goog-Visitor-Id"), "visitor-token")
        XCTAssertTrue(body.contains(#""clientName":"ANDROID""#))
        XCTAssertTrue(body.contains(#""clientVersion":"21.24.37""#))
        XCTAssertTrue(body.contains(#""gl":"CZ""#))
        XCTAssertTrue(body.contains(#""hl":"cs""#))
        XCTAssertTrue(body.contains(#""videoId":"video123""#))
    }

    func testPreferredMuxedStreamingURLPrefersHighestAVC1MP4() {
        let lower = VideoDownloadFormat(
            mimeType: "video/mp4",
            codec: "avc1",
            url: URL(string: "https://example.com/360.mp4"),
            height: 360
        )
        let higher = VideoDownloadFormat(
            mimeType: "video/mp4",
            codec: "avc1",
            url: URL(string: "https://example.com/720.mp4"),
            height: 720
        )
        let unsupported = VideoDownloadFormat(
            mimeType: "video/webm",
            codec: "vp9",
            url: URL(string: "https://example.com/720.webm"),
            height: 1080
        )

        let selectedURL = NativePlaybackSupport.preferredMuxedStreamingURL(
            from: [unsupported, lower, higher]
        )

        XCTAssertEqual(selectedURL?.absoluteString, "https://example.com/720.mp4")
    }

    func testPreferredMuxedStreamingURLRejectsNonPlayableFormats() {
        let nonHTTP = VideoDownloadFormat(
            mimeType: "video/mp4",
            codec: "avc1",
            url: URL(string: "file:///local.mp4"),
            height: 720
        )
        let wrongCodec = VideoDownloadFormat(
            mimeType: "video/mp4",
            codec: "av01",
            url: URL(string: "https://example.com/video.mp4"),
            height: 720
        )

        XCTAssertNil(NativePlaybackSupport.preferredMuxedStreamingURL(from: [nonHTTP, wrongCodec]))
    }

    func testStreamingURLPrefersHLSBeforeMuxedFallback() {
        let hls = URL(string: "https://example.com/master.m3u8")!
        let muxed = VideoDownloadFormat(
            mimeType: "video/mp4",
            codec: "avc1",
            url: URL(string: "https://example.com/video.mp4"),
            height: 360
        )

        let response = VideoInfosResponse(
            streamingURL: hls,
            defaultFormats: [muxed]
        )

        XCTAssertEqual(NativePlaybackSupport.streamingURL(from: response), hls)
    }

    func testStreamingURLFallsBackToMuxedMP4() {
        let muxedURL = URL(string: "https://example.com/video.mp4")!
        let muxed = VideoDownloadFormat(
            mimeType: "video/mp4",
            codec: "avc1",
            url: muxedURL,
            height: 360
        )

        let response = VideoInfosResponse(
            streamingURL: nil,
            defaultFormats: [muxed]
        )

        XCTAssertEqual(NativePlaybackSupport.streamingURL(from: response), muxedURL)
    }

    func testFallbackStreamingURLPrefersNestedVideoInfosStream() {
        let hls = URL(string: "https://example.com/master.m3u8")!
        let fallback = VideoDownloadFormat(
            mimeType: "video/mp4",
            codec: "avc1",
            url: URL(string: "https://example.com/video.mp4"),
            height: 360
        )

        var response = try! VideoInfosWithDownloadFormatsResponse.decodeJSON(
            json: JSON(
                parseJSON: #"{"playabilityStatus":{"status":"OK"},"videoDetails":{"videoId":"abc123"},"streamingData":{"hlsManifestUrl":"https://example.com/master.m3u8"}}"#
            )
        )
        response.defaultFormats = [fallback]

        XCTAssertEqual(NativePlaybackSupport.fallbackStreamingURL(from: response), hls)
    }

    func testExtractInitialPlayerResponseJSONHandlesNestedJSONAndEscapedBraces() {
        let html = """
        <html><body><script>
        var ytInitialPlayerResponse = {"videoDetails":{"title":"Example } title"},"streamingData":{"formats":[{"url":"https://example.com/video.mp4"}]}}
        ;</script></body></html>
        """

        let json = NativePlaybackSupport.extractInitialPlayerResponseJSON(from: html)

        XCTAssertEqual(
            json,
            #"{"videoDetails":{"title":"Example } title"},"streamingData":{"formats":[{"url":"https://example.com/video.mp4"}]}}"#
        )
    }

    func testExtractInitialPlayerResponseJSONReturnsNilWithoutMarker() {
        XCTAssertNil(NativePlaybackSupport.extractInitialPlayerResponseJSON(from: "<html></html>"))
    }

    func testCurrentWatchHTMLShapeBreaksLibraryPlayerPathRegexButNotOurJSONExtractor() {
        let html = #"""
        <link rel="preload" href="https://i.ytimg.com/generate_204" as="fetch"><link rel="preconnect" href="https://www.youtube.com"><link rel="dns-prefetch" href="https://www.youtube.com"><link as="script" rel="preload" href="/s/player/445213fb/player_ias.vflset/en_US/base.js">
        <script>var ytInitialPlayerResponse = {"videoDetails":{"videoId":"abc123","title":"Test"},"playabilityStatus":{"status":"OK"},"streamingData":{"formats":[{"itag":18,"mimeType":"video/mp4; codecs=\"avc1.42001E, mp4a.40.2\"","url":"https://example.com/video.mp4"}]}};</script><div id="player"></div>
        """#

        let libraryPlayerPath = html.ytkFirstGroupMatch(
            for: #"<link rel=\"preload\" href=\"https:\\/\\/i.ytimg.com\\/generate_204\" as=\"fetch\"><link as=\"script\" rel=\"preload\" href=\"([\S]+)\""#
        )

        XCTAssertNil(libraryPlayerPath)
        XCTAssertNotNil(NativePlaybackSupport.extractInitialPlayerResponseJSON(from: html))
    }
}
