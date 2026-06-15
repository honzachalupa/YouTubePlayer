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

}
