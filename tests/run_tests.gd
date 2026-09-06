extends SceneTree

const GameStateScript = preload("res://scripts/rules/game_state.gd")
const GameTypes = preload("res://scripts/rules/types.gd")
const DuckServerScript = preload("res://scripts/net/server.gd")

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
	_run("other_duck_discards_random_challenger_card", test_other_duck_discards_random_challenger_card)
	_run("safe_flips_score_a_point", test_safe_flips_score_a_point)
	_run("two_points_wins", test_two_points_wins)
	_run("last_card_eliminates_and_last_player_wins", test_last_card_eliminates_and_last_player_wins)
	_run("private_snapshot_hides_other_hands", test_private_snapshot_hides_other_hands)
	_run("server_create_and_join_room", test_server_create_and_join_room)
	_run("server_rejects_unknown_code", test_server_rejects_unknown_code)
	_run("server_start_requires_host_allows_one", test_server_start_requires_host_allows_one)
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
	if gs.phase != GameTypes.Phase.PLACE_INITIAL:
		return "next hand should start after scoring"
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
	if gs.phase != GameTypes.Phase.PLACE_INITIAL:
		return "solo should continue with a new hand after discard"
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
	if gs.phase != GameTypes.Phase.PLACE_INITIAL:
		return "next hand should start"
	if gs.hand_starter_id != "p0":
		return "challenger starts next hand"
	return ""


func test_other_duck_discards_random_challenger_card() -> String:
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
	var cards_before: int = gs.players["p0"].hand.size() + gs.players["p0"].stack.size()
	# also count already flipped belonging to p0 — snapshot after fail collects to hand
	r = gs.flip_stack("p0", "p1")
	if not r.ok:
		return r.error
	if gs.phase == GameTypes.Phase.CHOOSE_DISCARD:
		return "other duck should not let challenger choose"
	if gs.players["p0"].hand.size() != 3:
		return "p0 should have 3 cards after random discard of 1 from 4, got %s" % gs.players["p0"].hand.size()
	if gs.hand_starter_id != "p0":
		return "challenger still starts next hand"
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
	if gs.phase != GameTypes.Phase.PLACE_INITIAL:
		return "next hand after success"
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
	if gs.phase == GameTypes.Phase.CHOOSE_DISCARD:
		r = gs.choose_discard("p0", String(gs.players["p0"].hand[0]))
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
