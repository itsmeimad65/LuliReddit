# Luli for Reddit

A Reddit client for Android, built with Flutter and a **Material 3 Expressive**
design — blending Google's newer app aesthetic (rounded search bar, pill
navigation, soft containers) with the comfortable content density of Sync for
Reddit.

This is a ground-up rebuild of the ideas behind Infinity for Reddit. It is
distributed via GitHub only (no Play Store), so it ships **without any API keys
baked in** — you provide your own Reddit API credentials once, on the login
screen, and they are stored securely on-device.

## Setup: getting your Reddit API credentials

Login is mandatory and self-service. The login screen walks you through this:

1. Open <https://www.reddit.com/prefs/apps> and tap **create app**.
2. Choose the **installed app** type (no client secret needed).
3. Set the **redirect URI** to exactly:

   ```
   luli://oauth
   ```

4. Create the app. Your **Client ID** is the short string shown just under the
   app name.
5. Paste the Client ID into Luli, leave the redirect URI as the default, and tap
   **Connect Reddit account**.

The login screen validates your configuration before sending you to the browser:

- **Client ID check** — Luli performs an installed-app token request to confirm
  the ID exists and is the correct app type. (`Test configuration` button, and
  also run automatically before login.)
- **Redirect URI check** — validated by Reddit itself during the browser
  authorization step; if it doesn't match, you get a precise error telling you
  what to fix.

An optional **Giphy API key** can be entered to enable GIF features later.

## What works (Browse-complete milestone)

- OAuth2 login (installed-app flow) with token refresh
- Frontpage + subreddit feeds with `best / hot / new / top / rising` sorting and
  time ranges, infinite scroll
- Post cards: images, GIFs, galleries, videos, link previews, self text
- Post detail with threaded comments, collapse, and load-more
- Subreddit pages with join/leave
- Search across posts, subreddits, and users
- User profiles
- Image / gallery / video viewers
- Voting and saving
- Account tab with subscriptions and logout

## What works (Participate milestone)

- Reply to posts and comments (Markdown composer)
- Compose new posts: text, link, and image (image uploaded via Reddit's media
  lease + S3 flow), with NSFW / spoiler / reply-notification toggles
- Edit and delete your own posts and comments
- Compose FAB on the frontpage and subreddit screens

## What works (Settings & polish milestone)

- Settings screen (from the Account tab): theme mode (system/light/dark),
  AMOLED black, dynamic color toggle, accent-color swatches, default feed sort,
  NSFW-blur toggle, re-enter credentials, clear all data
- NSFW media is blurred until tapped (when enabled)
- Multi-image galleries are swipeable inline (page dots + counter) and open
  full-screen at the tapped image
- Material 3 outlined cards (subtle hairline borders) across the feeds

## What works (Inbox & messages milestone)

- Inbox tab in the bottom nav with an unread badge
- Tabs: All / Unread / Messages / Sent, with pagination
- Comment replies & mentions open the original post; private messages open a
  chat-style thread with inline replies
- Compose new private messages (also from a user's profile)
- Mark single message read on open, and mark-all-read

## What works (Power-user milestone)

- Post overflow actions: hide, report (with reasons), crosspost, open in browser
- Flair selection when submitting any post type
- Compose posts of every type: text, link, image, **gallery** (multi-image),
  and **video** (with an auto-generated poster frame)
- Giphy GIF picker in the reply/edit composer and the post body
- Multireddit ("custom feed") management: list, create, view feed, add/remove
  subreddits, delete — from the Account tab

## Architecture

- **State management:** Riverpod
- **Networking:** Dio (auth + auto-refresh interceptor, `raw_json=1`)
- **Models:** Freezed (immutable) with hand-written Reddit JSON parsers
- **Auth/secrets:** `flutter_web_auth_2` + `flutter_secure_storage`
- **Navigation:** `go_router` (auth-gated)

Feature-first layout under `lib/`:

```
lib/
  core/        constants, theme, secure storage, dio client, providers
  data/        RedditRepository (all API endpoints)
  models/      Post, Comment, Subreddit, RedditUser, Listing
  features/
    auth/      login screen, OAuth + config validation
    home/      shell (pill nav), frontpage, account tab
    feed/      post list, post card, feed controller
    post/      detail screen, comments controller
    subreddit/ search/ user/ media/
```

## Build & run

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # generates Freezed code
flutter run                # debug on a connected device/emulator
flutter build apk --release
```

> Note: this repo targets the Flutter SDK at the version pinned in
> `pubspec.yaml`. Use the bundled `dart` from your Flutter install for
> `build_runner` if your system `dart` is older.
