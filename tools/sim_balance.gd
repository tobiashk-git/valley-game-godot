extends SceneTree
# Combat balance simulator. Run via:
#   godot --headless --script res://tools/sim_balance.gd
# Writes res://balance_report.md and prints the same tables.
#
# Fights thousands of battles against the REAL enemy registry (Enemies.ENEMIES
# / BOSSES) and item table (Items.ITEMS) with a stand-in for the combat loop
# (combat.gd's turn order, attack power STR*2 + weapon, agility dodge, Defend
# not used, statuses ignored) so numbers can be tuned before anything the
# phone sees changes. Two things are pluggable:
#
#   MODELS   - the damage rule + potion/heal strengths + an enemy attack
#              multiplier ("current" = combat.gd today; "mitigation" = the
#              proposed percentage armour).
#   PROFILES - a player at a level with a GEAR LIST. Defence and attack are
#              summed over every listed piece whatever its slot, so future
#              helmets / boots / trousers are just more entries (or use
#              "extra_defense" to try a hypothetical set before its items
#              exist).
#
# Metrics per profile x arena: win rate, HP lost per fight (% of max),
# potions used per fight, and "fights per trip" - consecutive random
# encounters (60/30/10 solo/duo/trio, as the game rolls them) until HP would
# drop under 25% (time to head for the bed) or a loss. Plus a boss matrix.

const RUNS := 400
const TRIPS := 300
const POTION_AT := 0.35 # the sim drinks below 35% HP (a cautious player)
const BED_AT := 0.25    # a trip ends when HP is under 25% (walk home)

const MODELS := {
	"current": {"kind": "subtract", "k": 0.0, "enemy_atk_mult": 1.0, "potion_heal": 15, "heal_spell": 15, "heal_cost": 4},
	"mitigation": {"kind": "mitigate", "k": 8.0, "enemy_atk_mult": 2.0, "potion_heal": 8, "heal_spell": 10, "heal_cost": 5},
}

const PROFILES := [
	{"name": "L1 leather", "level": 1, "gear": ["wooden_pickaxe", "leather_armor"], "potions": 3, "extra_defense": 0},
	{"name": "L3 frost", "level": 3, "gear": ["frost_pick", "frostweave_coat"], "potions": 3, "extra_defense": 0},
	{"name": "L5 ironwood", "level": 5, "gear": ["ironwood_blade", "ironwood_mail"], "potions": 3, "extra_defense": 0},
	{"name": "L8 ember", "level": 8, "gear": ["ember_blade", "ember_plate"], "potions": 3, "extra_defense": 0},
	{"name": "L12 bog-iron", "level": 12, "gear": ["bogiron_cleaver", "bogiron_harness"], "potions": 3, "extra_defense": 0},
	# A hypothetical full set (helmet + boots + trousers worth +6 on top of the mail).
	{"name": "L5 ironwood +set", "level": 5, "gear": ["ironwood_blade", "ironwood_mail"], "potions": 3, "extra_defense": 6},
]

# --sweep: instead of the full report, try variants of the mitigation model
# (enemy attack multiplier x curve constant k) on a handful of target cells
# and print one line per variant. Targets: a fresh L1 in leather should win
# ~90% of dungeon fights and manage 4-6 before the bed; the Bone Lord should
# be a coin flip for L1-2 with potions; each tier boss ~70-90% with matching
# tier gear and hard (~30%) one tier below.
const SWEEP_MULTS := [1.3, 1.5, 1.7]
const SWEEP_KS := [6.0, 8.0, 10.0]

var _rng := RandomNumberGenerator.new()
var _lines: Array[String] = []

