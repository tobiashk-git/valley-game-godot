extends SceneTree
# Generates a small icon PNG per item/spell under res://assets/icons/,
# replacing the emoji that couldn't render on Web export. Simple geometric
# shapes, not full pixel art - a placeholder pass (same spirit as the touch
# controls' circle textures) rather than the LPC sprite pipeline's polish;
# real icon art is a separate later effort if wanted.
#
# Saved as real files (not in-memory ImageTexture like touch_controls.gd's
# icons) because these need to be load()-able by resource path from BBCode
# [img] tags and from other scenes' own builder scripts - run this ONCE
# first, then any other builder that load()s an icon needs Godot to have
# re-scanned/imported these new files, which only happens on the NEXT
# process launch (the same "brand-new file mid-script" gotcha touch
# controls hit, worked around there by skipping the file entirely - can't
# do that here since these need to be real resource paths). Run via:
# godot --headless --script res://tools/setup_item_icons.gd

const SIZE := 24

func _new_img() -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img

func _fill_circle(img: Image, cx: float, cy: float, r: float, color: Color) -> void:
	for y in range(SIZE):
		for x in range(SIZE):
			if Vector2(x + 0.5, y + 0.5).distance_to(Vector2(cx, cy)) <= r:
				img.set_pixel(x, y, color)

func _fill_rect(img: Image, x0: int, y0: int, x1: int, y1: int, color: Color) -> void:
	for y in range(max(0, y0), min(SIZE, y1)):
		for x in range(max(0, x0), min(SIZE, x1)):
			img.set_pixel(x, y, color)

func _fill_diamond(img: Image, cx: float, cy: float, r: float, color: Color) -> void:
	for y in range(SIZE):
		for x in range(SIZE):
			if abs(x + 0.5 - cx) + abs(y + 0.5 - cy) <= r:
				img.set_pixel(x, y, color)

func _fill_triangle_up(img: Image, cx: float, top_y: float, base_y: float, half_w: float, color: Color) -> void:
	var h: float = base_y - top_y
	for y in range(int(top_y), int(base_y) + 1):
		var t: float = (y - top_y) / max(h, 1.0)
		var w: float = half_w * t
		_fill_rect(img, int(cx - w), y, int(cx + w) + 1, y + 1, color)

func _draw_line(img: Image, x0: int, y0: int, x1: int, y1: int, color: Color, thickness: int = 2) -> void:
	var steps: int = max(abs(x1 - x0), abs(y1 - y0))
	for i in range(steps + 1):
		var t: float = float(i) / max(steps, 1)
		var cx: int = int(round(lerp(float(x0), float(x1), t)))
		var cy: int = int(round(lerp(float(y0), float(y1), t)))
		var half: int = thickness / 2
		for dx in range(-half, half + 1):
			for dy in range(-half, half + 1):
				var px: int = cx + dx
				var py: int = cy + dy
				if px >= 0 and px < SIZE and py >= 0 and py < SIZE:
					img.set_pixel(px, py, color)

func _bottle(color: Color) -> Image:
	var img := _new_img()
	_fill_rect(img, 10, 3, 14, 7, Color(0.5, 0.5, 0.55)) # neck (grey cap)
	_fill_rect(img, 6, 7, 18, 21, color) # body
	_fill_circle(img, 9, 10, 1.3, Color(1, 1, 1, 0.5)) # highlight
	return img

func _save(img: Image, name: String) -> void:
	var dir := DirAccess.open("res://assets")
	if not dir.dir_exists("icons"):
		dir.make_dir("icons")
	img.save_png("res://assets/icons/%s.png" % name)

