# Peekaboo 🍼🔒

Privately share your baby's photos through a **protected viewer**. Photos are
never delivered as files — recipients open a **watermarked, in-app link**, so
they can be sent through WhatsApp / Messenger / Instagram DM but **cannot be
posted to a Facebook / Instagram / TikTok feed or story**.

One Flutter codebase → **Web (PWA) + Android + iOS**.

---

## The security model in one line

> **We share a *link*, never a *file*.** Whoever holds the pixels controls the
> pixels — so the pixels never leave a surface we control.

| Goal | How it's achieved | Strength |
| --- | --- | --- |
| Shareable via messaging DMs | A tokenized link (`/#/v/<token>`) sent through WhatsApp/Telegram/etc. | ✅ Full |
| Not postable to feeds/stories | Feeds/stories can't ingest a link — there's no file to upload | ✅ Full (by construction) |
| No screenshots | Android `FLAG_SECURE` blocks; iOS detects + blurs + notifies; web can't | ⚠️ Android ✅ / iOS detect-only / Web none |
| Trace leaks (2nd-camera attack) | Per-recipient **watermark** stamped over every view | ✅ Deterrent everywhere |

Honest limits: **no app on any platform can stop a second camera**, and **iOS
cannot block screenshots at all** (Apple has no API) — hence watermark + detect.

---

## Architecture

```
lib/
  main.dart                     app entry; starts iOS screenshot listener
  app.dart                      MaterialApp + routing (parses /#/v/<token>)
  theme/app_theme.dart          "nursery at night" dark palette
  models/
    photo.dart                  a protected photo (bytes stay in memory)
    share_link.dart             per-recipient token (expiry / view-once)
  data/vault.dart               store + backend seam (see below)
  services/
    screen_protection.dart      MethodChannel bridge to native defenses
    share_service.dart          builds link + opens WhatsApp/Telegram/system
  screens/
    gallery_screen.dart         owner's private vault (add / share / delete)
    protected_viewer_screen.dart full-screen viewer + watermark + protection
    recipient_screen.dart       what a shared link opens to
    share_sheet.dart            create-link + pick-messaging-app sheet
  widgets/watermark_overlay.dart tiled diagonal traceable watermark

android/.../MainActivity.kt      FLAG_SECURE toggle (blocks screenshots)
ios/Runner/AppDelegate.swift     screenshot detection -> Flutter
```

### What's real vs. mocked

- **Real & working now:** UI, routing, screenshot blocking (Android) /
  detection (iOS) via a hand-written `MethodChannel` (no plugin), watermark
  overlay, link generation, share-to-app deep links, view-once/expiry logic.
- **Mocked:** storage. `data/vault.dart` keeps photos **in memory**. Every
  method there maps 1:1 to a backend call — that's the only file you rewrite to
  go live.

---

## Run it

```bash
flutter pub get
flutter run -d chrome                    # web / PWA
flutter run -d <android-device-id>       # Android (real screenshot blocking)
```

> Uses the **HTML web renderer** (see `.claude/launch.json`) — lighter than
> CanvasKit and better for a mobile PWA.

---

## Going to production (the ~$0 path)

1. **Backend — Supabase free tier.** Create a project, a private `photos`
   Storage bucket, and `photos` / `shares` tables with Row-Level Security.
   Replace the bodies in `data/vault.dart`:
   - `addPhoto`   → upload bytes to the bucket + insert a row
   - `createShare`→ insert a `shares` row; token = a short-lived **signed URL**
   - `photoForToken` → validate token, stream decoded bytes back
2. **Host the web build — free.** `flutter build web --web-renderer html` then
   deploy `build/web` to Cloudflare Pages / Netlify / Firebase Hosting (all
   free). iPhone users "Add to Home Screen" → installs as the Peekaboo PWA, $0.
3. **Android app — free.** `flutter build apk` and sideload to family, or $25
   one-time for Google Play.
4. **iOS app — only if you want screenshot *detection* + push.** Needs the
   Apple Developer Program (~$99/yr). The PWA already covers iPhones for free.
5. **Set a real bundle id** before publishing (currently
   `com.example.secure_baby_photos`) → e.g. `com.peekaboo.app`.
6. **Deep links (native).** Add App Links (Android) / Universal Links (iOS) for
   your domain so a tapped link opens the installed app instead of the browser.

### Nice next features
- Server-side forensic watermarking (tamper-proof) via a Supabase Edge Function
- Revoke access / "who viewed" log
- Screenshot push-notification to the sender ("Grandma screenshotted Emma")