func _initialize() -> void:
	_rng.seed = 12345
	if "--sweep" in OS.get_cmdline_user_args():
		_sweep()
		quit()
		return
	var world: Node = root.get_node("World")
	var arenas: Array = [
		{"name": "Dungeon", "zone": -1},
		{"name": "Frostpeak", "zone": world.Zone.FROSTPEAK},
		{"name": "Verdantwood", "zone": world.Zone.VERDANTWOOD},
		{"name": "Badlands", "zone": world.Zone.BADLANDS},
		{"name": "Gloomfen", "zone": world.Zone.GLOOMFEN},
	]
	_out("# Combat balance report")
	_out("")
	_out("%d fights and %d trips per cell, seed %d. Potion below %d%% HP, trip ends under %d%% HP. Statuses ignored." % [RUNS, TRIPS, _rng.seed, int(POTION_AT * 100), int(BED_AT * 100)])
	for model_name in MODELS.keys():
		var model: Dictionary = MODELS[model_name]
		_out("")
		_out("## Model: %s  (%s)" % [model_name, _describe_model(model)])
		_out("")
		_out("Profiles: " + ", ".join(PROFILES.map(func(p): return "%s (HP %d, ATK %d, DEF %d)" % [p.name, _stats(p).max_hp, _stats(p).power, _stats(p).defense])))
		_out("")
		_out("| profile | arena | win % | HP lost / fight | potions / fight | fights / trip | fights / trip, no potions |")
		_out("|---|---|---|---|---|---|---|")
		for profile in PROFILES:
			for arena in arenas:
				var pool: Array = _pool(arena.zone)
				var r: Dictionary = _run_cell(model, profile, pool)
				_out("| %s | %s | %d | %d%% | %.2f | %.1f | %.1f |" % [profile.name, arena.name, r.win_pct, r.hp_lost_pct, r.potions, r.trip, r.trip_dry])
		_out("")
		_out("### Bosses (win %% with the profile's %d potions / with none)" % PROFILES[0].potions)
		_out("")
		var bosses: Dictionary = root.get_node("Enemies").BOSSES
		var head := "| profile |"
		var sep := "|---|"
		for boss_id in bosses.keys():
			head += " %s |" % bosses[boss_id].name
			sep += "---|"
		_out(head)
		_out(sep)
		for profile in PROFILES:
			var row := "| %s |" % profile.name
			for boss_id in bosses.keys():
				var with_p: int = _win_rate(model, profile, [bosses[boss_id]], profile.potions)
				var dry: int = _win_rate(model, profile, [bosses[boss_id]], 0)
				row += " %d / %d |" % [with_p, dry]
			_out(row)
	var f := FileAccess.open("res://balance_report.md", FileAccess.WRITE)
	f.store_string("\n".join(_lines) + "\n")
	f.close()
	print("wrote res://balance_report.md")
	quit()

func _out(line: String) -> void:
	_lines.append(line)
	print(line)

func _describe_model(m: Dictionary) -> String:
	if m.kind == "subtract":
		return "damage = attack - defence, min 1; potion %d, Heal %d for %d MP" % [m.potion_heal, m.heal_spell, m.heal_cost]
	return "damage = attack x %d/(%d+defence); enemy attack x%.1f; potion %d, Heal %d for %d MP" % [int(m.k), int(m.k), m.enemy_atk_mult, m.potion_heal, m.heal_spell, m.heal_cost]

# --- player ---

func _stats(profile: Dictionary) -> Dictionary:
	var items: Dictionary = root.get_node("Items").ITEMS
	var level: int = profile.level
	var defense: int = profile.get("extra_defense", 0)
	var weapon := 0
	for id in profile.gear:
		var def: Dictionary = items[id]
		defense += int(def.get("defense", 0))
		weapon += int(def.get("attack", 0))
	var strength: int = 5 + (level - 1)
	var agility: int = 5 + int(level / 2)
	return {
		"max_hp": 20 + 4 * (level - 1),
		"max_mp": 10 + 2 * (level - 1),
		"power": strength * 2 + weapon,
		"defense": defense,
		"dodge": clampf((agility - 5) * 0.02, 0.0, 0.3),
	}

# --- enemies ---

func _pool(zone: int) -> Array:
	var enemies: Dictionary = root.get_node("Enemies").ENEMIES
	var out: Array = []
	for id in enemies.keys():
		var zones: Array = enemies[id].zones
		if (zone == -1 and zones.is_empty()) or (zone != -1 and zones.has(zone)):
			out.append(enemies[id])
	return out

func _group(pool: Array) -> Array:
	var roll := _rng.randf()
	var size := 1
	if roll < 0.10:
		size = 3
	elif roll < 0.40:
		size = 2
	var g: Array = []
	for i in range(size):
		g.append(pool[_rng.randi() % pool.size()])
	return g

# --- the fight ---

func _damage(model: Dictionary, power: float, defense: float) -> int:
	var base: float
	if model.kind == "subtract":
		base = power - defense
	else:
		base = power * model.k / (model.k + defense)
	var variance: float = base * (_rng.randf() * 0.3 - 0.15)
	return max(1, int(round(base + variance)))

