a# App Store Connect — "App Privacy" questionnaire cheat sheet

This is the separate web form in **App Store Connect → [Your App] → App Privacy**
(different from the `PrivacyInfo.xcprivacy` file already bundled in the app, and
different from the hosted privacy policy page). Answer it like this:

## "Do you or your third-party partners collect data from this app?"
**Yes** — because match data is linked to the user's iCloud account for sync, and
the live-broadcast feature writes data to a public database.

## Data types to declare

| Data type | Collected? | Linked to user? | Used for tracking? | Purpose |
|---|---|---|---|---|
| **User Content → Other User Content** (match history: team names, scores, sets) | Yes | Yes (via iCloud account) | No | App Functionality |
| **Identifiers → Device ID** (random UUID for the "viewers watching" heartbeat, stored locally, not tied to Apple ID) | Yes | No | No | App Functionality |

Leave every other category (Contact Info, Health, Financial Info, Location,
Browsing History, Search History, Purchases, Usage Data, Diagnostics, etc.)
**unchecked / "Data Not Collected"** — none of it applies to this app.

## Key answers within each data type's follow-up questions
- "Is this data used for tracking purposes (as defined by Apple)?" → **No**, for both rows.
- "Is this data linked to the user's identity?":
  - Match history row → **Yes** (iCloud account makes it linked, even though only
    the user themselves can access it).
  - Device ID row → **No** (it's a random local identifier, not tied to an account).
- "Purpose": **App Functionality** for both (never "Analytics", "Advertising",
  "Third-Party Advertising", or "Marketing").

## Why this is accurate
- SwiftData + CloudKit private database → match history syncs to *the user's own*
  iCloud, nobody else can read it, and the developer has no server collecting it —
  but Apple's framework still classifies it as "linked" data since it's tied to
  the user's account.
- The live-viewer heartbeat uses `UUID()` stored in `UserDefaults`, not an Apple ID
  or email, and is only used to show an approximate count — not tracking.

## If you later add anything new (e.g. crash reporting, analytics SDK, ads)
Come back and update both this questionnaire **and** `PrivacyInfo.xcprivacy` to
match — mismatches between the two are a common cause of App Review rejection.
