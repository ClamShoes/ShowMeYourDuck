# Show me your duck

Godot 4.7 bluffing game based on Skull. Each player has three safe cards and one Duck. First to win two challenges wins.

The `Legacy` folder holds old prototypes — leave it alone. New game files live at the repo root.

## How to play

Multiplayer with room codes (dedicated server). You can start with **1–6** players — solo is for testing the loop without friends.

**Server:** Keep a dedicated Godot process running, then Create / Join with `ws://127.0.0.1:9080`.

Easiest from the editor: click **Create room** — if nothing is listening, the game starts a headless server process for you (a second console window). You can also double-click `run_server.bat` and **leave that window open**.

```
run_server.bat
```

Or:
```
Godot_v4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path . -- --server --port 9080
```

**Clients**

1. Open this folder in Godot 4.7 and Press Play (or run extra client windows with the same project path).
2. Set server URL to `ws://127.0.0.1:9080`.
3. **Create room** (host) or enter a 4-letter code and **Join**.
4. Host starts at **1–6** players (1 is fine for solo testing; with one player a bid locks straight into a self-challenge).
5. Drag a card onto your mat. Bid when you want to challenge. Tap a mat to flip during a reveal.

**Browser:** Editor → Export → **Web** (preset included). Host the `export/web` folder over HTTP, then use the same URL. Pages served as `https://` need `wss://` on the server.

Use the **standard** Godot 4.7 editor (not the .NET build) for Web and Android exports. The game is GDScript-only.

## Android

The app joins the same live server (and the same rooms) as the web build at [showmeyourduck.paff.me](https://showmeyourduck.paff.me/): `LIVE_SERVER_URL` in `scripts/net/net.gd`. Landscape only; the table spreads to fit any phone or tablet shape.

**One-time setup**

1. Editor → Manage Export Templates → **Download and Install** the full 4.7.2 templates (only the web ones are installed right now).
2. Install the Android SDK (Android Studio is easiest; it lands in `%LOCALAPPDATA%\Android\Sdk`). JDK 17 is already set.
3. Editor → Editor Settings → Export → Android: set **Android SDK Path**. The debug keystore is already set.
4. Phone: Settings → About phone → tap Build number 7 times, then Developer options → **USB debugging** on. Plug it in.

**Building**

- Quick test: with the phone plugged in, click the Android button at the top-right of the editor. It installs and runs.
- APK to share: Project → Export → Android → Export Project → `export/android/ShowMeYourDuck.apk`.
- Without a phone: run at phone sizes, e.g. `--resolution 1600x720` (20:9) or `1280x960` (4:3), or take screenshots with
  `Godot_v4.7.2\Godot_v4.7.2-stable_win64_console.exe --path . --resolution 1600x720 --script tests/capture_screens.gd`
  (saved to `%APPDATA%\Godot\app_userdata\Show me your duck\screens`).

**Keeping web and app players together**

`PROTOCOL_VERSION` in `net.gd` must match on the server and every client. Bump it whenever an RPC or snapshot changes, then redeploy the server and web build and ship a new app together. Older apps then show "please update" instead of breaking. Never change `scripts/net/hello.gd`: Godot drops every RPC on a node whose RPC list differs between builds, so the handshake only works if that node stays identical forever. Check with a server running: `... --headless --path . -s res://tests/verify_hello.gd`.

**Play Store (later)**

- Release keystore: `keytool -genkeypair -v -keystore duck-release.keystore -alias duck -keyalg RSA -keysize 2048 -validity 10000`. Back it up; without it you can never update the app. Set it in the preset under Keystore → Release.
- Project → Install Android Build Template, then in the preset turn on **Use Gradle Build** and set the export format to AAB.
- Play Console ($25 once), upload to Internal testing first, bump **Version → Code** every upload.
- Set launcher icons in the preset (192x192 main, 432x432 adaptive foreground + background).
- `package/unique_name` (`com.jake.showmeyourduck`) is permanent once published.

**iOS (later)**: the same code works (it checks the `mobile` feature and the screen safe area). You need a Mac with Xcode, an Apple Developer account, and an iOS export preset; Godot exports an Xcode project to build and sign there.

## Tests

```
Godot_v4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/run_tests.gd
```
