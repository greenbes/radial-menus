# Research Report: Detecting YouTube Video Playback from Radial Menu

## Executive Summary

**Yes, your radial menu app can detect if a YouTube video is currently playing in a browser.** There are multiple approaches, each with different trade-offs regarding reliability, browser compatibility, and implementation complexity.

---

## Approach 1: macOS MediaRemote Private Framework (Recommended)

### How It Works

macOS maintains a system-wide "Now Playing" service that tracks media playback across all applications, including browsers. When YouTube plays in Safari, Chrome, or Firefox, the browser publishes metadata (title, artist, playback state) to this service via the **Media Session API**.

Your app can query this service using Apple's private `MediaRemote.framework` to detect:

- Whether media is currently playing
- The title (e.g., "YouTube video title")
- The player name (e.g., "Safari", "Google Chrome", "Firefox")
- Playback state (playing/paused)

### Key Functions

```swift
// Query current now playing info
MRMediaRemoteGetNowPlayingInfo(dispatch_get_main_queue()) { info in
    // info contains title, artist, playback state, app bundle ID
}

// Register for playback state changes
MRMediaRemoteRegisterForNowPlayingNotifications(dispatch_get_main_queue())
```

### Browser Compatibility

| Browser | Now Playing Integration | Notes |
|---------|------------------------|-------|
| Safari | Excellent | Full Media Session API support, best integration |
| Chrome | Good | Works in normal mode; metadata hidden in Incognito |
| Firefox | Good | Requires `media.hardwaremediakeys.enabled` = true in about:config |

### macOS 15.4+ Breaking Change

**Critical:** Starting with macOS 15.4, Apple restricted MediaRemote access to processes with bundle IDs starting with `com.apple.`. Third-party apps are blocked.

**Workaround:** The [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) project provides a solution by using `/usr/bin/perl` (which has bundle ID `com.apple.perl5`) as a proxy to access the framework.

### Implementation for Radial Menu

Since radial-menu already uses private frameworks for input handling, adding MediaRemote would follow the same pattern:

1. Dynamically load `/System/Library/PrivateFrameworks/MediaRemote.framework`
2. Create function pointers to `MRMediaRemoteGetNowPlayingInfo` and related functions
3. For macOS 15.4+, use the Perl-based adapter approach or embed equivalent logic

### Pros/Cons

| Pros | Cons |
|------|------|
| Works across all browsers uniformly | Private API - could break in future macOS versions |
| Detects play/pause state reliably | macOS 15.4+ requires workaround |
| No browser extensions needed | Won't be accepted in Mac App Store |
| Real-time notifications available | Requires Accessibility permissions |

---

## Approach 2: AppleScript Browser Queries

### How It Works

Query each browser directly for its current tab URL/title using AppleScript.

### Browser-Specific Scripts

**Safari:**
```applescript
tell application "Safari"
    set tabURL to URL of current tab of front window
    set tabTitle to name of current tab of front window
end tell
-- Check if tabURL contains "youtube.com" and title suggests video
```

**Chrome:**
```applescript
tell application "Google Chrome"
    set tabURL to URL of active tab of front window
    set tabTitle to title of active tab of front window
end tell
```

**Firefox:** Limited AppleScript support. A hacky workaround:
```applescript
tell application "Firefox" to activate
tell application "System Events"
    keystroke "l" using command down  -- Focus URL bar
    keystroke "c" using command down  -- Copy URL
end tell
delay 0.2
return the clipboard
```

### Pros/Cons

| Pros | Cons |
|------|------|
| Uses documented APIs (for Safari/Chrome) | Cannot detect if video is actually playing (only that page is open) |
| No private frameworks | Firefox support is fragile/hacky |
| No browser extensions needed | Requires checking multiple browsers |
| Works on all macOS versions | Intrusive for Firefox (steals focus, modifies clipboard) |

---

## Approach 3: Browser Extension + IPC

### How It Works

A browser extension monitors the page for video playback and communicates with your app via:

- Native messaging (most robust)
- WebSocket server in your app
- Shared file (e.g., `/tmp/youtube-status.json`)

### Existing Solution: WebNowPlaying

The [WebNowPlaying](https://github.com/keifufu/WebNowPlaying) browser extension already does this:

- Supports YouTube, Twitch, Spotify Web, SoundCloud, and more
- Exposes: playback state (playing/paused/stopped), title, artist, progress, duration
- Communicates via WebSocket

You would need to create an adapter that connects to WebNowPlaying's WebSocket and exposes the data to radial-menu.

### Pros/Cons

| Pros | Cons |
|------|------|
| Most accurate playback state detection | Requires user to install browser extension |
| Works across all browsers uniformly | Additional moving parts |
| Can detect specific video elements | Maintenance burden (extension updates) |
| Full control over what's detected | User friction |

---

## Approach 4: Accessibility API (AXUIElement)

### How It Works

Traverse the browser's accessibility tree to find video player controls and check their state.

### Reality Check

This approach is **not recommended** because:

- Browser accessibility trees are complex and browser-version-specific
- Video element accessibility varies by website (YouTube's player structure changes)
- Requires extensive reverse-engineering per browser
- Performance impact from tree traversal

---

## Recommendation

For your use case, I recommend **Approach 1 (MediaRemote)** with the following strategy:

1. **Primary**: Use MediaRemote to detect Now Playing state
2. **Fallback for macOS 15.4+**: Embed the mediaremote-adapter Perl approach
3. **Detection logic**:
   - Check if `kMRMediaRemoteNowPlayingInfoPlaybackRate` > 0 (playing)
   - Check if player app is a browser (Safari, Chrome, Firefox bundle IDs)
   - Optionally check if title contains "YouTube" or if artwork URL is from YouTube

### Why Not Require Safari?

While Safari has the best Now Playing integration, users expect Firefox/Chrome support. The MediaRemote approach works uniformly across all browsers that implement the Media Session API (which YouTube uses).

---

## Sources

- [MediaRemote.framework Documentation (The Apple Wiki)](https://theapplewiki.com/wiki/Dev:MediaRemote.framework)
- [mediaremote-adapter for macOS 15.4+](https://github.com/ungive/mediaremote-adapter)
- [nohackjustnoobb/media-remote Rust bindings](https://github.com/nohackjustnoobb/media-remote)
- [PrivateFrameworks/MediaRemote headers](https://github.com/PrivateFrameworks/MediaRemote)
- [Media Session API (MDN)](https://developer.mozilla.org/en-US/docs/Web/API/Media_Session_API)
- [Firefox Media Control Documentation](https://support.mozilla.org/en-US/kb/control-audio-or-video-playback-your-keyboard)
- [Apple Now Playing Discussion](https://discussions.apple.com/thread/252301449)
- [AppleScript Browser URL Gist](https://gist.github.com/vitorgalvao/5392178)
- [WebNowPlaying Extension](https://github.com/keifufu/WebNowPlaying)
- [Hammerspoon hs.axuielement](https://www.hammerspoon.org/docs/hs.axuielement.html)
- [How macOS Has Become More Private](https://eclecticlight.co/2025/01/02/how-macos-has-become-more-private/)
