extends SceneTree

const GameStateScript = preload("res://scripts/rules/game_state.gd")
const GameTypes = preload("res://scripts/rules/types.gd")
const DuckServerScript = preload("res://scripts/net/server.gd")
const CardCatalog = preload("res://scripts/ui/card_catalog.gd")
const CardArt = preload("res://scripts/ui/card_art.gd")
const CardScene = preload("res://scenes/card.tscn")
const PlayerMatScript = preload("res://scripts/ui/player_mat.gd")
const DuckDrawing = preload("res://scripts/ui/duck_drawing.gd")
const PlayerCosmetics = preload("res://scripts/ui/player_cosmetics.gd")
const DiscardFxScript = preload("res://scripts/ui/discard_fx.gd")
const StatusTextScript = preload("res://scripts/ui/status_text.gd")
const DuckStamps = preload("res://scripts/ui/duck_stamps.gd")
const SeatSpace = preload("res://scripts/ui/seat_space.gd")
const ScreenFit = preload("res://scripts/ui/screen_fit.gd")

var _failed := 0
var _passed := 0


func _init() -> void:
	_run("start_match_deals_three_safe_and_one_duck", test_start_match_deals_three_safe_and_one_duck)
	_run("start_match_rejects_too_few_players", test_start_match_rejects_too_few_players)
	_run("solo_playthrough_scores_and_survives_own_duck", test_solo_playthrough_scores_and_survives_own_duck)
	_run("initial_place_is_one_card_each_then_place_or_bid", test_initial_place_is_one_card_each_then_place_or_bid)
	_run("cannot_place_off_turn", test_cannot_place_off_turn)
	_run("simultaneous_initial_place", test_simultaneous_initial_place)
	_run("cannot_place_two_initial_cards", test_cannot_place_two_initial_cards)
	_run("open_bid_locks_further_placement", test_open_bid_locks_further_placement)
	_run("empty_hand_must_bid", test_empty_hand_must_bid)
	_run("raise_or_pass_until_one_challenger", test_raise_or_pass_until_one_challenger)
	_run("must_flip_own_stack_first", test_must_flip_own_stack_first)
	_run("own_duck_lets_challenger_choose_discard", test_own_duck_lets_challenger_choose_discard)
	_run("other_duck_owner_picks_discard", test_other_duck_owner_picks_discard)
	_run("flipped_cards_keep_challenger_in", test_flipped_cards_keep_challenger_in)
	_run("own_duck_all_flipped_uses_pick_row", test_own_duck_all_flipped_uses_pick_row)
	_run("discard_pick_snapshot_secrecy", test_discard_pick_snapshot_secrecy)
	_run("server_discard_hover_relay_requires_chooser", test_server_discard_hover_relay_requires_chooser)
	_run("discard_event_public_hides_card", test_discard_event_public_hides_card)
	_run("choose_discard_emits_event", test_choose_discard_emits_event)
	_run("stamp_offers_exclude_earned", test_stamp_offers_exclude_earned)
	_run("pick_style_fresh_then_random", test_pick_style_fresh_then_random)
	_run("other_duck_pick_grants_upgrade_own_duck_does_not", test_other_duck_pick_grants_upgrade_own_duck_does_not)
	_run("discard_style_uses_duck_owner_powers", test_discard_style_uses_duck_owner_powers)
	_run("apply_duck_upgrade_validates_offer", test_apply_duck_upgrade_validates_offer)
	_run("server_duck_upgrade_updates_peer_and_rev", test_server_duck_upgrade_updates_peer_and_rev)
	_run("duck_stamps_bake_places_rotated_stamp", test_duck_stamps_bake_places_rotated_stamp)
	_run("duck_stamps_bake_flips_horizontally", test_duck_stamps_bake_flips_horizontally)
	_run("profile_progress_round_trips_and_editor_clears", test_profile_progress_round_trips_and_editor_clears)
	_run("safe_flips_score_a_point", test_safe_flips_score_a_point)
	_run("two_points_wins", test_two_points_wins)
	_run("last_card_eliminates_and_last_player_wins", test_last_card_eliminates_and_last_player_wins)
	_run("private_snapshot_hides_other_hands", test_private_snapshot_hides_other_hands)
	_run("server_create_and_join_room", test_server_create_and_join_room)
	_run("server_rejects_unknown_code", test_server_rejects_unknown_code)
	_run("server_start_requires_host_allows_one", test_server_start_requires_host_allows_one)
	_run("server_min_players_flag", test_server_min_players_flag)
	_run("server_return_to_lobby", test_server_return_to_lobby)
	_run("server_set_display_name", test_server_set_display_name)
	_run("server_reveal_relay_requires_challenger", test_server_reveal_relay_requires_challenger)
	_run("server_sanitizes_cosmetics", test_server_sanitizes_cosmetics)
	_run("snapshot_carries_cosmetics", test_snapshot_carries_cosmetics)
	_run("card_art_duck_and_safe_faces_differ", test_card_art_duck_and_safe_faces_differ)
	_run("unrevealed_token_uses_blank_face", test_unrevealed_token_uses_blank_face)
	_run("stack_fan_is_even_and_fits_mat", test_stack_fan_is_even_and_fits_mat)
	_run("reveal_rows_fit_screen_and_clear_stack", test_reveal_rows_fit_screen_and_clear_stack)
	_run("seats_clear_hand_on_every_screen", test_seats_clear_hand_on_every_screen)
	_run("duck_drawing_decode_validates", test_duck_drawing_decode_validates)
	_run("server_duck_drawing_lobby_only_and_in_snapshot", test_server_duck_drawing_lobby_only_and_in_snapshot)
	_run("card_art_uses_custom_duck_for_matching_rev", test_card_art_uses_custom_duck_for_matching_rev)
	_run("card_art_new_drawing_same_rev_replaces_cache", test_card_art_new_drawing_same_rev_replaces_cache)
	_run("profile_name_round_trips", test_profile_name_round_trips)
	_run("status_text_is_per_viewer", test_status_text_is_per_viewer)
	_run("seat_space_round_trips_between_viewers", test_seat_space_round_trips_between_viewers)
	_run("reparent_keep_pose_keeps_seat_angle_and_scale", test_reparent_keep_pose_keeps_seat_angle_and_scale)
	_run("cursor_mapping_is_continuous", test_cursor_mapping_is_continuous)
	_run("server_hand_fx_relay_validates", test_server_hand_fx_relay_validates)
	_run("server_cursor_relay_validates", test_server_cursor_relay_validates)
	print("\n%d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _run(test_name: String, fn: Callable) -> void:
	var err: Variant = fn.call()
	if err == null or str(err) == "":
		_passed += 1
		print("PASS  ", test_name)
	else:
		_failed += 1
		print("FAIL  ", test_name, " — ", err)


func _game(n: int, seed: int = 1) -> RefCounted:
	var gs = GameStateScript.new()
	gs.rng = RandomNumberGenerator.new()
	gs.rng.seed = seed
	var infos: Array = []
	for i in n:
		infos.append({"id": "p%d" % i, "name": "P%d" % i})
	var result: Dictionary = gs.start_match(infos, "p0")
	if not result.get("ok", false):
		push_error(result.get("error", "start_match failed"))
	return gs


func _card_of(gs: RefCounted, player_id: String, want_duck: bool) -> String:
	var player: Dictionary = gs.players[player_id]
	for cid in player.hand:
		if gs.cards[cid].is_duck == want_duck:
			return String(cid)
	return ""


func _place_initial(gs: RefCounted, player_id: String, want_duck: bool = false) -> Dictionary:
	var cid := _card_of(gs, player_id, want_duck)
	if cid == "":
		cid = String(gs.players[player_id].hand[0])
	return gs.place_card(player_id, cid)


func _place_all_initial_safe(gs: RefCounted) -> String:
	for pid in gs.player_order:
		if gs.players[pid].placed_initial:
			continue
		var r := _place_initial(gs, String(pid), false)
		if not r.ok:
			return r.error
	return ""


func _everyone_pass_except_bidder(gs: RefCounted) -> String:
	var guard := 0
	while gs.phase == GameTypes.Phase.BIDDING and guard < 12:
		guard += 1
		if gs.current_player_id == gs.current_bidder_id:
			return "bidder should not need to act if others pass"
		var r: Dictionary = gs.pass_bid(gs.current_player_id)
		if not r.ok:
			return r.error
	return ""


func test_start_match_deals_three_safe_and_one_duck() -> String:
	var gs := _game(3)
	if gs.phase != GameTypes.Phase.PLACE_INITIAL:
		return "expected PLACE_INITIAL"
	for pid in gs.player_order:
		var p: Dictionary = gs.players[pid]
		if p.hand.size() != 4:
			return "expected 4 cards in hand"
		var ducks := 0
		var safes := 0
		for cid in p.hand:
			if gs.cards[cid].is_duck:
				ducks += 1
			else:
				safes += 1
		if ducks != 1 or safes != 3:
			return "expected 3 safe + 1 duck, got %s/%s" % [safes, ducks]
		if gs.cards[p.hand[0]].has("rank") or gs.cards[p.hand[0]].has("suit"):
			return "cards must not use rank/suit"
	return ""


func test_start_match_rejects_too_few_players() -> String:
	var gs = GameStateScript.new()
	var empty: Dictionary = gs.start_match([], "")
	if empty.get("ok", false):
		return "0 players should be rejected"
	var one: Dictionary = gs.start_match([{"id": "a", "name": "A"}], "a")
	if not one.get("ok", false):
		return one.get("error", "1 player should be allowed")
	var two: Dictionary = gs.start_match([
		{"id": "a", "name": "A"},
		{"id": "b", "name": "B"},
	], "a")
	if not two.get("ok", false):
		return two.get("error", "2 players should be allowed")
	return ""


func test_solo_playthrough_scores_and_survives_own_duck() -> String:
	var gs := _game(1)
	var r: Dictionary = _place_initial(gs, "p0", false)
	if not r.ok:
		return r.error
	if gs.phase != GameTypes.Phase.PLACE_OR_BID:
		return "solo opening place should unlock PLACE_OR_BID"
	r = gs.open_bid("p0", 1)
	if not r.ok:
		return r.error
	if gs.phase != GameTypes.Phase.REVEAL:
		return "solo bid should skip to REVEAL, got phase %s" % gs.phase
	if gs.challenger_id != "p0":
		return "solo bidder should be challenger"
	r = gs.flip_stack("p0", "p0")
	if not r.ok:
		return r.error
	if gs.players["p0"].points != 1:
		return "safe solo challenge should score 1 point"
	if gs.phase != GameTypes.Phase.ROUND_OVER:
		return "expected ROUND_OVER after scoring, got %s" % gs.phase
	if gs.flip_history.is_empty():
		return "solo reveal should remain in flip_history until Next round"
	r = gs.next_round("p0")
	if not r.ok:
		return r.error
	if gs.phase != GameTypes.Phase.PLACE_INITIAL:
		return "next hand should start after Next round"
	if not gs.flip_history.is_empty():
		return "flip_history should clear on Next round"
	# Own Duck must not end a solo match (last-player-standing only for multi-seat tables).
	r = _place_initial(gs, "p0", true)
	if not r.ok:
		return r.error
	r = gs.open_bid("p0", 1)
	if not r.ok:
		return r.error
	r = gs.flip_stack("p0", "p0")
	if not r.ok:
		return r.error
	if gs.phase != GameTypes.Phase.CHOOSE_DISCARD:
		return "expected CHOOSE_DISCARD after own duck"
	var discard_id: String = String(gs.players["p0"].hand[0])
	r = gs.choose_discard("p0", discard_id)
	if not r.ok:
		return r.error
	if gs.phase == GameTypes.Phase.GAME_OVER:
		return "solo own-duck discard must not end the game"
	if gs.phase != GameTypes.Phase.ROUND_OVER:
		return "expected ROUND_OVER after duck discard"
	r = gs.next_round("p0")
	if not r.ok:
		return r.error
	if gs.phase != GameTypes.Phase.PLACE_INITIAL:
		return "solo should continue with a new hand after Next round"
	if gs.players["p0"].points != 1:
		return "points should still be 1 after failed challenge"
	return ""


func test_initial_place_is_one_card_each_then_place_or_bid() -> String:
	var gs := _game(3)
	var err := _place_all_initial_safe(gs)
	if err != "":
		return err
	if gs.phase != GameTypes.Phase.PLACE_OR_BID:
		return "expected PLACE_OR_BID after one each"
	if gs.current_player_id != "p0":
		return "hand starter should act first in PLACE_OR_BID"
	for pid in gs.player_order:
		if gs.players[pid].stack.size() != 1:
			return "each stack should have exactly 1"
	return ""


func test_cannot_place_off_turn() -> String:
	var gs := _game(3)
	var err := _place_all_initial_safe(gs)
	if err != "":
		return err
	# After opening cards, PLACE_OR_BID is turn-based — p1 cannot place on p0's turn.
	var cid := _card_of(gs, "p1", false)
	var r: Dictionary = gs.place_card("p1", cid)
	if r.get("ok", false):
		return "p1 should not place on p0's turn during PLACE_OR_BID"
	return ""


func test_simultaneous_initial_place() -> String:
	var gs := _game(3)
	# p1 and p2 can place before p0 during PLACE_INITIAL.
	var r: Dictionary = _place_initial(gs, "p2", false)
	if not r.ok:
		return r.error
	r = _place_initial(gs, "p1", false)
	if not r.ok:
		return r.error
	if gs.phase != GameTypes.Phase.PLACE_INITIAL:
		return "still waiting on p0"
	r = _place_initial(gs, "p0", false)
	if not r.ok:
		return r.error
	if gs.phase != GameTypes.Phase.PLACE_OR_BID:
		return "expected PLACE_OR_BID after everyone placed"
	return ""


func test_cannot_place_two_initial_cards() -> String:
	var gs := _game(3)
	var r: Dictionary = _place_initial(gs, "p0", false)
	if not r.ok:
		return r.error
	r = _place_initial(gs, "p0", false)
	if r.get("ok", false):
		return "p0 should not place a second opening card"
	return ""


func test_open_bid_locks_further_placement() -> String:
	var gs := _game(3)
	var err := _place_all_initial_safe(gs)
	if err != "":
		return err
	var r: Dictionary = gs.open_bid("p0", 1)
	if not r.ok:
		return r.error
	if gs.phase != GameTypes.Phase.BIDDING:
		return "expected BIDDING"
	var cid := _card_of(gs, "p1", false)
	var place: Dictionary = gs.place_card("p1", cid)
	if place.get("ok", false):
		return "should not place after bidding opens"
	return ""


func test_empty_hand_must_bid() -> String:
	var gs := _game(3)
	var err := _place_all_initial_safe(gs)
	if err != "":
		return err
	var guard := 0
	while guard < 24 and not (gs.current_player_id == "p0" and gs.players["p0"].hand.size() == 0):
		guard += 1
		var pid: String = gs.current_player_id
		if gs.players[pid].hand.is_empty():
			return "unexpected empty hand for %s" % pid
		var cid: String = String(gs.players[pid].hand[0])
		var r: Dictionary = gs.place_card(pid, cid)
		if not r.ok:
			return r.error
	if gs.players["p0"].hand.size() != 0:
		return "p0 hand should be empty"
	if gs.current_player_id != "p0":
		return "turn should be p0"
	var place: Dictionary = gs.place_card("p0", "missing")
	if place.get("ok", false):
		return "empty hand must not place"
	var bid: Dictionary = gs.open_bid("p0", 1)
	if not bid.ok:
		return bid.error
	return ""


func test_raise_or_pass_until_one_challenger() -> String:
	var gs := _game(3)
	var err := _place_all_initial_safe(gs)
	if err != "":
		return err
	var r: Dictionary = gs.open_bid("p0", 1)
	if not r.ok:
		return r.error
	r = gs.raise_bid("p1", 2)
	if not r.ok:
		return r.error
	r = gs.pass_bid("p2")
	if not r.ok:
		return r.error
	r = gs.pass_bid("p0")
	if not r.ok:
		return r.error
	if gs.phase != GameTypes.Phase.REVEAL:
		return "expected REVEAL, got %s" % gs.phase
	if gs.challenger_id != "p1":
		return "p1 should be challenger"
	if gs.flips_remaining != 2:
		return "bid should be 2"
	return ""


func test_must_flip_own_stack_first() -> String:
	var gs := _game(3)
	var err := _place_all_initial_safe(gs)
	if err != "":
		return err
	gs.open_bid("p0", 1)
	err = _everyone_pass_except_bidder(gs)
	if err != "":
		return err
	var r: Dictionary = gs.flip_stack("p0", "p1")
	if r.get("ok", false):
		return "should not flip others before own stack"
	r = gs.flip_stack("p0", "p0")
	if not r.ok:
		return r.error
	return ""


func test_own_duck_lets_challenger_choose_discard() -> String:
	var gs := _game(3)
	var r := _place_initial(gs, "p0", true) # p0 duck
	if not r.ok:
		return r.error
	for pid in gs.player_order:
		if gs.players[pid].placed_initial:
			continue
		r = _place_initial(gs, String(pid), false)
		if not r.ok:
			return r.error
	r = gs.open_bid("p0", 1)
	if not r.ok:
		return r.error
	var err := _everyone_pass_except_bidder(gs)
	if err != "":
		return err
	r = gs.flip_stack("p0", "p0")
	if not r.ok:
		return r.error
	if gs.phase != GameTypes.Phase.CHOOSE_DISCARD:
		return "expected CHOOSE_DISCARD after own duck, got %s" % gs.phase
	var before: int = gs.players["p0"].hand.size()
	var discard_id: String = String(gs.players["p0"].hand[0])
	r = gs.choose_discard("p0", discard_id)
	if not r.ok:
		return r.error
	if gs.players["p0"].hand.size() != before - 1:
		return "challenger should lose one card"
	if gs.phase != GameTypes.Phase.ROUND_OVER:
		return "expected ROUND_OVER after duck discard"
	if gs.next_hand_starter_id != "p0":
		return "challenger should be next-hand starter"
	r = gs.next_round("p0")
	if not r.ok:
		return r.error
	if gs.phase != GameTypes.Phase.PLACE_INITIAL:
		return "next hand should start after Next round"
	if gs.hand_starter_id != "p0":
		return "challenger starts next hand"
	return ""


## p0 bids 3, flips its two Safes, then hits p1's Duck → p1 picks one of p0's cards (CHOOSE_DISCARD).
func _other_duck_failed_game() -> RefCounted:
	var gs := _game(3, 7)
	if _place_all_initial_safe(gs) != "":
		return null
	gs.place_card("p0", String(gs.players["p0"].hand[0]))
	gs.place_card("p1", _card_of(gs, "p1", true))
	gs.place_card("p2", String(gs.players["p2"].hand[0]))
	gs.open_bid("p0", 3)
	if _everyone_pass_except_bidder(gs) != "":
		return null
	gs.flip_stack("p0", "p0")
	gs.flip_stack("p0", "p0")
	gs.flip_stack("p0", "p1")
	return gs


func test_discard_event_public_hides_card() -> String:
	var gs := _other_duck_failed_game()
	if gs == null or not gs.pick_discard("p1", 0).ok or gs.phase != GameTypes.Phase.ROUND_OVER:
		return "setup should end in ROUND_OVER after p1 picks"
	var pub: Dictionary = gs.public_snapshot().last_discard
	if String(pub.get("player_id", "")) != "p0" or int(pub.get("seq", 0)) != 1:
		return "public last_discard should name p0 with seq 1, got %s" % pub
	if pub.has("card_id") or pub.has("is_duck"):
		return "public last_discard must not carry card identity: %s" % pub
	var mine: Dictionary = gs.private_snapshot("p0").last_discard
	var cid := String(mine.get("card_id", ""))
	if cid == "" or not mine.has("is_duck"):
		return "loser's snapshot should carry card_id + is_duck, got %s" % mine
	if cid in gs.players["p0"].hand:
		return "discarded card must be gone from the hand"
	var theirs: Dictionary = gs.private_snapshot("p1").last_discard
	if theirs.has("card_id") or theirs.has("is_duck"):
		return "other players' snapshots must not carry card identity: %s" % theirs
	return ""


func test_choose_discard_emits_event() -> String:
	var gs := _game(3)
	_place_initial(gs, "p0", true)
	if _place_all_initial_safe(gs) != "":
		return "setup place failed"
	gs.open_bid("p0", 1)
	if _everyone_pass_except_bidder(gs) != "":
		return "setup bidding failed"
	gs.flip_stack("p0", "p0")
	if gs.phase != GameTypes.Phase.CHOOSE_DISCARD:
		return "expected CHOOSE_DISCARD"
	if not gs.public_snapshot().last_discard.is_empty():
		return "no discard event before the challenger chooses"
	var pick := String(gs.players["p0"].hand[0])
	var want_duck: bool = gs.cards[pick].is_duck
	var r: Dictionary = gs.choose_discard("p0", pick)
	if not r.ok:
		return r.error
	var mine: Dictionary = gs.private_snapshot("p0").last_discard
	if String(mine.get("card_id", "")) != pick or bool(mine.get("is_duck", not want_duck)) != want_duck:
		return "chosen discard should be reported to the loser, got %s" % mine
	if int(gs.public_snapshot().last_discard.get("seq", 0)) != 1:
		return "choose_discard should bump the seq"
	return ""


func test_stamp_offers_exclude_earned() -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var earned: Array = ["katana", "top_hat"]
	for i in 30:
		var o: Array = DuckStamps.offers(rng, earned)
		if o.size() != DuckStamps.OFFER_SIZE:
			return "expected %s offers, got %s" % [DuckStamps.OFFER_SIZE, o]
		for id in o:
			if id in earned or not DuckStamps.STAMPS.has(id) or o.count(id) != 1:
				return "bad offer %s" % [o]
	var almost: Array = DuckStamps.STAMPS.keys().slice(1)
	if DuckStamps.offers(rng, almost) != [DuckStamps.STAMPS.keys()[0]]:
		return "only the one unearned stamp should be offered"
	if not DuckStamps.offers(rng, DuckStamps.STAMPS.keys()).is_empty():
		return "no offers once everything is earned"
	return ""


func test_pick_style_fresh_then_random() -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var p := DuckStamps.empty_progress()
	for i in 10:
		if DuckStamps.pick_style(p, rng) != "rip":
			return "no powers means always rip"
	if DuckStamps.apply_stamp(p, "torch") != "burn" or DuckStamps.apply_stamp(p, "torch") != "":
		return "torch should unlock burn exactly once"
	if DuckStamps.pick_style(p, rng) != "burn" or p.fresh != "":
		return "a fresh power plays first, then clears"
	var seen := {}
	for i in 40:
		seen[DuckStamps.pick_style(p, rng)] = true
	if seen.keys().size() != 2 or not seen.has("rip") or not seen.has("burn"):
		return "after fresh, picks come from rip + powers only: %s" % seen.keys()
	if DuckStamps.apply_stamp(p, "monocle") != "" or p.powers != ["burn"]:
		return "cosmetic stamps unlock nothing"
	return ""


func test_other_duck_pick_grants_upgrade_own_duck_does_not() -> String:
	var gs := _other_duck_failed_game()
	if gs == null or not gs.pick_discard("p1", 0).ok:
		return "setup: p1 should pick"
	var offer: Array = gs.private_snapshot("p1").you.get("upgrade_offer", [])
	if offer.size() != DuckStamps.OFFER_SIZE:
		return "Duck owner should get %s stamp offers, got %s" % [DuckStamps.OFFER_SIZE, offer]
	for pid in ["p0", "p2"]:
		if gs.private_snapshot(pid).you.has("upgrade_offer"):
			return "%s must not see an offer" % pid
	if str(gs.public_snapshot()).contains("upgrade_offer") or str(gs.public_snapshot()).contains("duck_progress"):
		return "public snapshot must not mention upgrades"
	gs.next_round("p0")
	if gs.private_snapshot("p1").you.get("upgrade_offer", []) != offer:
		return "an unused offer stays pending across rounds"
	var own := _game(3)
	_place_initial(own, "p0", true)
	_place_all_initial_safe(own)
	own.open_bid("p0", 1)
	_everyone_pass_except_bidder(own)
	own.flip_stack("p0", "p0")
	own.choose_discard("p0", String(own.players["p0"].hand[0]))
	for pid in own.player_order:
		if own.private_snapshot(pid).you.has("upgrade_offer"):
			return "flipping your own Duck grants nobody an upgrade"
	return ""


func test_discard_style_uses_duck_owner_powers() -> String:
	var gs := _other_duck_failed_game()
	if gs == null:
		return "setup failed"
	DuckStamps.apply_stamp(gs.players["p1"].duck_progress, "katana")
	DuckStamps.apply_stamp(gs.players["p0"].duck_progress, "tnt")
	gs.pick_discard("p1", 0)
	var pub: Dictionary = gs.public_snapshot().last_discard
	if String(pub.get("style", "")) != "samurai":
		return "the Duck owner's fresh power should style the discard: %s" % pub
	var plain := _other_duck_failed_game()
	plain.pick_discard("p1", 0)
	if String(plain.public_snapshot().last_discard.get("style", "")) != "rip":
		return "no powers means rip"
	return ""


func test_apply_duck_upgrade_validates_offer() -> String:
	var gs := _other_duck_failed_game()
	gs.pick_discard("p1", 0)
	var p: Dictionary = gs.players["p1"]
	p.upgrade_offer = ["tnt", "cane", "eyes_star"]
	if gs.apply_duck_upgrade("p1", "katana").ok:
		return "a stamp that wasn't offered must be rejected"
	if gs.apply_duck_upgrade("p0", "tnt").ok:
		return "someone without the offer must be rejected"
	var rev := int(p.duck_rev)
	if not gs.apply_duck_upgrade("p1", "tnt").ok:
		return "offered stamp should apply"
	if p.duck_progress.powers != ["explode"] or p.duck_progress.fresh != "explode" or "tnt" not in p.duck_progress.earned:
		return "tnt should unlock explode: %s" % p.duck_progress
	if int(p.duck_rev) != rev + 1 or not p.upgrade_offer.is_empty():
		return "upgrade should bump duck_rev and clear the offer"
	if gs.apply_duck_upgrade("p1", "cane").ok:
		return "the offer is single use"
	return ""


func test_server_duck_upgrade_updates_peer_and_rev() -> String:
	var srv = DuckServerScript.new()
	var progress := {"earned": ["top_hat"], "powers": [], "fresh": ""}
	var created: Dictionary = srv.create_room(2, "A", {"duck_progress": progress})
	srv.join_room(3, created.code, "B")
	var room: Dictionary = srv.rooms[created.code]
	if room.peers[2].duck_progress.earned != ["top_hat"]:
		return "peer should carry its saved progress"
	if srv.apply_duck_upgrade(2, "katana", _solid_drawing(Color.RED)).ok:
		return "no upgrade outside a match"
	srv.start_match(2)
	var gp: Dictionary = room.state.players["p2"]
	if gp.duck_progress.earned != ["top_hat"]:
		return "match should start from the peer's progress"
	gp.upgrade_offer = ["katana", "cane", "monocle"]
	if srv.apply_duck_upgrade(2, "katana", "junk".to_utf8_buffer()).ok:
		return "bad PNG must be rejected"
	if srv.apply_duck_upgrade(2, "tnt", _solid_drawing(Color.RED)).ok:
		return "stamp not in the offer must be rejected"
	var r: Dictionary = srv.apply_duck_upgrade(2, "katana", _solid_drawing(Color.RED))
	if not r.ok or int(r.rev) != 1 or String(r.player_id) != "p2":
		return "upgrade should succeed with rev 1, got %s" % r
	var info: Dictionary = room.peers[2]
	if int(info.duck_rev) != 1 or info.duck_png.is_empty() or "samurai" not in info.duck_progress.powers:
		return "peer should keep the new art, rev and powers for the next match"
	for p in room.state.public_snapshot().players:
		if String(p.id) == "p2" and int(p.duck_rev) != 1:
			return "snapshot should carry the new duck_rev"
	return ""


func test_duck_stamps_bake_places_rotated_stamp() -> String:
	var base := DuckDrawing.blank_image()
	base.fill(Color.WHITE)
	var stamp := Image.create(10, 2, false, Image.FORMAT_RGBA8)
	stamp.fill(Color.RED)
	var out := DuckStamps.bake(base, stamp, Vector2(50, 50), PI * 0.5, 2.0)
	if out.get_size() != base.get_size():
		return "bake must keep the duck size"
	if out.get_pixel(50, 50) != Color.RED:
		return "stamp centre should land at the given point"
	# 10x2 rotated 90° and doubled → 4 wide, 20 tall.
	if out.get_pixel(50, 41) != Color.RED or out.get_pixel(50, 58) != Color.RED:
		return "rotated stamp should run vertically"
	if out.get_pixel(60, 50) != Color.WHITE or out.get_pixel(50, 62) != Color.WHITE:
		return "pixels outside the stamp must be untouched"
	if base.get_pixel(50, 50) != Color.WHITE:
		return "bake must not modify the base"
	return ""


func test_duck_stamps_bake_flips_horizontally() -> String:
	var base := DuckDrawing.blank_image()
	base.fill(Color.WHITE)
	var stamp := Image.create(2, 1, false, Image.FORMAT_RGBA8)
	stamp.set_pixel(0, 0, Color.RED)
	stamp.set_pixel(1, 0, Color.BLUE)
	# Scale 4 → 8x4 on the duck, centred at (50, 50): left half x 46..49, right half x 50..53.
	var plain := DuckStamps.bake(base, stamp, Vector2(50, 50), 0.0, 4.0)
	var flipped := DuckStamps.bake(base, stamp, Vector2(50, 50), 0.0, 4.0, true)
	if plain.get_pixel(47, 50) != Color.RED or plain.get_pixel(52, 50) != Color.BLUE:
		return "unflipped stamp should be red on the left"
	if flipped.get_pixel(47, 50) != Color.BLUE or flipped.get_pixel(52, 50) != Color.RED:
		return "flipped stamp should be red on the right"
	if flipped.get_size() != base.get_size():
		return "flipped bake must keep the duck size"
	return ""


func test_profile_progress_round_trips_and_editor_clears() -> String:
	var old_path: String = PlayerCosmetics.path
	PlayerCosmetics.path = "user://test_progress.cfg"
	PlayerCosmetics.save_progress({"earned": ["katana", "bogus"], "powers": ["samurai"], "fresh": "samurai"})
	var loaded := PlayerCosmetics.load_progress()
	var via_local: Dictionary = PlayerCosmetics.load_local().get("duck_progress", {})
	PlayerCosmetics.save_progress({})
	var cleared := PlayerCosmetics.load_progress()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PlayerCosmetics.path))
	PlayerCosmetics.path = old_path
	if loaded.earned != ["katana"] or loaded.powers != ["samurai"] or loaded.fresh != "samurai":
		return "progress should round-trip (sanitised): %s" % loaded
	if via_local != loaded:
		return "load_local should carry duck_progress: %s" % via_local
	if not cleared.earned.is_empty() or not cleared.powers.is_empty():
		return "saving empty progress (duck edited) clears it: %s" % cleared
	return ""