# Returns {won, hp_lost, potions_used}; `player` is mutated (hp, mp, potions).
func _fight(model: Dictionary, stats: Dictionary, player: Dictionary, defs: Array) -> Dictionary:
	var enemies: Array = []
	for d in defs:
		enemies.append({"hp": d.max_hp, "attack": int(round(d.attack * model.enemy_atk_mult)), "defense": d.defense})
	var hp_start: int = player.hp
	var potions_start: int = player.potions
	var turns := 0
	while turns < 200:
		turns += 1
		# Player turn: drink / heal when low, else hit the weakest.
		if player.hp < POTION_AT * stats.max_hp and player.potions > 0:
			player.potions -= 1
			player.hp = mini(stats.max_hp, player.hp + model.potion_heal)
		elif player.hp < POTION_AT * stats.max_hp and player.mp >= model.heal_cost:
			player.mp -= model.heal_cost
			player.hp = mini(stats.max_hp, player.hp + model.heal_spell)
		else:
			var target: Dictionary = {}
			for e in enemies:
				if e.hp > 0 and (target.is_empty() or e.hp < target.hp):
					target = e
			target.hp -= _damage(model, stats.power, target.defense)
		var alive := false
		for e in enemies:
			if e.hp > 0:
				alive = true
		if not alive:
			return {"won": true, "hp_lost": hp_start - player.hp, "potions_used": potions_start - player.potions}
		# Enemy turns.
		for e in enemies:
			if e.hp <= 0:
				continue
			if _rng.randf() < stats.dodge:
				continue
			player.hp -= _damage(model, e.attack, stats.defense)
			if player.hp <= 0:
				return {"won": false, "hp_lost": hp_start, "potions_used": potions_start - player.potions}
	return {"won": false, "hp_lost": hp_start - player.hp, "potions_used": potions_start - player.potions}

func _fresh(stats: Dictionary, potions: int) -> Dictionary:
	return {"hp": stats.max_hp, "mp": stats.max_mp, "potions": potions}

func _run_cell(model: Dictionary, profile: Dictionary, pool: Array) -> Dictionary:
	var stats: Dictionary = _stats(profile)
	var wins := 0
	var lost_total := 0.0
	var potions_total := 0.0
	for i in range(RUNS):
		var p: Dictionary = _fresh(stats, profile.potions)
		var r: Dictionary = _fight(model, stats, p, _group(pool))
		if r.won:
			wins += 1
		lost_total += float(r.hp_lost) / stats.max_hp
		potions_total += r.potions_used
	var trip: float = _trip(model, stats, pool, profile.potions)
	var trip_dry: float = _trip(model, stats, pool, 0)
	return {"win_pct": int(round(100.0 * wins / RUNS)), "hp_lost_pct": int(round(100.0 * lost_total / RUNS)), "potions": potions_total / RUNS, "trip": trip, "trip_dry": trip_dry}

# Consecutive fights from full HP until it's time for the bed (or a loss).
func _trip(model: Dictionary, stats: Dictionary, pool: Array, potions: int) -> float:
	var total := 0
	for i in range(TRIPS):
		var p: Dictionary = _fresh(stats, potions)
		var fights := 0
		while fights < 50:
			var r: Dictionary = _fight(model, stats, p, _group(pool))
			if not r.won:
				break
			fights += 1
			if p.hp < BED_AT * stats.max_hp:
				break
		total += fights
	return float(total) / TRIPS

func _win_rate(model: Dictionary, profile: Dictionary, defs: Array, potions: int) -> int:
	var stats: Dictionary = _stats(profile)
	var wins := 0
	for i in range(RUNS):
		var p: Dictionary = _fresh(stats, potions)
		if _fight(model, stats, p, defs).won:
			wins += 1
	return int(round(100.0 * wins / RUNS))

# --- sweep mode ---
#
# Biome LADDER: outer biomes are all flat today (attack 4-7, HP 14-24) while
# the player's power quadruples with tiers, so mid-game monsters die in a
# hit or two. The sweep scales each zone's HP and attack by steepness^tier
# (dungeon 0, Frostpeak 1, Verdantwood 2, Badlands 3, Gloomfen 4) and each
# boss by its tier too, and tries a few steepness values.
const BOSS_TIER := {"dungeon_boss": 0, "golden_plains_boss": 0, "frostpeak_boss": 1, "verdantwood_boss": 2, "verdantwood_maze_guardian_1": 2, "castle_boss": 3, "badlands_boss": 3, "gloomfen_boss": 4, "final_boss": 5}
const SWEEP_WILD := [1.3]
const SWEEP_BOSS := [1.0]
const SWEEP_STEEP := [1.2] # wild ladder
const SWEEP_BOSS_STEEP := [1.25, 1.3, 1.35] # bosses climb faster than the wilds
const SWEEP_FINAL_TIER := [0, 1, 2] # the Ancient Warden already has end-game stats; try it with little or no ladder

func _scaled(def: Dictionary, m: float) -> Dictionary:
	return {"name": def.name, "max_hp": int(round(def.max_hp * m)), "attack": def.attack * m, "defense": def.defense, "zones": def.get("zones", [])}

