# App Review Information — paste into App Store Connect

Paste the text below into **App Store Connect → [Your App] → [Version] → App Review Information → Notes**.
It preempts the two things reviewers most commonly flag for this kind of app: the public
CloudKit database usage, and the WhatsApp share action.

---

VolleyballScore is a volleyball scorekeeping app with three main features:

1. SCORING — Users enter team names and tap/swipe to track points and sets for a
   live match. Completed matches are saved to History using SwiftData, synced only
   to the signed-in user's own iCloud account (CloudKit private database). No
   sign-up or account creation is required to use the app.

2. LIVE BROADCAST ("Watch" tab) — A scorekeeper can optionally generate a random
   6-character join code and tap "Broadcast for spectators." This writes the
   current score to Apple's CloudKit PUBLIC database, keyed only by that join code
   (not by any personal identifier). Up to this point, no login/account is
   required on either side:
     - The scorekeeper taps "Broadcast for spectators…" from the score screen menu
       and taps "Start broadcasting."
     - A spectator opens the "Watch" tab, enters the same 6-character code, and
       taps "Watch" to see the score update automatically every few seconds.
   To test this feature during review:
     - Open the app on two simulators/devices (or reviewer may use one device
       twice, since there is no login — any device can be either role).
     - On device A: Score tab → start a new match → tap the "…" menu (top-right)
       → "Broadcast for spectators…" → "Start broadcasting." Note the 6-character
       code shown.
     - On device B: Watch tab → type in the same code → tap "Watch." The live
       score from device A should appear within a few seconds and update as
       device A's score changes.
   There is no inappropriate or user-generated content risk here: the only data
   shown is team names (typed by the scorekeeper) and numeric scores.

3. WHATSAPP SHARE (optional, off by default) — A menu option and a Settings
   toggle let the user share a plain-text score summary via WhatsApp. This only
   opens WhatsApp (or wa.me) with a pre-filled message; the user must manually
   tap Send inside WhatsApp. The app does not read contacts and cannot send
   messages without explicit user action in WhatsApp itself. If WhatsApp is not
   installed, the request is simply ignored (no crash).

No account creation, login, or payment is required anywhere in the app. The app
requires an iCloud-signed-in device to use History sync, Watch, or Broadcast —
if iCloud is unavailable, the app shows a clear in-app message explaining this
rather than crashing or silently failing.

Privacy Policy: REPLACE_WITH_YOUR_HOSTED_PRIVACY_POLICY_URL
Support contact: REPLACE_WITH_YOUR_SUPPORT_EMAIL

---

## Other reminders for this submission (not for reviewer notes — for you)

- [ ] Replace both REPLACE_WITH_* placeholders above before pasting.
- [ ] Host `privacy-policy.html` (e.g. GitHub Pages) and put that URL in both:
      App Store Connect → App Privacy → Privacy Policy URL, AND the notes above.
- [ ] CloudKit Dashboard → Deploy Schema Changes to Production (VolleyballLiveSession
      + VolleyballLiveViewer, with the joinCode queryable index) BEFORE submitting,
      or the Watch/Broadcast features will not work for real App Store users even
      though they work fine in Development/TestFlight-from-Xcode.
- [ ] Test the two-device Watch/Broadcast flow on the Production CloudKit
      environment at least once (e.g. via a TestFlight build from App Store Connect,
      not an Xcode debug run) before release.