func _build_items() -> void:
	# wood: log cross-section
	var wood := _new_img()
	_fill_rect(wood, 4, 6, 20, 18, Color(0.55, 0.35, 0.18))
	_fill_rect(wood, 4, 10, 20, 12, Color(0.65, 0.45, 0.25))
	_save(wood, "wood")

	# stone: clustered grey blob
	var stone := _new_img()
	_fill_circle(stone, 9, 15, 6, Color(0.55, 0.55, 0.58))
	_fill_circle(stone, 16, 13, 5, Color(0.62, 0.62, 0.65))
	_fill_circle(stone, 12, 9, 4, Color(0.68, 0.68, 0.7))
	_save(stone, "stone")

	# gold: coin stack
	var gold := _new_img()
	_fill_circle(gold, 9, 15, 6, Color(0.75, 0.6, 0.15))
	_fill_circle(gold, 15, 10, 6, Color(0.95, 0.8, 0.25))
	_fill_circle(gold, 15, 10, 3.5, Color(0.8, 0.65, 0.15))
	_save(gold, "gold")

	# wooden_pickaxe: grey head + brown diagonal handle
	var pick := _new_img()
	_draw_line(pick, 4, 20, 18, 6, Color(0.5, 0.32, 0.16), 3)
	_fill_diamond(pick, 17, 6, 6, Color(0.6, 0.6, 0.63))
	_save(pick, "wooden_pickaxe")

	# leather_armor: brown vest
	var armor := _new_img()
	_fill_rect(armor, 6, 4, 18, 8, Color(0.45, 0.3, 0.15))
	_fill_rect(armor, 4, 8, 20, 20, Color(0.55, 0.38, 0.2))
	_fill_rect(armor, 10, 8, 14, 20, Color(0.45, 0.3, 0.15))
	_save(armor, "leather_armor")

	# charm_of_warding: purple gem
	var charm := _new_img()
	_fill_diamond(charm, 12, 12, 9, Color(0.55, 0.25, 0.75))
	_fill_diamond(charm, 10, 9, 3, Color(0.8, 0.55, 0.95))
	_save(charm, "charm_of_warding")

	_save(_bottle(Color(0.8, 0.15, 0.15)), "healing_potion")
	_save(_bottle(Color(0.15, 0.4, 0.85)), "mana_potion")
	_save(_bottle(Color(0.2, 0.7, 0.25)), "antidote")

	# bone_greatsword: cream blade + brown hilt
	var sword := _new_img()
	_fill_diamond(sword, 12, 10, 9, Color(0.92, 0.9, 0.82))
	_fill_rect(sword, 10, 17, 14, 21, Color(0.4, 0.28, 0.15))
	_fill_rect(sword, 6, 15, 18, 17, Color(0.55, 0.4, 0.2)) # crossguard
	_save(sword, "bone_greatsword")

	# royal_plate: blue-grey shield
	var plate := _new_img()
	_fill_rect(plate, 5, 4, 19, 14, Color(0.55, 0.62, 0.7))
	# _fill_triangle_up() widens top->base; a shield's point needs the
	# opposite (wide at top, narrowing down to a point), so draw it directly.
	for y in range(14, 21):
		var t: float = float(y - 14) / 6.0
		var half: float = 7.0 * (1.0 - t)
		_fill_rect(plate, int(12 - half), y, int(12 + half) + 1, y + 1, Color(0.55, 0.62, 0.7))
	_fill_rect(plate, 9, 7, 15, 11, Color(0.75, 0.8, 0.85))
	_save(plate, "royal_plate")

	# magic_crystal: bright cyan gem
	var crystal := _new_img()
	_fill_diamond(crystal, 12, 12, 10, Color(0.2, 0.85, 0.9))
	_fill_diamond(crystal, 9, 8, 3, Color(0.75, 0.98, 1.0))
	_save(crystal, "magic_crystal")

func _build_spells() -> void:
	# fireball: layered orange/red circles + flame tip
	var fire := _new_img()
	_fill_circle(fire, 12, 15, 8, Color(0.9, 0.4, 0.1))
	_fill_circle(fire, 12, 15, 4.5, Color(1.0, 0.7, 0.2))
	_fill_triangle_up(fire, 12, 2, 9, 4, Color(0.95, 0.55, 0.15))
	_save(fire, "fireball")

	# heal: 4-point sparkle (two overlapping diamonds)
	var heal := _new_img()
	_fill_diamond(heal, 12, 12, 10, Color(1.0, 0.95, 0.6))
	_fill_diamond(heal, 12, 12, 4, Color(1.0, 1.0, 0.85))
	_save(heal, "heal")

func _initialize() -> void:
	print("=== Item icon generation starting ===")
	_build_items()
	_build_spells()
	print("=== Icons saved to res://assets/icons/ ===")
	quit()