func test_discard_pick_snapshot_secrecy() -> String:
	var gs := _other_duck_failed_game()
	if gs == null or gs.phase != GameTypes.Phase.CHOOSE_DISCARD:
		return "setup should end in CHOOSE_DISCARD"
	var faces: Array = gs.private_snapshot("p0").get("discard_slot_faces", [])
	if faces.size() != gs.discard_order.size():
		return "challenger should see one face per slot"
	for i in faces.size():
		if String(faces[i].id) != String(gs.discard_order[i]):
			return "challenger's faces must follow slot order"
	for pid in ["p1", "p2"]:
		var snap: Dictionary = gs.private_snapshot(pid)
		if snap.has("discard_slot_faces"):
			return "%s must not get the challenger's faces" % pid
		var text := JSON.stringify(snap)
		for cid in gs.players["p0"].hand:
			if text.contains(String(cid)):
				return "%s's snapshot leaks p0's card %s" % [pid, cid]
		if int(snap.discard_slots) != faces.size() or String(snap.discard_chooser_id) != "p1":
			return "%s should see the slot count and chooser" % pid
	return ""


func test_server_discard_hover_relay_requires_chooser() -> String:
	var srv = DuckServerScript.new()
	var created: Dictionary = srv.create_room(2, "A")
	srv.join_room(3, created.code, "B")
	srv.start_match(2)
	var gs = srv.rooms[created.code].state
	gs.phase = GameTypes.Phase.CHOOSE_DISCARD
	gs.challenger_id = "p2"
	gs.discard_chooser_id = "p3"
	gs.discard_order = gs.players["p2"].hand.duplicate()
	var ok: Dictionary = srv.validate_discard_hover_relay(3, 1)
	if not ok.ok or ok.peer_ids != [2]:
		return "chooser should relay to the other peer: %s" % ok
	if not srv.validate_discard_hover_relay(3, -1).ok:
		return "chooser should be able to clear the hover"
	if srv.validate_discard_hover_relay(2, 1).ok:
		return "challenger must not relay a hover"
	if srv.validate_discard_hover_relay(3, gs.discard_order.size()).ok:
		return "out-of-range slot must not relay"
	gs.discard_order.clear()
	if srv.validate_discard_hover_relay(3, 0).ok:
		return "own-Duck discard has no pick row to hover"
	return ""


