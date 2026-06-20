import XCTest
import YouTubeKit
@testable import iOS

final class VideoPlaylistStateMapperTests: XCTestCase {
    func testCachedPlaylistStatesNeverCarryAddedState() {
        let playlists = [
            playlist(id: "VLwatch-later", title: "Watch later"),
            playlist(id: "retro", title: "Retro")
        ]

        let states = VideoPlaylistStateMapper.cachedPlaylistStates(from: playlists)

        XCTAssertEqual(states.map { $0.playlist.playlistId }, ["VLwatch-later", "retro"])
        XCTAssertEqual(states.map { $0.isVideoPresentInside }, [false, false])
    }

    func testMembershipStatesUseFetchedAddedStateForEditablePlaylistsOnly() {
        let editablePlaylists = [
            playlist(id: "VLwatch-later", title: "Watch later"),
            playlist(id: "VLretro", title: "Retro")
        ]
        let fetchedStates = [
            (playlist: playlist(id: "watch-later", title: "Watch later"), isVideoPresentInside: true),
            (playlist: playlist(id: "VLretro", title: "Retro"), isVideoPresentInside: false),
            (playlist: playlist(id: "VLsaved-read-only", title: "Saved read-only"), isVideoPresentInside: true)
        ]

        let states = VideoPlaylistStateMapper.membershipStates(
            from: fetchedStates,
            limitedTo: editablePlaylists
        )

        XCTAssertEqual(states.map { $0.playlist.playlistId }, ["VLwatch-later", "VLretro"])
        XCTAssertEqual(states.map { $0.isVideoPresentInside }, [true, false])
    }

    func testMembershipStatesDoNotReusePreviousVideoAddedState() {
        let editablePlaylists = [
            playlist(id: "VLwatch-later", title: "Watch later"),
            playlist(id: "VLsrdcovky", title: "Srdcovky")
        ]
        let firstVideoStates = VideoPlaylistStateMapper.membershipStates(
            from: [
                (playlist: playlist(id: "watch-later", title: "Watch later"), isVideoPresentInside: true),
                (playlist: playlist(id: "srdcovky", title: "Srdcovky"), isVideoPresentInside: false)
            ],
            limitedTo: editablePlaylists
        )
        let secondVideoCachedStates = VideoPlaylistStateMapper.cachedPlaylistStates(from: editablePlaylists)
        let secondVideoRefreshedStates = VideoPlaylistStateMapper.membershipStates(
            from: [
                (playlist: playlist(id: "watch-later", title: "Watch later"), isVideoPresentInside: false),
                (playlist: playlist(id: "srdcovky", title: "Srdcovky"), isVideoPresentInside: false)
            ],
            limitedTo: secondVideoCachedStates.map(\.playlist)
        )

        XCTAssertEqual(firstVideoStates.map { $0.isVideoPresentInside }, [true, false])
        XCTAssertEqual(secondVideoCachedStates.map { $0.isVideoPresentInside }, [false, false])
        XCTAssertEqual(secondVideoRefreshedStates.map { $0.isVideoPresentInside }, [false, false])
    }

    func testDuplicateFetchedStatesPreferPresentMembership() {
        let editablePlaylists = [
            playlist(id: "VLwatch-later", title: "Watch later")
        ]
        let fetchedStates = [
            (playlist: playlist(id: "watch-later", title: "Watch later"), isVideoPresentInside: false),
            (playlist: playlist(id: "VLwatch-later", title: "Watch later"), isVideoPresentInside: true)
        ]

        let states = VideoPlaylistStateMapper.membershipStates(
            from: fetchedStates,
            limitedTo: editablePlaylists
        )

        XCTAssertEqual(states.map { $0.isVideoPresentInside }, [true])
    }

    func testCurrentEditablePlaylistsUseOnlyLatestAPIValue() {
        let latestAPIPlaylists = [
            playlist(id: "retro", title: "Retro"),
            playlist(id: "VLfitness", title: "Fitness")
        ]

        let playlists = VideoPlaylistStateMapper.currentEditablePlaylists(from: latestAPIPlaylists)

        XCTAssertEqual(playlists.map { $0.playlistId }, ["VLretro", "VLfitness"])
        XCTAssertEqual(playlists.map { $0.title }, ["Retro", "Fitness"])
    }

    func testCurrentEditablePlaylistsCanBecomeEmpty() {
        let playlists = VideoPlaylistStateMapper.currentEditablePlaylists(from: [])

        XCTAssertTrue(playlists.isEmpty)
    }

    func testSettingPlaylistPresenceUsesNormalizedPlaylistID() {
        let states = VideoPlaylistStateMapper.cachedPlaylistStates(from: [
            playlist(id: "VLwatch-later", title: "Watch later"),
            playlist(id: "VLretro", title: "Retro")
        ])

        let updatedStates = VideoPlaylistStateMapper.settingPlaylistPresence(
            playlistID: "watch-later",
            isPresent: true,
            in: states
        )

        XCTAssertEqual(updatedStates.map { $0.isVideoPresentInside }, [true, false])
    }

    func testPlaylistIDPrefixHelpers() {
        XCTAssertEqual(VideoPlaylistStateMapper.playlistIDWithVLPrefix("watch-later"), "VLwatch-later")
        XCTAssertEqual(VideoPlaylistStateMapper.playlistIDWithVLPrefix("VLwatch-later"), "VLwatch-later")
        XCTAssertEqual(VideoPlaylistStateMapper.playlistIDWithoutVLPrefix("VLwatch-later"), "watch-later")
        XCTAssertEqual(VideoPlaylistStateMapper.playlistIDWithoutVLPrefix("watch-later"), "watch-later")
    }

    private func playlist(id: String, title: String) -> YTPlaylist {
        YTPlaylist(playlistId: id, title: title)
    }
}
