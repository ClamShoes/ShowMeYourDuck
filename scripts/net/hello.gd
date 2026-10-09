extends Node
## Version handshake, child of Net. Godot rejects every RPC on a node whose RPC list differs between
## peers, so this node must keep exactly this one RPC forever; every other RPC lives on Net.

@rpc("any_peer", "reliable")
func hello(version: int) -> void:
	get_parent()._on_hello(multiplayer.get_remote_sender_id(), version)
