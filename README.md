# YouTube

Unofficial native YouTube client for iOS and tvOS built with SwiftUI, SwiftData, AVKit, and YouTubeKit.

This project is an experiment in building a fully native Apple-platform client on top of YouTubeKit's access to YouTube's internal endpoints. It focuses on search, recommendations, subscriptions, playlists, history, and native video playback in a shared codebase for iPhone, iPad, and Apple TV.

## Disclaimer

This repository and the software distributed from it are provided for educational, research, interoperability, and personal experimental purposes only.

The project is unofficial. It is not affiliated with, endorsed by, sponsored by, or approved by YouTube or Google.

This application relies on YouTubeKit and on access patterns that may depend on undocumented, internal, or otherwise unsupported YouTube interfaces. Those interfaces may change, break, rate-limit, or become unavailable at any time without notice.

By using, modifying, building, running, or redistributing this project, you accept that:

- you are solely responsible for assessing whether your use complies with applicable law, platform rules, copyright rules, contractual obligations, and the terms of service of any third-party service involved;
- you are solely responsible for any account, content, network, compliance, or enforcement risk resulting from your use of this software;
- the maintainers provide no legal advice, no guarantee of functionality, no guarantee of continued access, and no warranty of any kind;
- to the maximum extent permitted by applicable law, the authors, contributors, and distributors disclaim liability for any direct, indirect, incidental, consequential, exemplary, or special damages arising out of or related to the use, misuse, distribution, or inability to use this project.

If you do not understand or accept those risks, do not use this software.

## Status

- Intended for local builds and direct distribution outside the App Store.
- Not designed around App Store policy compliance.
- Expected to require ongoing maintenance as upstream YouTube responses and player behavior evolve.

## Feature Overview

- Native SwiftUI UI for iOS and tvOS.
- Shared application core in `Shared/` with thin platform entry points in `iOS/` and `tvOS/`.
- Recommended videos feed.
- Search for videos and channels.
- Authenticated subscriptions feed.
- Authenticated history view.
- Authenticated playlist listing, creation, deletion, and add/remove video actions.
- Native playback via `AVPlayer` and `AVPlayerViewController`.
- Picture in Picture support where the platform allows it.
- Background playback and remote transport controls.
- Playback queue support for recommended videos and playlists.
- Persisted playback positions via SwiftData.
- Basic Czech localization alongside English strings.

## Technical Architecture

### High-level layout

- `iOS/`: iOS-specific app entry point, iOS views, WebKit login flow, and platform helpers.
- `tvOS/`: tvOS-specific app entry point and presentation shell.
- `Shared/`: shared models, services, playback logic, and most of the UI.
- `iOSTests/`: unit tests and optional live smoke tests for native playback behavior.

### App composition

Both platform targets bootstrap the same shared services through SwiftData-backed `ModelContainer` instances. The main persistent models are:

- `AuthenticationModel`: stores sign-in state, cookies, visitor data, and cached account info.
- `PlaybackPositionModel`: stores resume positions for previously watched videos.

The app keeps most state in shared singletons and observable objects:

- `YouTubeService`: configures `YouTubeModel`, stores cookies and visitor data, and manages short-lived caches.
- `YouTubeAuthService`: loads and saves authentication state, validates cookie presence, fetches account metadata, and handles sign-out cleanup.
- `YouTubePlaylistService`: fetches account playlists and performs playlist create/delete mutations.
- `VideoManager`: owns playback state, `AVPlayer`, queue logic, now playing info, remote controls, and persisted playback position updates.

### Authentication model

Authentication is cookie-based.

On iOS, the login flow uses a `WKWebView` wrapper in `YouTubeLoginWebView` to load the Google/YouTube sign-in page. After successful navigation back to YouTube, the app extracts YouTube-domain cookies and passes them into the shared authentication service.

The shared authentication service then:

- verifies the presence of required auth cookies such as `SAPISID` and secure session cookies;
- fetches or restores visitor data needed for some requests;
- requests account metadata to confirm that the session is usable;
- persists cookies, visitor data, and account info locally.

There is no application backend. Authentication material is stored on-device in SwiftData and related local preferences.

### Request and data layer

The project uses `YouTubeKit` as the transport and response-decoding layer for YouTube data.

The shared service layer builds on top of YouTubeKit request types such as:

