import SwiftUI
import SwiftData
import YouTubeKit

private struct YouTubeSearchResultsResponse: YouTubeResponse {
    static let headersType: HeaderTypes = .search
    static let parametersValidationList: ValidationList = [.query: .existenceValidator]

    var videos: [YTVideo] = []
    var channels: [YTChannel] = []
    var continuationToken: String?
    var visitorData: String?

    static func decodeJSON(json: JSON) throws -> YouTubeSearchResultsResponse {
        var response = YouTubeSearchResultsResponse()
        let visitorData = json["responseContext", "visitorData"].stringValue
        response.visitorData = visitorData.isEmpty ? nil : visitorData

        let sectionContents = json["contents", "twoColumnSearchResultsRenderer", "primaryContents", "sectionListRenderer", "contents"].arrayValue
        response.decodeSectionContents(sectionContents)
        return response
    }

    private mutating func decodeSectionContents(_ sectionContents: [JSON]) {
        for section in sectionContents {
            if let token = section["continuationItemRenderer", "continuationEndpoint", "continuationCommand", "token"].string {
                continuationToken = token
            }

            decodeResultItems(section["itemSectionRenderer", "contents"].arrayValue)
        }
    }

    private mutating func decodeResultItems(_ items: [JSON]) {
        for item in items {
            if let video = YTVideo.decodeJSON(json: item["videoRenderer"]) ?? YTVideo.decodeLockupJSON(json: item["lockupViewModel"]) {
                videos.append(video)
            } else if let channel = YTChannel.decodeJSON(json: item["channelRenderer"]) {
                channels.append(channel)
            } else {
                decodeResultItems(item["shelfRenderer", "content", "verticalListRenderer", "items"].arrayValue)
            }
        }
    }
}

private struct YouTubeSearchContinuationResponse: YouTubeResponse {
    static let headersType: HeaderTypes = .searchContinuationHeaders
    static let parametersValidationList: ValidationList = [.continuation: .existenceValidator]

    var videos: [YTVideo] = []
    var continuationToken: String?

    static func decodeJSON(json: JSON) throws -> YouTubeSearchContinuationResponse {
        var response = YouTubeSearchContinuationResponse()
        let continuationItems = json["onResponseReceivedCommands", 0, "appendContinuationItemsAction", "continuationItems"].arrayValue

        for item in continuationItems {
            if let token = item["continuationItemRenderer", "continuationEndpoint", "continuationCommand", "token"].string {
                response.continuationToken = token
            }

            response.decodeResultItems(item["itemSectionRenderer", "contents"].arrayValue)
        }

        return response
    }

    private mutating func decodeResultItems(_ items: [JSON]) {
        for item in items {
            if let video = YTVideo.decodeJSON(json: item["videoRenderer"]) ?? YTVideo.decodeLockupJSON(json: item["lockupViewModel"]) {
                videos.append(video)
            } else {
                decodeResultItems(item["shelfRenderer", "content", "verticalListRenderer", "items"].arrayValue)
            }
        }
    }
}

