class_name StatusText
extends RefCounted

## Top-of-screen instruction line, worded for the viewing player.
const GameTypes = preload("res://scripts/rules/types.gd")


static func for_viewer(snap: Dictionary, viewer: String) -> String:
	var phase := int(snap.get("phase", -1))
	var me := _info(snap, viewer)
	if bool(me.get("eliminated", false)) and phase != GameTypes.Phase.GAME_OVER:
		return "You're out — watching the rest of the game."
	var current := String(snap.get("current_player_id", ""))
	var challenger := String(snap.get("challenger_id", ""))
	match phase:
		GameTypes.Phase.PLACE_INITIAL:
			if not bool(me.get("placed_initial", false)):
				return "Play one card face-down onto your mat."
			var waiting: Array = []
			for p in snap.players:
				if not bool(p.placed_initial) and not bool(p.eliminated):
					waiting.append(String(p.name))
			return "Waiting for %s to play their opening card…" % ", ".join(waiting)
		GameTypes.Phase.PLACE_OR_BID:
			if current == viewer:
				return "Your turn: play another card, or open the bidding."
			return "Waiting for %s to play a card or bid…" % _name(snap, current)
		GameTypes.Phase.BIDDING:
			var bid := int(snap.get("current_bid", 0))
			var bidder := String(snap.get("current_bidder_id", ""))
			if current == viewer:
				if bidder == viewer:
					return "You lead with %d. Raise or pass." % bid
				return "Your bid: raise above %d or pass." % bid
			if bool(me.get("passed", false)):
				return "You passed. Waiting for %s…" % _name(snap, current)
			if bidder == viewer:
				return "You lead with %d. Waiting for %s…" % [bid, _name(snap, current)]
			return "%s is bidding — current bid %d by %s." % [_name(snap, current), bid, _name(snap, bidder)]
		GameTypes.Phase.REVEAL:
			var n := int(snap.get("flips_remaining", 0))
			if challenger == viewer:
				return "Flip %s more. Drag sideways on a stack to flip (release past halfway to commit)." % n
			return "%s is flipping %d %s…" % [_name(snap, challenger), n, "card" if n == 1 else "cards"]
		GameTypes.Phase.CHOOSE_DISCARD:
			if int(snap.get("discard_slots", 0)) > 0:
				var chooser := String(snap.get("discard_chooser_id", ""))
				if chooser == challenger:
					if challenger == viewer:
						return "You hit your own Duck. Pick one of your cards to lose."
					return "%s hit their own Duck and is choosing a card to lose…" % _name(snap, challenger)
				if chooser == viewer:
					return "Pick one of %s's cards to destroy." % _name(snap, challenger)
				if challenger == viewer:
					return "%s is choosing which of your cards to destroy…" % _name(snap, chooser)
				return "%s is choosing one of %s's cards to destroy…" % [_name(snap, chooser), _name(snap, challenger)]
			if challenger == viewer:
				return "You hit your own Duck. Tap a card in your hand to discard it forever."
			return "%s hit their own Duck and is choosing a card to lose…" % _name(snap, challenger)
		GameTypes.Phase.ROUND_OVER:
			if bool(snap.get("you_are_host", true)):
				return "Round over — press Next round when ready."
			return "Round over — waiting for %s to start the next round." % _name(snap, String(snap.get("host_id", "")), "the host")
		GameTypes.Phase.GAME_OVER:
			return "Game over."
	return "Show me your duck"


static func _info(snap: Dictionary, pid: String) -> Dictionary:
	for p in snap.get("players", []):
		if String(p.id) == pid:
			return p
	return {}


static func _name(snap: Dictionary, pid: String, fallback: String = "someone") -> String:
	var p := _info(snap, pid)
	return String(p.name) if not p.is_empty() else fallback
