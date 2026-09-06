# Show me your duck

Godot 4.3 bluffing game based on Skull. Each player has three safe cards and one Duck. First to win two challenges wins.

The Skulldicks folder is the old prototype — leave it alone. New game files live at the repo root.

## How to play

Multiplayer with room codes (dedicated server). You can start with **1–6** players — solo is for testing the loop without friends.

**Server:** Keep a dedicated Godot process running, then Create / Join with `ws://127.0.0.1:9080`.

Easiest from the editor: click **Create room** — if nothing is listening, the game starts a headless server process for you (a second console window). You can also double-click `run_server.bat` and **leave that window open**.

```
run_server.bat
```

Or:
```
"C:\Godot\Godot_v4.3-stable_mono_win64\Godot_v4.3-stable_mono_win64_console.exe" --headless --path . -- --server --port 9080
```

**Clients**

1. Open this folder in Godot 4.3 and Press Play (or run extra client windows with the same project path).
2. Set server URL to `ws://127.0.0.1:9080`.
3. **Create room** (host) or enter a 4-letter code and **Join**.
4. Host starts at **1–6** players (1 is fine for solo testing; with one player a bid locks straight into a self-challenge).
5. Drag a card onto your mat. Bid when you want to challenge. Tap a mat to flip during a reveal.

**Browser:** Editor → Export → **Web** (preset included). Host the `export/web` folder over HTTP, then use the same URL. Pages served as `https://` need `wss://` on the server.

Web export needs the **standard** Godot 4.3 editor (not the .NET/Mono build). This machine’s `Godot_v4.3-stable_mono_win64` cannot export HTML5. The game is GDScript-only, so either editor can **play** it; only the non-.NET build can **export Web**. Download 4.3-stable win64 from [godotengine.org](https://godotengine.org/download/archive/4.3-stable/) and use Editor → Manage Export Templates, then Export → Web.

## Tests

```
Godot_v4.3-stable_mono_win64_console.exe --headless --path . -s res://tests/run_tests.gd
```