func test_server_hand_fx_relay_validates() -> String:
	var srv = DuckServerScript.new()
	var created: Dictionary = srv.create_room(2, "A")
	srv.join_room(3, created.code, "B")
	if srv.validate_hand_fx_relay(2, {"t": "hover", "slot": 0}).ok:
		return "no relay before the match starts"
	srv.start_match(2)
	var hand_size: int = srv.rooms[created.code].state.players["p2"].hand.size()
	var ok: Dictionary = srv.validate_hand_fx_relay(2, {"t": "drag", "slot": 1, "card_id": "p2_duck", "x": 5})
	if not ok.ok or ok.peer_ids != [3] or ok.player_id != "p2":
		return "seated player should relay to the other peer: %s" % ok
	if ok.ev != {"t": "drag", "slot": 1}:
		return "relayed event must keep only t and slot: %s" % ok.ev
	for bad in [{"t": "peek", "slot": 0}, {"t": "hover", "slot": hand_size + 1}, {"t": "hover", "slot": -2},
			{"t": "hover", "slot": "0"}, {"slot": 0}]:
		if srv.validate_hand_fx_relay(2, bad).ok:
			return "should reject %s" % bad
	if not srv.validate_hand_fx_relay(2, {"t": "hover", "slot": -1}).ok:
		return "clearing the hover (-1) should relay"
	return ""


