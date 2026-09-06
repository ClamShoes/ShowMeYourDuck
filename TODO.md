# TODO — Card animations (manual)

This file is a guide for adding place / flip / burn animations later.
Nothing here is implemented yet. Do not treat it as a checklist of finished work.

---

## How the game is laid out

```
scenes/
  boot.tscn      → starts lobby or dedicated server
  lobby.tscn     → create/join room
  table.tscn     → the match UI (script does almost everything)

scripts/
  rules/
    types.gd         → phases, Card / Player dictionaries
    game_state.gd    → authoritative rules (no visuals)
  net/
    protocol.gd      → intent dictionaries (place_card, flip, choose_discard)
    net.gd / server.gd → online sync; clients get snapshots
  ui/
    table.gd         → orchestrates mats, hand, bids, clicks
    card_view.gd     → one card in YOUR hand (hover, drag, face/back)
    player_mat.gd    → one seat: name, points, face-down stack tokens
    lobby.gd         → lobby UI
```

**Data flow (important):**

1. Player does something in the UI (`table.gd`).
2. UI sends an **intent** (`protocol.gd`) → Net → server → `GameState.apply_intent`.
3. Rules update; UI gets a **snapshot** and **rebuilds** mats / hand from that state.
4. Visuals live only in `scripts/ui/`. Rules must stay animation-free.

**Phases that matter for these TODOs:**

| Phase | What happens |
|---|---|
| `PLACE_INITIAL` / `PLACE_OR_BID` | Drag from hand onto your mat → `place_card` |
| `REVEAL` | Challenger taps a mat → `flip` |
| `CHOOSE_DISCARD` | Challenger taps a hand card to burn forever → `choose_discard` |

Snapshot already has:

- Per player: `hand_count`, `stack_count`, `points`, …
- Your private hand: `you.hand` (with `id`, `is_duck`, `art_id`)
- `flip_history`: list of recently revealed cards `{ card_id, owner_id, is_duck }`

---

## 1. Place onto pile + show a “played” card in front of the player

**Goal:** When someone plays, the card animates onto their pile. Then a face-down (or face-up-to-owner-only) representation sits in front of that player so everyone at the table can see the stack grow.

**Where it is now:**

- Drop handling: `table.gd` → `_on_card_dropped` → `_submit(place_card)`
- Hand rebuild: `table.gd` → `_layout_hand` (cards kept by `card_id`)
- Stack visuals: `player_mat.gd` → `_rebuild_stack(count)` — only a **count** of anonymous green/teal tokens. No card identity. Snapshots only send `stack_count`, not which cards are on the stack (correct for bluffing).

**How to do it:**

1. **Keep stacks secret in the rules.** Do not put face values of unrevealed stack cards into the public snapshot.
2. In `player_mat.gd`, replace (or enhance) `_rebuild_stack`:
   - Prefer **diffing** tokens when `stack_count` increases by 1 instead of wiping all children every render (same idea as hand persist in `_layout_hand`).
3. On successful place (local: after `_submit` ok; online: when `stack_count` for a player goes up):
   - Spawn a temporary flying card (reuse `CardView` or a thin “token” scene).
   - Tween from hand (or screen center for opponents) to that player’s mat stack slot.
   - On tween finish, leave a face-down token on the mat.
4. For **your own** play, you can briefly show the face mid-flight if you want; opponents’ cards should stay face-down for everyone.
5. Optional: a small “last played” slot in front of each mat (separate from the stacked tokens) that only shows “a card was played” without revealing it.

**Watch out:** `_render` / `_layout_mats` currently rebuilds mats from scratch. Persist mat nodes by `player_id` (like hand cards) or anims will be destroyed mid-flight.

---

## 2. Reveal flip — mouse-drag driven, live on every screen

**Goal:** During `REVEAL`, the challenger click-holds the top card of a legal stack and drags horizontally. Mouse travel maps to the card’s rotation (yaw). At ~90° the face swaps (Duck / Safe). **Other players see the same motion live** while the challenger is still dragging — not only the final result.

**Where it is now:**

- Input is a single click: `table.gd` → `_on_mat_input` → `_submit(flip(pid))`
- Rules resolve the flip **instantly** in `game_state.gd` → `flip_stack` (pop stack, append `flip_history`, score/fail)
- Net only syncs **full snapshots** after intents (`Net.submit_intent` → `s_intent` → `_broadcast_match`). There is no live “animation progress” channel yet.
- No rotation / hold-drag gesture exists.

### Local interaction (challenger)

1. On mouse **press** on a flippable stack token (own stack first, then others — same rules as today):
   - Enter a “revealing” UI state. Do **not** call `flip_stack` yet.
   - Remember `press_x` (or press global mouse x).
2. While **held**, each frame:
   - `delta_x = mouse_x - press_x`
   - Map a fixed horizontal distance to 0°→180° (example: ±120 px screen = full flip). Clamp.
   - Drive card angle (or `scale.x = cos(angle)` for a cheap 2D flip).
   - When angle crosses **90°**, swap visible face (back → Duck/Safe). Before 90°, keep showing the back.
3. On mouse **release**:
   - If angle ≥ 90° (committed): send the real `flip` intent so rules update.
   - If angle < 90° (aborted): tween card back to face-down; no rules change.
4. Optional: once past 90°, snap/finish to 180° on release even if they stop short of full travel.

