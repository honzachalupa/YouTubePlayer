import Foundation
import YouTubeKit

enum NativePlaybackSupport {
    static let androidClientVersion = "21.24.37"
    static let androidUserAgent = "com.google.android.youtube/\(androidClientVersion) (Linux; U; Android 15) gzip"

    static func resolvedCountryCode(
        selectedLocaleCountryCode: String,
        languageCode: String,
        fallbackRegionCode: String
    ) -> String {
        let uppercaseLocaleCountryCode = selectedLocaleCountryCode.uppercased()
        let uppercaseLanguageCode = languageCode.uppercased()

        if uppercaseLocaleCountryCode.isEmpty || uppercaseLocaleCountryCode == uppercaseLanguageCode {
            return fallbackRegionCode.uppercased()
        }

        return uppercaseLocaleCountryCode
    }

    static func makeVideoInfosHeaders(
        languageCode: String,
        countryCode: String
    ) -> HeadersList {
        HeadersList(
            url: URL(string: "https://www.youtube.com/youtubei/v1/player")!,
            method: .POST,
            headers: [
                .init(name: "Accept", content: "*/*"),
                .init(name: "Accept-Encoding", content: "gzip, deflate, br"),
                .init(name: "Content-Type", content: "application/json"),
                .init(name: "User-Agent", content: androidUserAgent),
                .init(name: "X-Youtube-Client-Name", content: "3"),
                .init(name: "X-Youtube-Client-Version", content: androidClientVersion)
            ],
            customHeaders: [
                "X-Goog-Visitor-Id": .visitorData
            ],
            addQueryAfterParts: [
                .init(index: 0, encode: false, content: .query)
            ],
            httpBody: [
                """
                {"contentCheckOk":true,"context":{"client":{"androidSdkVersion":35,"clientName":"ANDROID","clientVersion":"\(androidClientVersion)","deviceMake":"Google","deviceModel":"Pixel 8","gl":"\(countryCode)","hl":"\(languageCode)","osName":"Android","osVersion":"15","timeZone":"UTC","userAgent":"\(androidUserAgent)","utcOffsetMinutes":0}},"playbackContext":{"contentPlaybackContext":{"html5Preference":"HTML5_PREF_WANTS"}},"racyCheckOk":true,"videoId":"
                """,
                "\"}"
            ],
            parameters: [
                .init(name: "prettyPrint", content: "false")
            ]
        )
    }

    static func preferredMuxedStreamingURL(from formats: [any DownloadFormat]) -> URL? {
        let preferredMuxedFormat = formats
            .compactMap { $0 as? VideoDownloadFormat }
            .filter { format in
                guard let url = format.url,
                      let mimeType = format.mimeType?.lowercased(),
                      let codec = format.codec?.lowercased() else {
                    return false
                }

                return url.scheme?.hasPrefix("http") == true &&
                    mimeType.contains("video/mp4") &&
                    codec.contains("avc1")
            }
            .sorted { ($0.height ?? 0) > ($1.height ?? 0) }
            .first

        return preferredMuxedFormat?.url
    }

    static func streamingURL(from response: VideoInfosResponse) -> URL? {
        if let hlsURL = response.streamingURL {
            return hlsURL
        }

        return preferredMuxedStreamingURL(from: response.defaultFormats)
    }

    static func fallbackStreamingURL(from response: VideoInfosWithDownloadFormatsResponse) -> URL? {
        if let streamURL = response.videoInfos.streamingURL {
            return streamURL
        }

        return preferredMuxedStreamingURL(from: response.defaultFormats)
    }

    static func extractInitialPlayerResponseJSON(from html: String) -> String? {
        let marker = "var ytInitialPlayerResponse = "

        guard let markerRange = html.range(of: marker) else {
            return nil
        }

        var index = markerRange.upperBound
        while index < html.endIndex, html[index].isWhitespace {
            index = html.index(after: index)
        }

        guard index < html.endIndex, html[index] == "{" else {
            return nil
        }

        let startIndex = index
        var depth = 0
        var isInsideString = false
        var isEscaped = false

        while index < html.endIndex {
            let character = html[index]

            if isInsideString {
                if isEscaped {
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == "\"" {
                    isInsideString = false
                }
            } else if character == "\"" {
                isInsideString = true
            } else if character == "{" {
                depth += 1
            } else if character == "}" {
                depth -= 1

                if depth == 0 {
                    return String(html[startIndex...index])
                }
            }

            index = html.index(after: index)
        }

        return nil
    }
}