func test_server_cursor_relay_validates() -> String:
	var srv = DuckServerScript.new()
	var created: Dictionary = srv.create_room(2, "A")
	srv.join_room(3, created.code, "B")
	srv.start_match(2)
	var area := Rect2(48, 0, 1552, 720)
	var ok: Dictionary = srv.validate_cursor_relay(3, "mat:p2", Vector2(1e9, -1e9), area)
	if not ok.ok or ok.peer_ids != [2] or ok.player_id != "p3":
		return "cursor should relay to the other peer: %s" % ok
	if ok.local != Vector2(4096, -4096):
		return "cursor local should be clamped: %s" % ok.local
	if ok.area != area:
		return "a sane area should pass through unchanged: %s" % ok.area
	for anchor in ["hand:p3", "centre"]:
		if not srv.validate_cursor_relay(3, anchor, Vector2.ZERO, area).ok:
			return "%s should be a valid anchor" % anchor
	for anchor in ["hand:p9", "deck:p2", "mat", "mat:p2:x", ""]:
		if srv.validate_cursor_relay(3, anchor, Vector2.ZERO, area).ok:
			return "%s should be rejected" % anchor
	if srv.validate_cursor_relay(3, "centre", Vector2.ZERO, Rect2(NAN, 0, 1280, 720)).ok:
		return "a non-finite area should be rejected"
	var clamped: Rect2 = srv.validate_cursor_relay(3, "centre", Vector2.ZERO, Rect2(-50, 1e9, 1, 1e9)).area
	if clamped != Rect2(0, 2880, 1280, 2880):
		return "area should be clamped to [BASE, 4*BASE] with an in-range inset: %s" % clamped
	return ""


func test_other_duck_owner_picks_discard() -> String:
	var gs := _game(3, 7)
	var err := _place_all_initial_safe(gs)
	if err != "":
		return err
	# p1 still has duck in hand; have p1 place it as extra then p0 bids and flips p1
	# After initial, it's p0's PLACE_OR_BID. p0 places nothing — wait, we need p1's duck on stack.
	# p0 places a second card, p1 places duck, p2 places, p0 opens bid 2 so they must flip own then p1.
	var r: Dictionary = gs.place_card("p0", String(gs.players["p0"].hand[0]))
	if not r.ok:
		return r.error
	r = gs.place_card("p1", _card_of(gs, "p1", true))
	if not r.ok:
		return r.error
	r = gs.place_card("p2", String(gs.players["p2"].hand[0]))
	if not r.ok:
		return r.error
	r = gs.open_bid("p0", 3)
	if not r.ok:
		return r.error
	err = _everyone_pass_except_bidder(gs)
	if err != "":
		return err
	# flip both of p0 (safe), then p1 top... p1's stack is [safe_initial, duck] so top is duck
	r = gs.flip_stack("p0", "p0")
	if not r.ok:
		return r.error
	r = gs.flip_stack("p0", "p0")
	if not r.ok:
		return r.error
	# p0's two flipped Safes stay face-up in flip_history but can still be picked.
	r = gs.flip_stack("p0", "p1")
	if not r.ok:
		return r.error
	if gs.phase != GameTypes.Phase.CHOOSE_DISCARD or gs.discard_chooser_id != "p1":
		return "p1 (the Duck's owner) should be choosing, got phase %s chooser %s" % [gs.phase, gs.discard_chooser_id]
	if gs.current_player_id != "p1":
		return "the chooser should be the current player"
	var owned: Array = gs.players["p0"].hand.duplicate()
	for e in gs.flip_history:
		if String(e.owner_id) == "p0":
			owned.append(String(e.card_id))
	if int(gs.public_snapshot().discard_slots) != owned.size() or owned.size() != gs.players["p0"].hand.size() + 2:
		return "one slot per p0 card, hand plus its 2 flipped Safes"
	if gs.discard_order.duplicate().all(func(c): return c in owned) == false:
		return "slots must be p0's cards"
	if gs.pick_discard("p0", 0).ok or gs.pick_discard("p2", 0).ok:
		return "only the Duck's owner may pick"
	if gs.choose_discard("p0", String(gs.players["p0"].hand[0])).ok:
		return "challenger must not choose their own discard after another player's Duck"
	if gs.pick_discard("p1", owned.size()).ok:
		return "out-of-range slot must fail"
	var k := owned.size() - 1
	var want := String(gs.discard_order[k])
	r = gs.pick_discard("p1", k)
	if not r.ok:
		return r.error
	if want in gs.players["p0"].hand or gs.cards.has(want):
		return "picked slot's card should be destroyed"
	if int(gs.last_discard.slot) != k or int(gs.public_snapshot().last_discard.slot) != k:
		return "last_discard should carry the picked slot"
	if gs.flip_history.is_empty():
		return "flip_history should remain until Next round"
	if gs.phase != GameTypes.Phase.ROUND_OVER:
		return "expected ROUND_OVER after other duck"
	if gs.next_hand_starter_id != "p0":
		return "challenger still starts next hand"
	r = gs.next_round("p0")
	if not r.ok:
		return r.error
	if gs.hand_starter_id != "p0":
		return "challenger still starts next hand after Next round"
	if not gs.flip_history.is_empty():
		return "flip_history should clear on Next round"
	if gs.players["p0"].hand.size() != owned.size() - 1 or want in gs.players["p0"].hand:
		return "p0 should get back every card but the destroyed one, got %s" % [gs.players["p0"].hand]
	return ""


