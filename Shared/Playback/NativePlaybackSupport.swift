import Foundation
import YouTubeKit

enum NativePlaybackSupport {
    struct HLSVariant {
        let bandwidth: Int
        let width: Int
        let height: Int

        var pixelCount: Int {
            width * height
        }
    }

    static func preferredOriginalAudioOption<Option>(
        from options: [Option],
        defaultOption: Option?,
        displayName: (Option) -> String,
        extendedLanguageTag: (Option) -> String?
    ) -> Option? {
        guard !options.isEmpty else { return nil }
        guard options.count > 1 else { return options[0] }

        if let original = options.first(where: { isOriginalAudioOption(displayName: displayName($0), extendedLanguageTag: extendedLanguageTag($0)) }) {
            return original
        }

        if let defaultOption,
           !isDubbedAudioOption(displayName: displayName(defaultOption), extendedLanguageTag: extendedLanguageTag(defaultOption)) {
            return defaultOption
        }

        if let nonDubbed = options.first(where: { !isDubbedAudioOption(displayName: displayName($0), extendedLanguageTag: extendedLanguageTag($0)) }) {
            return nonDubbed
        }

        return defaultOption ?? options[0]
    }

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

    static func isLikelyHLSPlaylistURL(_ url: URL) -> Bool {
        let value = url.absoluteString.lowercased()
        return value.contains(".m3u8") ||
            value.contains("/manifest/hls") ||
            value.contains("hls_playlist") ||
            value.contains("playlist_type=hls")
    }

    private static func isOriginalAudioOption(displayName: String, extendedLanguageTag: String?) -> Bool {
        let searchableText = audioOptionSearchText(
            displayName: displayName,
            extendedLanguageTag: extendedLanguageTag
        )

        return searchableText.contains("original") ||
            searchableText.contains("orig") ||
            searchableText.contains("default")
    }

    private static func isDubbedAudioOption(displayName: String, extendedLanguageTag: String?) -> Bool {
        let searchableText = audioOptionSearchText(
            displayName: displayName,
            extendedLanguageTag: extendedLanguageTag
        )

        return searchableText.contains("dub") ||
            searchableText.contains("dubbed") ||
            searchableText.contains("descriptive") ||
            searchableText.contains("description") ||
            searchableText.contains("commentary") ||
            searchableText.contains("translation")
    }

    private static func audioOptionSearchText(displayName: String, extendedLanguageTag: String?) -> String {
        [displayName, extendedLanguageTag]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()
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

    static func highestQualityHLSVariant(from masterPlaylist: String, masterURL: URL) -> HLSVariant? {
        let variants = hlsVariants(from: masterPlaylist, masterURL: masterURL)

        return variants
            .sorted {
                if $0.pixelCount == $1.pixelCount {
                    return $0.bandwidth > $1.bandwidth
                }

                return $0.pixelCount > $1.pixelCount
            }
            .first
    }

    static func hlsVariantSummary(from masterPlaylist: String, masterURL: URL) -> String {
        let variants = hlsVariants(from: masterPlaylist, masterURL: masterURL)

        guard !variants.isEmpty else {
            return "no HLS variants found"
        }

        return variants
            .sorted {
                if $0.pixelCount == $1.pixelCount {
                    return $0.bandwidth > $1.bandwidth
                }

                return $0.pixelCount > $1.pixelCount
            }
            .map { variant in
                let mbps = Double(variant.bandwidth) / 1_000_000
                return "\(variant.width)x\(variant.height) @ \(String(format: "%.1f", mbps)) Mbps"
            }
            .joined(separator: ", ")
    }

    private static func hlsVariants(from masterPlaylist: String, masterURL: URL) -> [HLSVariant] {
        let lines = masterPlaylist
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }

        var variants: [HLSVariant] = []

        for index in lines.indices where lines[index].hasPrefix("#EXT-X-STREAM-INF:") {
            guard let uriLine = lines[(index + 1)...].first(where: { !$0.isEmpty && !$0.hasPrefix("#") }),
                  URL(string: uriLine, relativeTo: masterURL)?.absoluteURL != nil else {
                continue
            }

            let attributes = lines[index]
            let bandwidth = hlsIntegerAttribute("BANDWIDTH", in: attributes) ?? 0
            let resolution = hlsResolutionAttribute(in: attributes) ?? (width: 0, height: 0)

            variants.append(
                HLSVariant(
                    bandwidth: bandwidth,
                    width: resolution.width,
                    height: resolution.height
                )
            )
        }

        return variants
    }

    private static func hlsIntegerAttribute(_ name: String, in attributes: String) -> Int? {
        guard let value = hlsAttribute(name, in: attributes) else { return nil }
        return Int(value)
    }

    private static func hlsResolutionAttribute(in attributes: String) -> (width: Int, height: Int)? {
        guard let value = hlsAttribute("RESOLUTION", in: attributes) else { return nil }
        let parts = value.split(separator: "x")
        guard parts.count == 2,
              let width = Int(parts[0]),
              let height = Int(parts[1]) else {
            return nil
        }

        return (width, height)
    }

    private static func hlsAttribute(_ name: String, in attributes: String) -> String? {
        guard let range = attributes.range(of: "\(name)=") else { return nil }
        var value = attributes[range.upperBound...]

        if let commaIndex = value.firstIndex(of: ",") {
            value = value[..<commaIndex]
        }

        return String(value).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
    }

    static func streamingURL(from response: VideoInfosResponse) -> URL? {
        if let muxedURL = preferredMuxedStreamingURL(from: response.defaultFormats) {
            return muxedURL
        }

        return response.streamingURL
    }

    static func fallbackStreamingURL(from response: VideoInfosWithDownloadFormatsResponse) -> URL? {
        if let muxedURL = preferredMuxedStreamingURL(from: response.defaultFormats) {
            return muxedURL
        }

        return response.videoInfos.streamingURL
    }

}