struct SearchVideosView: View {
    private let youtubeService = YouTubeService.shared
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SearchQueryModel.lastSearchedAt, order: .reverse) private var recentSearches: [SearchQueryModel]
    @State private var searchText = ""
    @State private var submittedQuery = ""
    @State private var videos: [YTVideo] = []
    @State private var channels: [YTChannel] = []
    @State private var fetchError: Error?
    @State private var isSearching = false
    @State private var isLoadingMore = false
    @State private var continuationToken: String?
    @State private var hasMoreResults = false
    @State private var visitorData: String?
    @State private var activeSearchID = UUID()
    @State private var suppressNextGridFetch = false
    @FocusState private var isSearchFocused: Bool

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var searchLocale: String {
        let normalizedLocale = Locale.current.identifier.replacingOccurrences(of: "_", with: "-")
        let components = normalizedLocale.split(separator: "-").map(String.init)
        let languageCode = components.first?.isEmpty == false ? components[0] : "en"
        let regionCode = components.dropFirst().first(where: { $0.count == 2 }) ?? "US"
        return "\(languageCode)-\(regionCode.uppercased())"
    }

    private var shouldShowInitialState: Bool {
        submittedQuery.isEmpty && videos.isEmpty && channels.isEmpty && fetchError == nil && !isSearching
    }

    private var shouldShowVideosSection: Bool {
        !videos.isEmpty || isSearching
    }

    private var searchResultsHeader: AnyView? {
        guard !channels.isEmpty || shouldShowVideosSection else { return nil }

        return AnyView(
            VStack(alignment: .leading, spacing: 0) {
                if !channels.isEmpty {
                    SearchChannelsSection(channels: channels)

                    if shouldShowVideosSection {
                        Divider()
                            .padding(.horizontal)
                    }
                }

                if shouldShowVideosSection {
                    SearchSectionHeader(title: "Videos")
                }
            }
        )
    }

    private func resetSearchResults() {
        activeSearchID = UUID()
        submittedQuery = ""
        videos = []
        channels = []
        fetchError = nil
        isSearching = false
        isLoadingMore = false
        continuationToken = nil
        hasMoreResults = false
        visitorData = nil
        suppressNextGridFetch = false
    }

    private func saveRecentSearch(_ query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }

        let normalizedQuery = SearchQueryModel.normalizedQuery(trimmedQuery)
        let now = Date()
        let searchToKeep = recentSearches.first { $0.normalizedQuery == normalizedQuery }
            ?? SearchQueryModel(query: trimmedQuery, lastSearchedAt: now)

        searchToKeep.query = trimmedQuery
        searchToKeep.normalizedQuery = normalizedQuery
        searchToKeep.lastSearchedAt = now

        if searchToKeep.modelContext == nil {
            modelContext.insert(searchToKeep)
        }

        var retainedSearches = [searchToKeep]

        for search in recentSearches where search !== searchToKeep {
            if search.normalizedQuery == normalizedQuery || retainedSearches.count >= 10 {
                modelContext.delete(search)
            } else {
                retainedSearches.append(search)
            }
        }

        do {
            try modelContext.save()
        } catch {
            fetchError = error
        }
    }

    private func searchVideos() async {
        let query = trimmedSearchText
        guard !query.isEmpty else {
            withAnimation {
                resetSearchResults()
            }
            return
        }

        saveRecentSearch(query)

        let searchID = UUID()
        activeSearchID = searchID

        withAnimation {
            submittedQuery = query
            videos = []
            channels = []
            fetchError = nil
            continuationToken = nil
            hasMoreResults = false
            visitorData = nil
            isSearching = true
            isLoadingMore = false
        }

        do {
            youtubeService.model.selectedLocale = searchLocale
            await youtubeService.getVisitorData()

            let response = try await YouTubeSearchResultsResponse.sendThrowingRequest(
                youtubeModel: youtubeService.model,
                data: [.query: query],
                useCookies: false
            )

            guard activeSearchID == searchID else { return }

            withAnimation {
                videos = response.videos
                channels = response.channels
                continuationToken = response.continuationToken
                visitorData = response.visitorData
                hasMoreResults = response.continuationToken != nil
                suppressNextGridFetch = true
                isSearching = false
            }
        } catch {
            guard activeSearchID == searchID else { return }

            withAnimation {
                fetchError = error
                videos = []
                channels = []
                hasMoreResults = false
                suppressNextGridFetch = true
                isSearching = false
            }
        }
    }

    private func loadMoreResults() async {
        guard !isSearching,
              !isLoadingMore,
              hasMoreResults,
              let continuationToken,
              let visitorData else {
            return
        }

        isLoadingMore = true

        do {
            let response = try await YouTubeSearchContinuationResponse.sendThrowingRequest(
                youtubeModel: youtubeService.model,
                data: [
                    .continuation: continuationToken,
                    .visitorData: visitorData
                ],
                useCookies: false
            )

            withAnimation {
                videos.append(contentsOf: response.videos)
                self.continuationToken = response.continuationToken
                hasMoreResults = response.continuationToken != nil
                fetchError = nil
            }
        } catch {
            fetchError = error
        }

        isLoadingMore = false
    }

    var body: some View {
        VStack(spacing: 0) {
            if shouldShowInitialState {
                Spacer()
                ContentUnavailableView(
                    "Search YouTube",
                    systemImage: "magnifyingglass",
                    description: Text("Find videos, channels, and topics.")
                )
                Spacer()
            } else {
                VideosGridView(
                    videos: videos,
                    error: fetchError,
                    fetchVideos: {
                        if suppressNextGridFetch {
                            suppressNextGridFetch = false
                            return
                        }

                        await searchVideos()
                    },
                    loadMoreIfNeeded: hasMoreResults ? { _ in
                        Task {
                            await loadMoreResults()
                        }
                    } : nil,
                    isLoadingMore: isLoadingMore,
                    isLoadingInitial: isSearching,
                    topContent: searchResultsHeader
                )
            }
        }
        .searchable(text: $searchText, prompt: "Search videos or channels...")
        .searchSuggestions {
            ForEach(recentSearches.prefix(10)) { search in
                Text(search.query)
                    .searchCompletion(search.query)
            }
        }
        .searchFocused($isSearchFocused)
        .navigationTitle("Search")
        .onAppear {
            Task {
                await Task.yield()
                isSearchFocused = true
            }
        }
        .onSubmit(of: .search) {
            isSearchFocused = false
            Task { await searchVideos() }
        }
        .onChange(of: trimmedSearchText) {
            guard trimmedSearchText.isEmpty else { return }

            withAnimation {
                resetSearchResults()
            }
        }
    }
}

private struct SearchSectionHeader: View {
    let title: LocalizedStringKey

    var body: some View {
        Text(title)
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 6)
    }
}

private struct SearchChannelsSection: View {
    let channels: [YTChannel]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SearchSectionHeader(title: "Channels")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(channels, id: \.channelId) { channel in
                        NavigationLink(destination: ChannelView(channel: channel)) {
                            VStack(spacing: 8) {
                                AsyncImage(url: channel.thumbnails.first?.url) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Color.gray.opacity(0.2)
                                }
                                .frame(width: 60, height: 60)
                                .clipShape(Circle())

                                Text(channel.name ?? "Unknown")
                                    .font(.caption)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(width: 84)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
    }
}

#Preview {
    SearchVideosView()
}