## The reported bug: p0 plays both Safes, keeps only its Duck in hand, flips its Safes then p1's
## Duck. Losing the Duck must not knock p0 out while its flipped Safes remain.
func test_flipped_cards_keep_challenger_in() -> String:
	var gs := _game(3, 7)
	var p0: Dictionary = gs.players["p0"]
	p0.hand.erase(_card_of(gs, "p0", false))
	var err := _place_all_initial_safe(gs)
	if err != "":
		return err
	for step in [["p0", _card_of(gs, "p0", false)], ["p1", _card_of(gs, "p1", true)], ["p2", String(gs.players["p2"].hand[0])]]:
		var r: Dictionary = gs.place_card(step[0], step[1])
		if not r.ok:
			return r.error
	if p0.hand != [_card_of(gs, "p0", true)]:
		return "setup: p0 should hold only its Duck, got %s" % [p0.hand]
	gs.open_bid("p0", 3)
	err = _everyone_pass_except_bidder(gs)
	if err != "":
		return err
	for target in ["p0", "p0", "p1"]:
		var r: Dictionary = gs.flip_stack("p0", target)
		if not r.ok:
			return r.error
	if gs.phase != GameTypes.Phase.CHOOSE_DISCARD or int(gs.public_snapshot().discard_slots) != 3:
		return "p1 should pick from p0's Duck and 2 flipped Safes, got %s slots" % gs.public_snapshot().discard_slots
	var duck_slot: int = gs.discard_order.find("p0_duck")
	var r: Dictionary = gs.pick_discard("p1", duck_slot)
	if not r.ok:
		return r.error
	if p0.eliminated or gs.phase != GameTypes.Phase.ROUND_OVER:
		return "p0 still has 2 Safes, so must stay in (eliminated=%s phase=%s)" % [p0.eliminated, gs.phase]
	gs.next_round("p0")
	if p0.hand.size() != 2 or gs.cards.has("p0_duck"):
		return "p0 should get its 2 Safes back after Next round, got %s" % [p0.hand]
	return ""


## Own Duck with every card flipped: the challenger picks from the centre row and stays in.
func test_own_duck_all_flipped_uses_pick_row() -> String:
	var gs := _game(3, 7)
	var p0: Dictionary = gs.players["p0"]
	p0.hand = [_card_of(gs, "p0", true), _card_of(gs, "p0", false)]
	var r := _place_initial(gs, "p0", true)
	if not r.ok:
		return r.error
	var err := _place_all_initial_safe(gs)
	if err != "":
		return err
	for pid in ["p0", "p1", "p2"]:
		r = gs.place_card(pid, String(gs.players[pid].hand[0]))
		if not r.ok:
			return r.error
	r = gs.open_bid("p0", 2)
	if not r.ok:
		return r.error
	err = _everyone_pass_except_bidder(gs)
	if err != "":
		return err
	gs.flip_stack("p0", "p0")
	gs.flip_stack("p0", "p0")
	if gs.phase != GameTypes.Phase.CHOOSE_DISCARD or gs.discard_chooser_id != "p0" or int(gs.public_snapshot().discard_slots) != 2:
		return "p0 should pick from its 2 flipped cards (phase %s chooser %s slots %s)" % [
			gs.phase, gs.discard_chooser_id, gs.public_snapshot().discard_slots
		]
	if gs.pick_discard("p1", 0).ok:
		return "only p0 may pick after its own Duck"
	r = gs.pick_discard("p0", gs.discard_order.find("p0_duck"))
	if not r.ok:
		return r.error
	if p0.eliminated or gs.phase != GameTypes.Phase.ROUND_OVER:
		return "p0 keeps its Safe, so must stay in"
	for pid in gs.player_order:
		if gs.private_snapshot(pid).you.has("upgrade_offer"):
			return "hitting your own Duck grants nobody an upgrade"
	gs.next_round("p0")
	if p0.hand.size() != 1:
		return "p0 should get its Safe back, got %s" % [p0.hand]
	return ""


func test_safe_flips_score_a_point() -> String:
	var gs := _game(3)
	var err := _place_all_initial_safe(gs)
	if err != "":
		return err
	var r: Dictionary = gs.open_bid("p0", 1)
	if not r.ok:
		return r.error
	err = _everyone_pass_except_bidder(gs)
	if err != "":
		return err
	r = gs.flip_stack("p0", "p0")
	if not r.ok:
		return r.error
	if gs.players["p0"].points != 1:
		return "expected 1 point"
	if bool(gs.last_revealed.get("is_duck", true)):
		return "last_revealed should be Safe after successful challenge"
	if String(gs.last_revealed.get("target_player_id", "")) != "p0":
		return "last_revealed target should be p0"
	var snap: Dictionary = gs.public_snapshot()
	if bool(snap.last_revealed.get("is_duck", true)):
		return "snapshot last_revealed should be Safe"
	if gs.phase != GameTypes.Phase.ROUND_OVER:
		return "expected ROUND_OVER after success"
	if gs.flip_history.is_empty():
		return "revealed cards should stay in flip_history until Next round"
	r = gs.next_round("p0")
	if not r.ok:
		return r.error
	if gs.phase != GameTypes.Phase.PLACE_INITIAL:
		return "next hand after Next round"
	if not gs.flip_history.is_empty():
		return "flip_history should clear on Next round"
	return ""


func test_two_points_wins() -> String:
	var gs := _game(3)
	gs.players["p0"].points = 1
	var err := _place_all_initial_safe(gs)
	if err != "":
		return err
	gs.open_bid("p0", 1)
	err = _everyone_pass_except_bidder(gs)
	if err != "":
		return err
	var r: Dictionary = gs.flip_stack("p0", "p0")
	if not r.ok:
		return r.error
	if gs.phase != GameTypes.Phase.GAME_OVER:
		return "expected GAME_OVER"
	if gs.winner_id != "p0":
		return "p0 should win"
	var snap: Dictionary = gs.public_snapshot()
	if snap.flip_history.size() != 1 or String(snap.last_revealed.get("target_player_id", "")) != "p0":
		return "winning flip must stay in flip_history / last_revealed so clients can animate it"
	return ""


func test_last_card_eliminates_and_last_player_wins() -> String:
	var gs := _game(3)
	# Strip p0 and p1 down to 1 card (their duck) so a failed challenge on own duck eliminates.
	for pid in ["p0", "p1"]:
		var keep := _card_of(gs, pid, true)
		var keep_hand: Array = [keep]
		gs.players[pid].hand = keep_hand
	var r := _place_initial(gs, "p0", true)
	if not r.ok:
		return r.error
	for pid in gs.player_order:
		if gs.players[pid].placed_initial:
			continue
		r = _place_initial(gs, String(pid), false)
		if not r.ok:
			return r.error
	r = gs.open_bid("p0", 1)
	if not r.ok:
		return r.error
	var err := _everyone_pass_except_bidder(gs)
	if err != "":
		return err
	r = gs.flip_stack("p0", "p0")
	if not r.ok:
		return r.error
	# p0's only card is its flipped Duck, so it goes through the pick row.
	if gs.discard_chooser_id != "p0" or gs.discard_order != ["p0_duck"]:
		return "p0 should pick its flipped Duck, got chooser %s order %s" % [gs.discard_chooser_id, gs.discard_order]
	r = gs.pick_discard("p0", 0)
	if not r.ok:
		return r.error
	if not gs.players["p0"].eliminated:
		return "p0 should be eliminated"
	# Not yet last player — p1 and p2 remain. Eliminate p1 the same way next hand.
	if gs.phase == GameTypes.Phase.GAME_OVER:
		return "should not be over yet with 2 players left"
	return ""


func test_private_snapshot_hides_other_hands() -> String:
	var gs := _game(3)
	var mine: Dictionary = gs.private_snapshot("p0")
	if mine.you.hand.size() != 4:
		return "p0 should see own 4 cards"
	for card in mine.you.hand:
		if not card.has("is_duck"):
			return "own cards should include faces"
	var pub: Dictionary = gs.public_snapshot()
	for p in pub.players:
		if p.hand_count == null:
			return "public should only expose hand_count"
		if p.has("hand"):
			return "public must not include hand faces"
	return ""


func test_server_create_and_join_room() -> String:
	var srv = DuckServerScript.new()
	var created: Dictionary = srv.create_room(2, "Mallard")
	if not created.ok:
		return created.get("error", "create failed")
	var code: String = String(created.code)
	if code.length() != 4:
		return "code should be 4 characters"
	var joined: Dictionary = srv.join_room(3, code, "Teal")
	if not joined.ok:
		return joined.error
	var snap: Dictionary = srv.lobby_snapshot(code)
	if snap.players.size() != 2:
		return "expected 2 players in lobby"
	return ""