Tune `PIXELS_PER_HALF_TURN` so the gesture feels deliberate (bluff tension), not twitchy.

### Live sync to other players (required)

Snapshots alone are too slow / too late — they fire **after** the rules flip. For live motion you need a **presentation-only** stream that does not change GameState.

**Suggested protocol** (add beside existing intents in `protocol.gd` / `net.gd`):

| Message | When | Payload (example) |
|---|---|---|
| `reveal_start` | Challenger presses on a stack | `{ target_player_id }` |
| `reveal_progress` | While dragging (throttled) | `{ target_player_id, angle }` or `{ t }` 0→1 |
| `reveal_cancel` | Released before 90° | `{ target_player_id }` |
| Then existing `flip` intent | Released after commit | `{ target_player_id }` as today |

Implementation notes:

1. **Server relays, does not apply to GameState.** e.g. `s_reveal_progress` → broadcast `c_reveal_progress` to peers in the room. Only validate “sender is challenger” and “phase is REVEAL”.
2. **Throttle progress.** Send on a timer (~50–100 ms) or when angle changes by ≥ a few degrees. Use **unreliable** RPC if you add one later; for now reliable is fine if throttled.
3. **Observers:** on `reveal_progress`, rotate the same mat’s top token. Do not show the face until angle ≥ 90°, same as the challenger — but the **server must not send `is_duck` in progress messages**. Face identity is only safe after the committed `flip` intent (or send face at the moment of commit via the normal snapshot / `flip_history`).
4. **Crossing 90° on remote screens:** observers flip to a “revealed but unknown” placeholder **or** wait until the `flip` snapshot arrives to show Duck vs Safe. Cleanest for bluffing: keep back until the authoritative `flip` result arrives, but still rotate toward edge-on so everyone feels the drama; at 90°+ show face only when `flip_history` updates.  
   - Alternative (more theatrical): at commit, include face in the `flip` response immediately so all screens swap face together at ~90° of the local gesture. Progress before commit never includes face.

### Split rules vs presentation

```
Challenger input → UI angle (local)
                 → reveal_progress RPCs → other UIs set angle
Release ≥ 90°    → flip intent → GameState.flip_stack → snapshot (truth)
Release < 90°    → reveal_cancel RPC → everyone resets token
```

Do **not** put mouse sampling or tweens in `game_state.gd`. Keep `flip_stack` as the single moment the pile actually loses a card and scoring happens.

### UI pieces to add

- A “revealable” top token on `PlayerMat` that can set `reveal_angle` / `set_reveal_t(t)`.
- Gesture state machine in `table.gd` (or a small `reveal_gesture.gd`): idle → dragging → committed / cancelled.
- Replace instant `_on_mat_input` flip submit with press/drag/release as above.
- Persist mats across `_render` so in-flight reveal nodes are not destroyed when other state fields update.

**Skulldicks note:** Old project never finished flip. Build this on the new mat tokens + face/back panels.

---

## 3. Burn animation (permanent discard)

**Goal:** When the challenger must lose a card (`CHOOSE_DISCARD` after their own Duck, or after a random discard of someone else’s Duck), play a “burn / rip / dissolve” animation.

**Where it is now:**

- Own Duck → phase `CHOOSE_DISCARD` → tap hand card → `table.gd` `_on_card_pressed` → `choose_discard`
- Other Duck → rules call `_remove_card_forever` with a **random** hand card (no UI pick). Card vanishes on next hand rebuild.
- Assets already copied: `assets/cardripFX_spritesheet.png` (from Skulldicks) — good candidate for burn FX.

**How to do it:**

1. Add `CardView.play_burn() -> Signal` (or a one-shot FX node):
   - e.g. play rip spritesheet / shrink + fade / particle burst, then `queue_free`.
2. **Chosen burn (own Duck):**
   - On press in `CHOOSE_DISCARD`, play burn on that `CardView` **before** or **while** submitting `choose_discard`.
   - Don’t rebuild the hand until the anim finishes (defer `_layout_hand` or keep the burning node out of the clear list).
3. **Random burn (other’s Duck):**
   - Snapshot won’t tell clients *which* card was removed unless you add a private event.
   - Minimal approach: if your `hand_count` dropped and phase advanced after a failed challenge, flash a burn FX over the hand area or a generic “you lost a card” overlay without naming the card (rules say only the loser knows).
   - Better approach later: add a private snapshot field / event `{ burned_card_id }` only for the affected player.
4. Wire FX to `assets/cardripFX_spritesheet.png` when you are ready for art; until then a scale-down + modulate tween is enough.

---

## Suggested order when you implement

1. Persist `PlayerMat` instances by `player_id` (stops anims dying every render).
2. Place-to-pile flight + stack token grow.
3. Mouse-drag reveal gesture locally (angle from horizontal mouse travel; commit at 90°).
4. Live `reveal_start` / `reveal_progress` / `reveal_cancel` relay + observer angle; commit with existing `flip` intent.
5. Burn on `choose_discard` + optional private burn event for random discards.

## Do not

- Put animation waits or mouse sampling inside `game_state.gd`.
- Reveal unrevealed stack card faces in the public snapshot **or** in `reveal_progress` messages.
- Resolve scoring/`flip_history` before the challenger commits past 90°.
- Edit the plan file under `.cursor/plans/` for this work — use this `TODO.md` instead.
