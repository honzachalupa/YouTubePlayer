import SwiftUI
import YouTubeKit
import Combine

typealias VideoPlaylistStates = [(playlist: YTPlaylist, isVideoPresentInside: Bool)]

enum VideoPlaylistStateMapper {
    static func cachedPlaylistStates(from playlists: [YTPlaylist]) -> VideoPlaylistStates {
        playlists.map { playlist in
            (playlist: playlist, isVideoPresentInside: false)
        }
    }

    static func currentEditablePlaylists(from playlists: [YTPlaylist]) -> [YTPlaylist] {
        var playlistIDs = Set<String>()
        var currentPlaylists: [YTPlaylist] = []

        for item in playlists {
            let playlistID = normalizedPlaylistID(item.playlistId)
            guard playlistIDs.insert(playlistID).inserted else { continue }

            var playlist = item
            playlist.playlistId = playlistIDWithVLPrefix(playlist.playlistId)
            currentPlaylists.append(playlist)
        }

        return currentPlaylists
    }

    static func membershipStates(
        from fetchedStates: VideoPlaylistStates,
        limitedTo playlists: [YTPlaylist]
    ) -> VideoPlaylistStates {
        let fetchedMembership = Dictionary(
            fetchedStates.map { (normalizedPlaylistID($0.playlist.playlistId), $0.isVideoPresentInside) },
            uniquingKeysWith: { current, next in current || next }
        )

        return playlists.map { playlist in
            let playlistID = normalizedPlaylistID(playlist.playlistId)
            return (
                playlist: playlist,
                isVideoPresentInside: fetchedMembership[playlistID] ?? false
            )
        }
    }

    static func settingPlaylistPresence(
        playlistID: String,
        isPresent: Bool,
        in states: VideoPlaylistStates
    ) -> VideoPlaylistStates {
        let normalizedID = normalizedPlaylistID(playlistID)

        return states.map { item in
            guard normalizedPlaylistID(item.playlist.playlistId) == normalizedID else { return item }
            return (playlist: item.playlist, isVideoPresentInside: isPresent)
        }
    }

    static func normalizedPlaylistID(_ playlistID: String) -> String {
        playlistID.hasPrefix("VL") ? String(playlistID.dropFirst(2)) : playlistID
    }

    static func playlistIDWithVLPrefix(_ playlistID: String) -> String {
        playlistID.hasPrefix("VL") ? playlistID : "VL" + playlistID
    }

    static func playlistIDWithoutVLPrefix(_ playlistID: String) -> String {
        normalizedPlaylistID(playlistID)
    }
}

@MainActor
class VideoPlaylistsViewModel: ObservableObject {
    @Published var playlistStates: VideoPlaylistStates = []
    @Published var isLoading = false

    private var video: YTVideo?
    private var activeLoadID: UUID?
    private let videoManager: VideoManager

    init(video: YTVideo, videoManager: VideoManager) {
        self.video = video
        self.videoManager = videoManager
        self.playlistStates = Self.playlistStates(from: videoManager.cachedEditablePlaylists())
        self.isLoading = playlistStates.isEmpty
    }

    func load(video: YTVideo) async {
        self.video = video
        let loadID = UUID()
        activeLoadID = loadID

        setPlaylistStates(Self.playlistStates(from: videoManager.cachedEditablePlaylists()))
        isLoading = playlistStates.isEmpty

        let refreshedStates = await videoManager.refreshPlaylistMembershipStates(for: video)
        guard isCurrentLoad(loadID, for: video) else {
            return
        }

        isLoading = false
        if let refreshedStates {
            setPlaylistStates(refreshedStates)
        }
    }

    private static func playlistStates(from playlists: [YTPlaylist]) -> VideoPlaylistStates {
        VideoPlaylistStateMapper.cachedPlaylistStates(from: playlists)
    }

    private func isCurrentLoad(_ loadID: UUID, for video: YTVideo) -> Bool {
        activeLoadID == loadID && self.video?.videoId == video.videoId
    }

    private func setPlaylistStates(_ states: VideoPlaylistStates) {
        guard playlistStates.map(\.playlist.playlistId) != states.map(\.playlist.playlistId)
                || playlistStates.map(\.isVideoPresentInside) != states.map(\.isVideoPresentInside) else {
            return
        }

        playlistStates = states
    }

    func canEditPlaylist(_ playlist: YTPlaylist) -> Bool {
        videoManager.canEditPlaylist(playlist)
    }

    func addToPlaylist(_ playlist: YTPlaylist) async {
        guard let video else { return }

        guard videoManager.canEditPlaylist(playlist) else {
            return
        }

        let didAdd = await videoManager.addVideo(video, to: playlist)
        guard didAdd else { return }

        setPlaylistStates(
            VideoPlaylistStateMapper.settingPlaylistPresence(
                playlistID: playlist.playlistId,
                isPresent: true,
                in: playlistStates
            )
        )
    }

    func removeFromPlaylist(_ playlist: YTPlaylist) async {
        guard let video else { return }

        let didRemove = await videoManager.removeVideo(video, from: playlist)
        guard didRemove else { return }

        setPlaylistStates(
            VideoPlaylistStateMapper.settingPlaylistPresence(
                playlistID: playlist.playlistId,
                isPresent: false,
                in: playlistStates
            )
        )
    }
}