func test_server_rejects_unknown_code() -> String:
	var srv = DuckServerScript.new()
	var r: Dictionary = srv.join_room(2, "ZZZZ", "X")
	if r.ok:
		return "unknown room should fail"
	return ""


func test_server_min_players_flag() -> String:
	var srv = DuckServerScript.new()
	srv.min_players = 3
	var created: Dictionary = srv.create_room(2, "A")
	srv.join_room(3, created.code, "B")
	if int(srv.lobby_snapshot(String(created.code)).get("min_players", 0)) != 3:
		return "lobby snapshot should carry min_players"
	var short: Dictionary = srv.start_match(2)
	if short.ok or not String(short.error).contains("3"):
		return "2 players must not start when 3 are required, got %s" % short
	srv.join_room(4, created.code, "C")
	if not srv.start_match(2).ok:
		return "3 players should start"
	return ""


func test_server_return_to_lobby() -> String:
	var srv = DuckServerScript.new()
	var created: Dictionary = srv.create_room(2, "A")
	var code := String(created.code)
	srv.join_room(3, code, "B")
	if srv.return_to_lobby(2).ok:
		return "no match yet, nothing to return from"
	srv.start_match(2)
	if srv.return_to_lobby(2).ok:
		return "must not return before GAME_OVER"
	var gs = srv.rooms[code].state
	gs.phase = GameTypes.Phase.GAME_OVER
	if srv.return_to_lobby(3).ok:
		return "only the host may return the room to its lobby"
	var r: Dictionary = srv.return_to_lobby(2)
	if not r.ok or String(r.code) != code:
		return "host should return to the lobby: %s" % r
	if srv.rooms[code].state != null or bool(srv.lobby_snapshot(code).in_match):
		return "room should be back in its lobby"
	if srv.rooms[code].peers.size() != 2:
		return "everyone stays in the room"
	if not srv.join_room(4, code, "C").ok:
		return "new players can join between games"
	if not srv.start_match(2).ok:
		return "a new match should start from the lobby"
	return ""


func test_server_set_display_name() -> String:
	var srv = DuckServerScript.new()
	var created: Dictionary = srv.create_room(2, "A")
	var code := String(created.code)
	if srv.set_display_name(9, "X").ok:
		return "peer not in a room can't rename"
	var r: Dictionary = srv.set_display_name(2, "  Quackers  ")
	if not r.ok or String(r.code) != code:
		return "rename in the lobby should work: %s" % r
	var name := String(srv.lobby_snapshot(code).players[0].name)
	if name != "Quackers":
		return "name should be cleaned and shown in the lobby, got '%s'" % name
	srv.start_match(2)
	if srv.set_display_name(2, "Mid").ok:
		return "rename must be rejected during a match"
	return ""


func test_server_start_requires_host_allows_one() -> String:
	var srv = DuckServerScript.new()
	var created: Dictionary = srv.create_room(2, "A")
	var not_host_empty: Dictionary = srv.start_match(3)
	if not_host_empty.ok:
		return "peer not in room should not start"
	var ok_solo: Dictionary = srv.start_match(2)
	if not ok_solo.ok:
		return ok_solo.get("error", "host should start with 1 player")
	if srv.rooms[created.code].state == null:
		return "match state should exist after solo start"
	# Fresh room: join then non-host cannot start; host can with 2.
	created = srv.create_room(2, "A")
	srv.join_room(3, created.code, "B")
	var not_host: Dictionary = srv.start_match(3)
	if not_host.ok:
		return "non-host should not start"
	var ok: Dictionary = srv.start_match(2)
	if not ok.ok:
		return ok.error
	if srv.rooms[created.code].state == null:
		return "match state should exist"
	var snaps: Dictionary = srv.snapshots_for_room(String(created.code))
	if snaps.size() != 2:
		return "each peer should get a snapshot"
	var s2: Dictionary = snaps[2]
	if s2.you.hand.size() != 4:
		return "host should see their hand"
	# other player's snapshot must not include host card ids in you.hand of peer 3 matching... they have their own 4
	var s3: Dictionary = snaps[3]
	if s3.you.id == s2.you.id:
		return "private snapshots must be per player"
	return ""


func test_server_reveal_relay_requires_challenger() -> String:
	var srv = DuckServerScript.new()
	var created: Dictionary = srv.create_room(2, "A")
	srv.join_room(3, created.code, "B")
	var started: Dictionary = srv.start_match(2)
	if not started.ok:
		return started.get("error", "start failed")
	var room: Dictionary = srv.rooms[created.code]
	var gs = room.state
	# Force REVEAL with a stack so relay validation can pass for the challenger.
	gs.phase = GameTypes.Phase.REVEAL
	gs.challenger_id = "p2"
	gs.flips_remaining = 1
	if gs.players["p2"].stack.is_empty():
		var cid: String = String(gs.players["p2"].hand[0])
		gs.players["p2"].hand.erase(cid)
		gs.players["p2"].stack.append(cid)
	var ok: Dictionary = srv.validate_reveal_relay(2, "p2")
	if not ok.ok:
		return "challenger should relay: %s" % ok.get("error", "")
	if ok.peer_ids.size() != 1 or int(ok.peer_ids[0]) != 3:
		return "should relay to other peer only"
	var non_chal: Dictionary = srv.validate_reveal_relay(3, "p2")
	if non_chal.ok:
		return "non-challenger must not relay"
	gs.phase = GameTypes.Phase.BIDDING
	var wrong_phase: Dictionary = srv.validate_reveal_relay(2, "p2")
	if wrong_phase.ok:
		return "wrong phase must not relay"
	gs.phase = GameTypes.Phase.REVEAL
	gs.players["p2"].stack.clear()
	var empty_stack: Dictionary = srv.validate_reveal_relay(2, "p2")
	if empty_stack.ok:
		return "empty stack must not relay"
	return ""


func test_server_sanitizes_cosmetics() -> String:
	var srv = DuckServerScript.new()
	var created: Dictionary = srv.create_room(2, "A", {"card_back_id": "nope", "card_front_id": ""})
	srv.join_room(3, created.code, "B", {"card_back_id": "crimson", "card_front_id": "gilded"})
	var lobby: Dictionary = srv.lobby_snapshot(String(created.code))
	for p in lobby.players:
		if int(p.peer_id) == 2:
			if p.card_back_id != CardCatalog.DEFAULT_BACK or p.card_front_id != CardCatalog.DEFAULT_FRONT:
				return "unknown ids should fall back to defaults, got %s/%s" % [p.card_back_id, p.card_front_id]
		elif p.card_back_id != "crimson" or p.card_front_id != "gilded":
			return "valid ids should be kept"
	var bad: Dictionary = srv.set_cosmetics(3, "not a dictionary")
	if not bad.ok:
		return "set_cosmetics in lobby should succeed (sanitised)"
	if srv.rooms[created.code].peers[3].cosmetics.card_back_id != CardCatalog.DEFAULT_BACK:
		return "garbage cosmetics should sanitise to defaults"
	srv.start_match(2)
	if srv.set_cosmetics(3, {"card_back_id": "jade"}).ok:
		return "cosmetics must not change mid-match"
	return ""


func test_snapshot_carries_cosmetics() -> String:
	var gs = GameStateScript.new()
	var r: Dictionary = gs.start_match([
		{"id": "a", "name": "A", "cosmetics": {"card_back_id": "frost", "card_front_id": "corners"}},
		{"id": "b", "name": "B"},
	], "a")
	if not r.ok:
		return r.error
	var by_id := {}
	for p in gs.public_snapshot().players:
		by_id[p.id] = p
	var a: Dictionary = by_id["a"]
	if a.card_back_id != "frost" or a.card_front_id != "corners" or int(a.duck_rev) != 0:
		return "player a cosmetics missing from snapshot: %s" % a
	if by_id["b"].card_back_id != CardCatalog.DEFAULT_BACK:
		return "player without cosmetics should get defaults"
	return ""


func test_card_art_duck_and_safe_faces_differ() -> String:
	CardArt.set_players([{"id": "a", "card_back_id": "classic", "card_front_id": "gilded"}])
	var safe: Texture2D = CardArt.face_texture("a", false)
	var duck: Texture2D = CardArt.face_texture("a", true)
	var blank: Texture2D = CardArt.blank_face_texture("a")
	if safe == duck:
		return "duck and safe faces must be different textures"
	var size := Vector2i(CardArt.CARD_SIZE)
	for t in [safe, duck, blank, CardArt.back_texture("a")]:
		if Vector2i(t.get_size()) != size:
			return "card textures should be %s, got %s" % [size, t.get_size()]
	if safe.get_image().get_data() == duck.get_image().get_data():
		return "duck and safe faces must differ in pixels"
	if blank.get_image().get_data() == safe.get_image().get_data():
		return "blank face must not carry the Safe emblem"
	return ""


func test_unrevealed_token_uses_blank_face() -> String:
	CardArt.set_players([{"id": "a", "card_back_id": "jade", "card_front_id": "paper"}])
	var token = CardScene.instantiate()
	token.setup_stack_token(false, "a")
	var front: Texture2D = token._card_front.texture
	var back: Texture2D = token._card_back.texture
	token.free()
	if front != CardArt.blank_face_texture("a"):
		return "unrevealed token face sprite must be the blank frame"
	if front == CardArt.face_texture("a", true) or front == CardArt.face_texture("a", false):
		return "unrevealed token must not carry Duck/Safe"
	if back != CardArt.back_texture("a"):
		return "token back should be the owner's back"
	return ""