func _ladder_pool(zone: int, tier: int, steep: float) -> Array:
	var m: float = pow(steep, tier)
	return _pool(zone).map(func(d): return _scaled(d, m))

func _cell(model: Dictionary, profile: Dictionary, pool: Array) -> String:
	var r: Dictionary = _run_cell(model, profile, pool)
	return "%d%%/%.1f" % [r.win_pct, r.trip]

func _boss(model: Dictionary, profile: Dictionary, boss_id: String, steep: float, tier_override: int = -1) -> int:
	var bosses: Dictionary = root.get_node("Enemies").BOSSES
	var tier: int = BOSS_TIER.get(boss_id, 0) if tier_override < 0 else tier_override
	var boss_model: Dictionary = model.duplicate()
	boss_model.enemy_atk_mult = model.boss_atk_mult
	return _win_rate(boss_model, profile, [_scaled(bosses[boss_id], pow(steep, tier))], 3)

func _profile(name: String, level: int, gear: Array, extra: int = 0) -> Dictionary:
	return {"name": name, "level": level, "gear": gear, "potions": 3, "extra_defense": extra}

func _sweep() -> void:
	var world: Node = root.get_node("World")
	var L1: Dictionary = _profile("L1 leather", 1, ["wooden_pickaxe", "leather_armor"])
	var L3l: Dictionary = _profile("L3 leather", 3, ["wooden_pickaxe", "leather_armor"])
	var L3: Dictionary = _profile("L3 frost", 3, ["frost_pick", "frostweave_coat"])
	var L5: Dictionary = _profile("L5 ironwood", 5, ["ironwood_blade", "ironwood_mail"])
	var L8: Dictionary = _profile("L8 ember", 8, ["ember_blade", "ember_plate"])
	var L12: Dictionary = _profile("L12 bog-iron", 12, ["bogiron_cleaver", "bogiron_harness"])
	var L12s: Dictionary = _profile("L12 bog-iron +set", 12, ["bogiron_cleaver", "bogiron_harness"], 6)
	print("cells = win%/fights-per-trip (wilds) or win% with 3 potions (bosses)")
	print("| wild | boss | steep | L1 dungeon | L1 BoneLord | L2lea BoneLord | L3 frost | L3 Revenant | L5 Revenant | L5 verdant | L5 Bramble | L8 Bramble | L8 badlands | L8 Cinderjaw | L12 gloom | L12 Bogmaw | L12+set Ancient (tier 0/1/2) |")
	print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
	var L2l: Dictionary = _profile("L2 leather", 2, ["wooden_pickaxe", "leather_armor"])
	for wild in SWEEP_WILD:
		for boss in SWEEP_BOSS:
			for steep in SWEEP_STEEP:
				for bsteep in SWEEP_BOSS_STEEP:
					var m: Dictionary = {"kind": "mitigate", "k": 8.0, "enemy_atk_mult": wild, "boss_atk_mult": boss, "potion_heal": 8, "heal_spell": 10, "heal_cost": 5}
					var dungeon: Array = _ladder_pool(-1, 0, steep)
					var frost: Array = _ladder_pool(world.Zone.FROSTPEAK, 1, steep)
					var verdant: Array = _ladder_pool(world.Zone.VERDANTWOOD, 2, steep)
					var badlands: Array = _ladder_pool(world.Zone.BADLANDS, 3, steep)
					var gloom: Array = _ladder_pool(world.Zone.GLOOMFEN, 4, steep)
					var finals: Array = SWEEP_FINAL_TIER.map(func(t): return str(_boss(m, L12s, "final_boss", bsteep, t)))
					print("| %.1f | %.1f | %.2f/%.2f | %s | %d | %d | %s | %d | %d | %s | %d | %d | %s | %d | %s | %d | %s |" % [
						wild, boss, steep, bsteep,
						_cell(m, L1, dungeon), _boss(m, L1, "dungeon_boss", bsteep), _boss(m, L2l, "dungeon_boss", bsteep),
						_cell(m, L3, frost), _boss(m, L3, "frostpeak_boss", bsteep), _boss(m, L5, "frostpeak_boss", bsteep),
						_cell(m, L5, verdant), _boss(m, L5, "verdantwood_boss", bsteep), _boss(m, L8, "verdantwood_boss", bsteep),
						_cell(m, L8, badlands), _boss(m, L8, "badlands_boss", bsteep),
						_cell(m, L12, gloom), _boss(m, L12, "gloomfen_boss", bsteep), "/".join(finals)])
