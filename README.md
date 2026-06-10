# Luli for Reddit

A fast, modern Reddit client for Android, built with Flutter and a Material 3
Expressive design. You bring your own Reddit API credentials; nothing is sent
anywhere but Reddit.

## Features

- Browse the frontpage, subreddits, multireddits, and users
- A personalized **For You** feed built entirely on-device, with explainable
  "why you're seeing this" labels and per-post tuning
- Full participation: vote, comment, reply, submit text/link/image/gallery/video
  posts, edit, and delete
- Inbox and private messages
- Saved, upvoted, and locally-stored history
- Moderation actions on subreddits you moderate
- Three feed layouts, swipe-to-vote, NSFW blur, AMOLED and dynamic-color themes
- Offline cache, rate-limit awareness, and an in-app updater

## Install

Download the APK from the
[latest release](https://github.com/bennybar/LuliReddit/releases/latest) and
install it. The app checks GitHub for newer releases and can update itself.

(iOS has no public distribution — build and sideload it yourself; see `ios.txt`.)

## First run

The app ships with no API keys — you provide your own:

1. Go to <https://www.reddit.com/prefs/apps> and create an app of type
   **installed app**.
2. Set the redirect URI to exactly `luli://oauth`.
3. Copy the client ID (shown under the app name) into the login screen and
   connect.

## Build from source

Requires Flutter 3.35+.

```
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build apk --release
```

## Tech

Flutter, Riverpod, Dio, go_router, Freezed. Reddit OAuth2 (installed-app flow),
credentials stored in the device keychain.

Not affiliated with Reddit, Inc.