- `HomeScreenResponse` for initial visitor data and recommendation sources,
- `SearchResponse` for video and channel discovery,
- `AccountSubscriptionsFeedResponse` for subscriptions,
- `AccountPlaylistsResponse`, `CreatePlaylistResponse`, `DeletePlaylistResponse`, and playlist mutation endpoints for playlist management,
- `AccountInfosResponse` for account identity and session validation,
- `VideoInfosResponse`, `VideoInfosWithDownloadFormatsResponse`, and `MoreVideoInfosResponse` for playback and detail screens.

The app also adds its own caching and fallback logic on top of library responses:

- in-memory TTL caching for recommended feeds and detailed video metadata;
- persisted subscriptions feed caching for faster reloads;
- fallback extraction of `ytInitialPlayerResponse` from watch-page HTML when the primary player path becomes brittle.

### Native playback pipeline

Playback is intentionally native rather than WebView-based.

`NativePlaybackSupport` customizes the request headers used for player requests by emulating a current Android YouTube client profile. It builds a custom request to `https://www.youtube.com/youtubei/v1/player`, injects locale and visitor data, and prefers:

1. HLS manifests when available.
2. Muxed MP4 formats with an `avc1` codec when HLS is unavailable.

`VideoManager` then wraps the resolved media URL in `AVPlayer`, wires periodic observation, updates system now playing metadata, saves resume positions, and advances to the next queued video when playback finishes.

### UI model

The shared UI is organized around content tabs and detail navigation:

- `Recommended`
- `Search`
- `Subscriptions` when authenticated
- `History` when authenticated
- `Playlists` when authenticated

The iOS target also exposes a bottom accessory playback control surface and presents the active video in a sheet backed by the shared `VideoView`.

## Dependencies

Resolved Swift Package dependencies currently include:

- `YouTubeKit` `2.7.0`
- `SwiftCore` `1.10.3`
- `NetworkImage` `6.0.1`
- `swift-markdown-ui` `2.4.1`
- `swift-cmark` `0.6.0`
- `PhoneNumberKit` `4.1.3`

The most important dependency is YouTubeKit, which provides the request/response abstractions used across the project.

## Build Requirements

- Current Xcode with Swift Package Manager support.
- Apple platform SDKs matching the project settings in `YouTube.xcodeproj`.
- A valid signing team if you want to run on physical devices.
- Network access to YouTube endpoints.

Because this app depends on undocumented and change-prone upstream behavior, a build that succeeds today is not a guarantee that playback and authenticated actions will keep working tomorrow.

## Getting Started

1. Open `YouTube.xcodeproj` in Xcode.
2. Allow Swift Package Manager to resolve dependencies.
3. Select the `iOS` or `tvOS` shared scheme.
4. Adjust signing settings for your Apple developer team if needed.
5. Build and run on a simulator or device.

For authenticated features, sign in through the in-app flow on iOS so the app can capture the YouTube cookies it expects.

## Testing

The project includes both deterministic unit tests and opt-in live smoke tests.

### Unit tests

`NativePlaybackSupportTests` verifies the custom player request headers, country resolution logic, playable format selection, and HTML player-response extraction behavior.

### Live smoke tests

`LivePlaybackSmokeTests` can hit live YouTube endpoints to verify that:

- the customized player endpoint still returns a natively playable stream, and
- the watch page still contains a parsable initial player response.

Enable them explicitly with environment variables before running tests:

```bash
YOUTUBEKIT_RUN_LIVE_TESTS=1
YOUTUBEKIT_SMOKE_VIDEO_ID=dQw4w9WgXcQ
```

These tests are intentionally disabled by default because they depend on external network behavior and may fail due to upstream changes outside this repository.

## Data Storage and Privacy Notes

This app stores some sensitive operational data locally on the device, including:

- YouTube authentication cookies,
- visitor data tokens,
- cached account metadata,
- cached feed data,
- playback resume positions.

There is no remote application server in this repository. Data flows directly between the app and YouTube endpoints through YouTubeKit and related request code.

If you distribute binaries to other users, assume that local cookie handling, account exposure, and service enforcement are meaningful risks that should be communicated clearly.

## Known Limitations

- No App Store compatibility target.
- Heavy reliance on internal or undocumented YouTube behavior.
- Authenticated flows are fragile because they depend on cookie presence and response shapes.
- Playback may break when YouTube changes player headers, response schemas, or watch-page markup.
- Some playlist operations rely on API quirks, including creation via a temporary known video ID before cleanup.

## Repository Intent

This repository documents the implementation of an unofficial native client. It should be treated as a research codebase, not as a compatibility promise, production service, or legally reviewed distribution package.
