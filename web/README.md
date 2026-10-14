# VolleyballScore — Web Watch Viewer

This is a **standalone web page** (no app install needed) that shows the same live
score the app's own "Watch" tab shows, by reading directly from Apple's CloudKit
public database using [CloudKit JS](https://developer.apple.com/documentation/cloudkitjs).

Anyone with the 6-character join code can open this page in any browser (desktop or
mobile) and watch the score update automatically — no sign-in required.

## One-time setup (you only need to do this once)

### 1. Decide which CloudKit environment to use
- If scorekeepers are currently running the app from **Xcode** (debug builds) or a
  **TestFlight build uploaded straight from Xcode**, use CloudKit environment
  **Development**.
- If scorekeepers are using a build from **TestFlight via App Store Connect** or the
  **public App Store**, use **Production**.
- Whatever you pick must match what the scorekeeper's app build actually uses — the
  live match row only exists in that one environment.

### 2. Create a CloudKit Web Services API Token
1. Go to [developer.apple.com → CloudKit Database](https://icloud.developer.apple.com/dashboard/).
2. Select the container **`iCloud.com.francesl.volleyballscore`**.
3. Switch to the environment you chose in step 1 (Development or Production — top of
   the page).
4. Open **API Access** (left sidebar) → **Tokens** → **Add API Token** (choose the
   "Client" / user-facing token type, not a server-to-server key).
5. Under **Allowed Origins**, add the exact origin where you'll host this page, for
   example:
   ```
   https://francessmli.github.io
   ```
   (scheme + host only, no path, no trailing slash). You can add `http://localhost:*`
   too if you want to test locally first.
6. Save, then copy the generated token (looks like a long string of letters/numbers).

### 3. Allow public (signed-out) read access
This page does **not** ask visitors to sign in with their Apple ID — it reads the
public database anonymously, the same way the app's spectators already do.
1. In the same container/environment: **Schema → Security Roles**.
2. Select the **World** role (this is what applies to anonymous/unauthenticated
   readers).
3. For record type **`VolleyballLiveSession`**, make sure **Read** is checked.
   (This is the same permission already required for the iOS app's "Watch" tab to
   work, so if that's working today, this step is likely already done.)

### 4. Fill in `index.html`
Open `web/index.html` and edit the three constants near the top of the `<script>`
block at the bottom of the file:

```js
var CONTAINER_IDENTIFIER = "iCloud.com.francesl.volleyballscore"; // already correct
var ENVIRONMENT = "production"; // or "development" — must match step 1
var API_TOKEN = "YOUR_API_TOKEN_HERE"; // paste the token from step 2
```

### 5. Host it
Easiest option — **GitHub Pages**, using the same repo this project already lives in:
1. Push this `web/` folder to GitHub (already done if you're reading this from the repo).
2. Repo → **Settings → Pages** → Source: **Deploy from a branch** → Branch **main**,
   folder **/ (root)** (or `/web` if GitHub offers a folder picker for your plan).
3. Your page will be live at something like:
   ```
   https://francessmli.github.io/volleyballscorestream/web/
   ```

### 6. (Optional) Let the app share a direct link
In the app's **Settings** tab, there's a **"Web watch link"** field — paste the full
URL from step 5 there. After that, the "Broadcast for spectators" sheet will offer a
**"Share watch link"** button that shares a ready-to-tap URL like:
```
https://francessmli.github.io/volleyballscorestream/web/?code=AB12CD
```
Opening that link auto-fills the code and starts watching immediately — no typing
required.

## Testing it
1. In the app, start broadcasting a match and note the 6-character code.
2. Open your hosted page (or `web/index.html` directly in a browser for a quick local
   test, though CloudKit JS requires it be served over `http://` or `https://`, not
   `file://` — use e.g. `python3 -m http.server` in this folder for local testing).
3. Enter the code and tap **Watch**. The score should appear within a couple seconds
   and keep updating as the scorekeeper scores points.

## Troubleshooting
- **"This page isn't configured yet"** — you haven't pasted a real API token into
  `index.html` yet (step 4).
- **"No live match found for that code"** — confirm: (a) the scorekeeper is still
  actively broadcasting, (b) `ENVIRONMENT` in `index.html` matches the environment
  their app build actually uses (step 1), (c) the code was typed correctly.
- **Network/CORS error in the browser console** — the page's origin isn't in the
  API token's **Allowed Origins** list (step 2.5). Add the exact origin you're
  loading the page from and re-check for typos (http vs https, trailing slash, etc).
- **"Not authorized" / permission error** — the **World** security role doesn't have
  Read access to `VolleyballLiveSession` yet in this environment (step 3).