func test_stack_fan_is_even_and_fits_mat() -> String:
	var max_stack := GameTypes.SAFE_PER_PLAYER + 1
	var mat_rect := Rect2(Vector2.ZERO, PlayerMatScript.MAT_SIZE)
	var drawn := CardView.SIZE * PlayerMatScript.TOKEN_SCALE
	var shrink := CardView.SIZE * 0.5 * (1.0 - PlayerMatScript.TOKEN_SCALE)
	var prev := Vector2.INF
	var step := Vector2.INF
	for i in max_stack:
		var node_pos: Vector2 = PlayerMatScript.slot_local(i)
		var card_rect := Rect2(node_pos + shrink, drawn)
		if not mat_rect.encloses(card_rect):
			return "slot %s (%s) spills outside the mat %s" % [i, card_rect, mat_rect]
		if prev.is_finite():
			var d := node_pos - prev
			if step.is_finite() and not d.is_equal_approx(step):
				return "fan step should be even, got %s then %s" % [step, d]
			if absf(d.x) < 12.0:
				return "each card's edge should stay visible (step %s)" % d
			step = d
		prev = node_pos
	return ""


## Drawn rect of the i-th reveal in mat coords (same for every seat: the mat itself is rotated).
func _reveal_rect(i: int) -> Rect2:
	var shrink := CardView.SIZE * 0.5 * (1.0 - PlayerMatScript.REVEAL_SCALE)
	return Rect2(PlayerMatScript.reveal_slot_local(i) + shrink, CardView.SIZE * PlayerMatScript.REVEAL_SCALE)


func _token_rect(i: int) -> Rect2:
	var shrink := CardView.SIZE * 0.5 * (1.0 - PlayerMatScript.TOKEN_SCALE)
	return Rect2(PlayerMatScript.slot_local(i) + shrink, CardView.SIZE * PlayerMatScript.TOKEN_SCALE)


func _seat_xform(s: Dictionary, is_viewer: bool, area := Rect2(Vector2.ZERO, ScreenFit.BASE)) -> Transform2D:
	return SeatSpace.mat_xform(s.pos, SeatSpace.seat_rotation(s.pos, s.dir, is_viewer, area))


## Logical viewport sizes under canvas_items + expand: 16:9, 20:9, 19.5:9, 16:10, 4:3.
const SCREEN_SIZES := [Vector2(1280, 720), Vector2(1600, 720), Vector2(1560, 720), Vector2(1280, 800), Vector2(1280, 960)]


func test_reveal_rows_fit_screen_and_clear_stack() -> String:
	for size in SCREEN_SIZES:
		var err := _check_reveal_rows(Rect2(Vector2.ZERO, size))
		if err != "":
			return "%s: %s" % [size, err]
	return ""


func test_seats_clear_hand_on_every_screen() -> String:
	for size in SCREEN_SIZES:
		var screen := Rect2(Vector2.ZERO, size)
		# Bid row top to hand bottom, matching table._layout_chrome.
		var hand_zone := Rect2(size.x * 0.5 - 360.0, size.y - 216.0, 720, 206)
		for n in range(1, 7):
			for s in PlayerMatScript.seat_layout(n, screen):
				var mat := Rect2(s.pos, PlayerMatScript.MAT_SIZE)
				if not screen.encloses(mat):
					return "%s %dp: mat %s leaves the screen" % [size, n, mat]
				if mat.intersects(hand_zone):
					return "%s %dp: mat %s overlaps the hand/bid row" % [size, n, mat]
	return ""


func _check_reveal_rows(screen: Rect2) -> String:
	var max_cards := GameTypes.SAFE_PER_PLAYER + 1
	# k flipped off a full stack leaves max_cards - k tokens; the new top must stay clear.
	for k in range(1, max_cards):
		var top := _token_rect(max_cards - k - 1)
		for i in k:
			var hit := _reveal_rect(i).intersection(top)
			if hit.get_area() > top.get_area() * 0.02:
				return "reveal %d covers top token with %d left" % [i, max_cards - k]
	for n in range(2, 7):
		var seats: Array = PlayerMatScript.seat_layout(n, screen)
		var xfs: Array = []
		for si in seats.size():
			xfs.append(_seat_xform(seats[si], si == 0, screen))
		for si in seats.size():
			for i in max_cards:
				var r: Rect2 = xfs[si] * _reveal_rect(i)
				if not screen.encloses(r):
					return "%dp seat %s: reveal %d %s leaves the screen" % [n, seats[si].pos, i, r]
		if n > 4:
			continue
		# Rows of different mats must not collide (2-4 players).
		for a in seats.size():
			for b in range(a + 1, seats.size()):
				for i in max_cards:
					for j in max_cards:
						var ra: Rect2 = xfs[a] * _reveal_rect(i)
						var rb: Rect2 = xfs[b] * _reveal_rect(j)
						if ra.intersects(rb):
							return "%dp: reveal rows of seats %s and %s overlap" % [n, seats[a].pos, seats[b].pos]
	return ""


func _solid_drawing(c: Color) -> PackedByteArray:
	var img := DuckDrawing.blank_image()
	img.fill(c)
	return DuckDrawing.encode(img)


func test_duck_drawing_decode_validates() -> String:
	if DuckDrawing.decode(_solid_drawing(Color.RED)) == null:
		return "valid 144x176 PNG should decode"
	var small := Image.create(100, 100, false, Image.FORMAT_RGBA8)
	if DuckDrawing.decode(small.save_png_to_buffer()) != null:
		return "wrong-size PNG must be rejected"
	if DuckDrawing.decode("not a png at all, just text".to_utf8_buffer()) != null:
		return "garbage must be rejected"
	var noise := DuckDrawing.blank_image()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for y in DuckDrawing.SIZE.y:
		for x in DuckDrawing.SIZE.x:
			noise.set_pixel(x, y, Color(rng.randf(), rng.randf(), rng.randf(), 1.0))
	var big := DuckDrawing.encode(noise)
	if big.size() <= DuckDrawing.MAX_BYTES:
		return "noise PNG should exceed MAX_BYTES for this test (got %s)" % big.size()
	if DuckDrawing.decode(big) != null:
		return "oversized PNG must be rejected"
	return ""


func test_server_duck_drawing_lobby_only_and_in_snapshot() -> String:
	var srv = DuckServerScript.new()
	var created: Dictionary = srv.create_room(2, "A")
	srv.join_room(3, created.code, "B")
	var r1: Dictionary = srv.set_duck_drawing(2, _solid_drawing(Color.RED))
	var r2: Dictionary = srv.set_duck_drawing(2, _solid_drawing(Color.BLUE))
	if not r1.ok or not r2.ok or int(r2.rev) != 2:
		return "lobby duck changes should succeed and bump rev, got %s / %s" % [r1, r2]
	if srv.set_duck_drawing(3, "junk".to_utf8_buffer()).ok:
		return "invalid PNG must be rejected"
	var arts: Array = srv.duck_arts(String(created.code))
	if arts.size() != 1 or String(arts[0].player_id) != String(r2.player_id):
		return "only players with a drawing should be synced to joiners: %s" % [arts]
	for p in srv.lobby_snapshot(String(created.code)).players:
		var want := 2 if int(p.peer_id) == 2 else 0
		if int(p.duck_rev) != want:
			return "lobby snapshot duck_rev wrong for %s" % p.peer_id
	srv.start_match(2)
	for p in srv.rooms[created.code].state.public_snapshot().players:
		var want := 2 if String(p.id) == String(r2.player_id) else 0
		if int(p.duck_rev) != want:
			return "match snapshot duck_rev should match the lobby drawing (%s)" % p
	if srv.set_duck_drawing(2, _solid_drawing(Color.GREEN)).ok:
		return "duck must not change mid-match"
	return ""


func test_card_art_uses_custom_duck_for_matching_rev() -> String:
	CardArt.set_players([{"id": "d", "card_back_id": "classic", "card_front_id": "bordered", "duck_rev": 1}])
	var center := Vector2i(CardArt.CARD_SIZE / 2)
	var default_px := CardArt.face_texture("d", true).get_image().get_pixelv(center)
	var red := DuckDrawing.blank_image()
	red.fill(Color.RED)
	CardArt.set_duck_image("d", 1, red)
	var custom_px := CardArt.face_texture("d", true).get_image().get_pixelv(center)
	if not custom_px.is_equal_approx(Color.RED):
		return "matching rev should show the drawing, centre is %s" % custom_px
	if custom_px.is_equal_approx(default_px):
		return "custom duck should differ from the default"
	CardArt.set_duck_image("d", 0, red)
	if not CardArt.face_texture("d", true).get_image().get_pixelv(center).is_equal_approx(default_px):
		return "stale rev should fall back to the default duck"
	if CardArt.face_texture("d", false).get_image().get_pixelv(center).is_equal_approx(Color.RED):
		return "Safe face must never use the duck drawing"
	return ""


## Revs restart per room, so a new drawing can arrive with an (owner, rev) seen before.
func test_card_art_new_drawing_same_rev_replaces_cache() -> String:
	CardArt.set_players([{"id": "r", "duck_rev": 1}, {"id": "other", "duck_rev": 0}])
	var center := Vector2i(CardArt.CARD_SIZE / 2)
	var mini_center := Vector2i(CardArt.MINI_DUCK_SIZE / 2)
	var other_before := CardArt.face_texture("other", true)
	var red := DuckDrawing.blank_image()
	red.fill(Color.RED)
	CardArt.set_duck_image("r", 1, red)
	if not CardArt.face_texture("r", true).get_image().get_pixelv(center).is_equal_approx(Color.RED):
		return "first drawing should show on the face"
	if not CardArt.mini_duck_texture("r").get_image().get_pixelv(mini_center).is_equal_approx(Color.RED):
		return "first drawing should show on the mini duck"
	var blue := DuckDrawing.blank_image()
	blue.fill(Color.BLUE)
	CardArt.set_duck_image("r", 1, blue)
	var face_px := CardArt.face_texture("r", true).get_image().get_pixelv(center)
	if not face_px.is_equal_approx(Color.BLUE):
		return "new drawing with the same rev should replace the cached face, centre is %s" % face_px
	var mini_px := CardArt.mini_duck_texture("r").get_image().get_pixelv(mini_center)
	if not mini_px.is_equal_approx(Color.BLUE):
		return "new drawing with the same rev should replace the cached mini duck, centre is %s" % mini_px
	if CardArt.face_texture("other", true) != other_before:
		return "eviction must not touch other players' (default) duck textures"
	return ""


