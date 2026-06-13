import XCTest
import YouTubeKit
@testable import iOS

final class LivePlaybackSmokeTests: XCTestCase {
    private var smokeVideoID: String {
        ProcessInfo.processInfo.environment["YOUTUBEKIT_SMOKE_VIDEO_ID"] ?? "dQw4w9WgXcQ"
    }

    private func requireLiveTests() throws {
        if ProcessInfo.processInfo.environment["YOUTUBEKIT_RUN_LIVE_TESTS"] != "1" {
            throw XCTSkip("Set YOUTUBEKIT_RUN_LIVE_TESTS=1 to enable live YouTube smoke tests.")
        }
    }

    func testPrimaryPlayerEndpointStillReturnsNativePlayableStream() async throws {
        try requireLiveTests()

        let model = YouTubeModel()
        model.selectedLocale = "en-US"
        model.replaceHeaders(
            withHeaders: NativePlaybackSupport.makeVideoInfosHeaders(languageCode: "en", countryCode: "US"),
            headersType: .videoInfos
        )

        let searchResponse = try await SearchResponse.sendThrowingRequest(
            youtubeModel: model,
            data: [.query: "home"],
            useCookies: false
        )

        guard let visitorData = searchResponse.visitorData, !visitorData.isEmpty else {
            XCTFail("visitorData stage failed: SearchResponse did not provide a visitor token.")
            return
        }

        model.visitorData = visitorData

        let response = try await VideoInfosResponse.sendThrowingRequest(
            youtubeModel: model,
            data: [
                .query: smokeVideoID,
                .visitorData: visitorData
            ],
            useCookies: false
        )

        guard let playableURL = NativePlaybackSupport.streamingURL(from: response) else {
            XCTFail("primaryVideoInfos stage failed: player endpoint returned neither HLS nor muxed MP4.")
            return
        }

        XCTAssertTrue(playableURL.scheme?.hasPrefix("http") == true)
    }

    func testWatchPageStillContainsParsableInitialPlayerResponse() async throws {
        try requireLiveTests()

        let url = URL(string: "https://www.youtube.com/watch?v=\(smokeVideoID)&bpctr=9999999999&has_verified=1")!
        var request = URLRequest(url: url)
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.2 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue(
            "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            forHTTPHeaderField: "Accept"
        )
        request.setValue("en-US;q=0.9", forHTTPHeaderField: "Accept-Language")

        let (data, _) = try await URLSession.shared.data(for: request)
        let html = String(decoding: data, as: UTF8.self)

        guard let playerResponseJSON = NativePlaybackSupport.extractInitialPlayerResponseJSON(from: html) else {
            XCTFail("watchPageFallback stage failed: ytInitialPlayerResponse was not found in current watch HTML.")
            return
        }

        let response = try VideoInfosResponse.decodeJSON(json: JSON(parseJSON: playerResponseJSON))
        XCTAssertEqual(response.videoId, smokeVideoID)
    }
}
