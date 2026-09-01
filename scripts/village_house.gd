extends Node2D
# Shared script for all 3 village houses (elder/trader/empty) — port of the
# per-house furniture/NPC branch in world.js's villageHouses.forEach() loop.
# One scene per house (ElderHouse/TraderHouse/EmptyHouse.tscn), each just
# setting these exported values differently rather than 3 near-duplicate
# scripts, matching how the JS version drives all 3 from one loop body too.

const WIDTH := 9
const HEIGHT := 7
const DOOR_TILE := Vector2i(4, 6)
const NPC_TILE := Vector2i(4, 2)

@export var has_npc := false
@export var npc_sprite_path := ""
@export var npc_name_text := ""
@export var npc_dialogue := ""
@export var npc_quest_id := ""
@export var furniture_layout: Array[Dictionary] = [] # [{"kind": "Bed", "x": 2, "y": 4}, ...]
@export var window_tiles: Array[Vector2i] = []
@export var overworld_return_tile := Vector2i.ZERO
@export var overworld_return_offset := Vector2i(0, 1)

const FURNITURE_SCENES := {
	"Bed": preload("res://scenes/props/Bed.tscn"),
	"Table": preload("res://scenes/props/Table.tscn"),
	"Chair": preload("res://scenes/props/Chair.tscn"),
	"Bookshelf": preload("res://scenes/props/Bookshelf.tscn"),
	"Barrel": preload("res://scenes/props/Barrel.tscn"),
	"Cabinet": preload("res://scenes/props/Cabinet.tscn"),
}
const NPC_SCENE := preload("res://scenes/props/NPC.tscn")

@onready var terrain: TileMapLayer = $TerrainLayer
@onready var ysort: Node2D = $YSort
@onready var player: CharacterBody2D = $YSort/Player
@onready var out_portal: Area2D = $OutPortal

func _tile_center(pos: Vector2i) -> Vector2:
	return Vector2(pos.x * 32 + 16, pos.y * 32 + 16)

func _ready() -> void:
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var on_border: bool = x == 0 or x == WIDTH - 1 or y == 0 or y == HEIGHT - 1
			terrain.set_cell(Vector2i(x, y), 0 if on_border else 1, Vector2i(0, 0)) # 0=wall,1=floor
	for w in window_tiles:
		terrain.set_cell(w, 2, Vector2i(0, 0)) # 2=window
	terrain.set_cell(DOOR_TILE, 1, Vector2i(0, 0))

	for item in furniture_layout:
		var scene: PackedScene = FURNITURE_SCENES[item.kind]
		var instance: Node2D = scene.instantiate()
		instance.position = _tile_center(Vector2i(item.x, item.y))
		ysort.add_child(instance)

	if has_npc:
		var npc: StaticBody2D = NPC_SCENE.instantiate()
		npc.position = _tile_center(NPC_TILE)
		npc.sprite_path = npc_sprite_path
		npc.npc_name = npc_name_text
		npc.dialogue_text = npc_dialogue
		npc.quest_id = npc_quest_id
		ysort.add_child(npc)

	if not GameState.consume_next_spawn(player):
		player.position = _tile_center(DOOR_TILE + Vector2i(0, -1))

	var cam: Camera2D = player.get_node("Camera2D")
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = WIDTH * 32
	cam.limit_bottom = HEIGHT * 32
	cam.reset_smoothing()

	out_portal.position = _tile_center(DOOR_TILE)
	out_portal.target_scene = "res://scenes/Overworld.tscn"
	out_portal.target_spawn = Vector2(
		overworld_return_tile.x * 32 + 16 + overworld_return_offset.x * 32,
		overworld_return_tile.y * 32 + 16 + overworld_return_offset.y * 32
	)