func test_profile_name_round_trips() -> String:
	var old_path: String = PlayerCosmetics.path
	PlayerCosmetics.path = "user://test_profile.cfg"
	PlayerCosmetics.save_name("  Quackers  ")
	PlayerCosmetics.save_local({"card_back_id": "jade", "card_front_id": "paper"})
	var n := PlayerCosmetics.load_name()
	var c := PlayerCosmetics.load_local()
	PlayerCosmetics.save_name("")
	var blank := PlayerCosmetics.load_name()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PlayerCosmetics.path))
	PlayerCosmetics.path = old_path
	if n != "Quackers":
		return "name should round-trip trimmed, got '%s'" % n
	if c.card_back_id != "jade" or c.card_front_id != "paper":
		return "saving cards must not lose them: %s" % c
	if blank != PlayerCosmetics.DEFAULT_NAME:
		return "empty name should fall back to default, got '%s'" % blank
	return ""


func test_status_text_is_per_viewer() -> String:
	var gs := _game(3)
	var say := func(pid: String) -> String: return StatusTextScript.for_viewer(gs.private_snapshot(pid), pid)
	_place_initial(gs, "p0")
	if not say.call("p1").begins_with("Play one card"):
		return "unplaced viewer should be told to play: %s" % say.call("p1")
	if say.call("p0") != "Waiting for P1, P2 to play their opening card…":
		return "placed viewer should see who's left: %s" % say.call("p0")
	_place_initial(gs, "p1")
	_place_initial(gs, "p2")
	if not say.call("p0").begins_with("Your turn"):
		return "current player should get 'Your turn': %s" % say.call("p0")
	if say.call("p1") != "Waiting for P0 to play a card or bid…":
		return "others should wait on P0: %s" % say.call("p1")
	gs.open_bid("p0", 2)
	if not say.call("p1").begins_with("Your bid"):
		return "bidder on turn should get 'Your bid': %s" % say.call("p1")
	if say.call("p0") != "You lead with 2. Waiting for P1…":
		return "top bidder should see they lead: %s" % say.call("p0")
	if say.call("p2") != "P1 is bidding — current bid 2 by P0.":
		return "others should see who's bidding: %s" % say.call("p2")
	var snap: Dictionary = gs.private_snapshot("p1")
	snap.phase = GameTypes.Phase.ROUND_OVER
	snap.you_are_host = false
	snap.host_id = "p0"
	if StatusTextScript.for_viewer(snap, "p1") != "Round over — waiting for P0 to start the next round.":
		return "non-host should wait for the host: %s" % StatusTextScript.for_viewer(snap, "p1")
	snap.you_are_host = true
	if not StatusTextScript.for_viewer(snap, "p1").contains("press Next round"):
		return "host should be told to press Next round"
	snap.phase = GameTypes.Phase.GAME_OVER
	if StatusTextScript.for_viewer(snap, "p1") != "Game over — press Back to lobby when ready.":
		return "host should be told to press Back to lobby: %s" % StatusTextScript.for_viewer(snap, "p1")
	snap.you_are_host = false
	if StatusTextScript.for_viewer(snap, "p1") != "Game over — waiting for P0 to return to the lobby.":
		return "non-host should wait for the host to return: %s" % StatusTextScript.for_viewer(snap, "p1")
	return ""


func test_reparent_keep_pose_keeps_seat_angle_and_scale() -> String:
	var seat := Control.new()
	seat.position = Vector2(300, 80)
	seat.rotation = 2.4
	seat.scale = Vector2(0.6, 0.6)
	var layer := Control.new()
	layer.position = Vector2(5, 7)
	var card := Control.new()
	card.size = CardView.SIZE
	card.pivot_offset = CardView.SIZE * 0.5
	card.position = Vector2(40, 10)
	card.rotation = 0.2
	seat.add_child(card)
	var before := card.get_global_transform()
	SeatSpace.reparent_keep_pose(card, layer)
	var after := card.get_global_transform()
	var err := ""
	if card.get_parent() != layer:
		err = "card should move to the new parent"
	elif not (before.origin.is_equal_approx(after.origin) and before.x.is_equal_approx(after.x) and before.y.is_equal_approx(after.y)):
		err = "on-screen pose changed: %s -> %s" % [before, after]
	seat.free()
	layer.free()
	return err


## [sender area, receiver area]: same screen, then a 20:9 phone with a left notch inset talking to
## a 4:3 tablet (and back).
const CURSOR_SCREEN_PAIRS := [
	[Rect2(0, 0, 1280, 720), Rect2(0, 0, 1280, 720)],
	[Rect2(48, 0, 1552, 720), Rect2(0, 0, 1280, 960)],
	[Rect2(0, 0, 1280, 960), Rect2(48, 0, 1552, 720)],
]


func test_seat_space_round_trips_between_viewers() -> String:
	var card_w := CardView.SIZE.x
	for screens in CURSOR_SCREEN_PAIRS:
		var area_a: Rect2 = screens[0]
		var area_b: Rect2 = screens[1]
		for n in range(2, 7):
			var ids: Array = []
			for i in n:
				ids.append("p%d" % i)
			var on_a := SeatSpace.anchors(SeatSpace.seat_list(ids, "p0", area_a), "p0", area_a)
			var on_b := SeatSpace.anchors(SeatSpace.seat_list(ids, "p1", area_b), "p1", area_b)
			for pid in ids:
				var mat_name := "mat:%s" % pid
				var mid := PlayerMatScript.MAT_SIZE * 0.5
				var got := _cursor_a_to_b(SeatSpace.decode(mat_name, mid, on_a), on_a, on_b)
				if got.distance_to(SeatSpace.decode(mat_name, mid, on_b)) > 0.01:
					return "%s %dp: %s's mat centre should map mat to mat, got %s" % [screens, n, pid, got]
				# Slot centres of a 4-card hand laid out like the HBoxContainer (separation 4).
				var hand_name := "hand:%s" % pid
				var x0 := (SeatSpace.HAND_SIZE.x - (4 * card_w + 3 * 4.0)) * 0.5
				for slot in 4:
					var local := Vector2(x0 + card_w * 0.5 + slot * (card_w + 4.0), SeatSpace.HAND_SIZE.y * 0.5)
					got = _cursor_a_to_b(SeatSpace.decode(hand_name, local, on_a), on_a, on_b)
					if got.distance_to(SeatSpace.decode(hand_name, local, on_b)) > 0.01:
						return "%s %dp: %s's hand slot %d should stay that slot, got %s" % [screens, n, pid, slot, got]
	return ""


## The wire path: A encodes with its anchors; B rebuilds A's point with A's anchors and maps it.
func _cursor_a_to_b(p: Vector2, on_a: Array, on_b: Array) -> Vector2:
	var enc := SeatSpace.encode(p, on_a, false)
	return SeatSpace.map_point(SeatSpace.decode(enc[0], enc[1], on_a), on_a, on_b, false)


## Gaps between seats can map to long slides on another screen (steep but smooth, steeper still
## between different screen shapes), so a big 2px step is bisected toward its biggest jump: a real
## snap stays big however finely it is sampled.
func test_cursor_mapping_is_continuous() -> String:
	var step := 2.0
	var max_jump := 15.0
	for screens in CURSOR_SCREEN_PAIRS:
		var err := _check_cursor_continuity(screens[0], screens[1], step, max_jump)
		if err != "":
			return "%s: %s" % [screens, err]
	return ""


func _check_cursor_continuity(area_a: Rect2, area_b: Rect2, step: float, max_jump: float) -> String:
	var vp := area_a.end
	for n in [3, 4, 6]:
		var ids: Array = []
		for i in n:
			ids.append("p%d" % i)
		for pair in [["p0", "p1"], ["p1", "p0"], ["p0", ids[n - 1]]]:
			var on_a := SeatSpace.anchors(SeatSpace.seat_list(ids, pair[0], area_a), pair[0], area_a)
			var on_b := SeatSpace.anchors(SeatSpace.seat_list(ids, pair[1], area_b), pair[1], area_b)
			var lines: Array = []
			for y in range(0, int(vp.y) + 1, 60):
				lines.append([Vector2(0, y), Vector2(step, 0), int(vp.x / step)])
			for x in range(0, int(vp.x) + 1, 60):
				lines.append([Vector2(x, 0), Vector2(0, step), int(vp.y / step)])
			for line in lines:
				var prev := _cursor_a_to_b(line[0], on_a, on_b)
				for k in range(1, int(line[2]) + 1):
					var p: Vector2 = line[0] + line[1] * k
					var q := _cursor_a_to_b(p, on_a, on_b)
					if q.distance_to(prev) > max_jump:
						var lo: Vector2 = p - line[1]
						var hi := p
						var q_lo := prev
						var q_hi := q
						for _i in 16:
							var mid := (lo + hi) * 0.5
							var q_mid := _cursor_a_to_b(mid, on_a, on_b)
							if q_mid.distance_to(q_lo) > q_mid.distance_to(q_hi):
								hi = mid
								q_hi = q_mid
							else:
								lo = mid
								q_lo = q_mid
						if q_lo.distance_to(q_hi) > 1.0:
							return "%dp %s->%s: cursor snaps %.1fpx at %s" % [n, pair[0], pair[1], q_lo.distance_to(q_hi), lo]
					prev = q
	return ""
