extends RefCounted
class_name GachaSystem

## Tirages (simple / x10) depuis la Brèche, avec pity system.
## Logique pure : ne touche ni aux monnaies ni à l'inventaire (voir PlayerManager.summon).
## Taux et catalogue : Data/characters_db.json · coûts et pity : Data/economy.json.
## Voir GDD.md > Économie pour les règles de conception.

const RARITY_ORDER: Array[String] = ["SSR", "SR", "R"] # du plus rare au plus commun
const RARITY_RANK := {"R": 0, "SR": 1, "SSR": 2}

var rarities: Dictionary = {}
var cost_single: int = 0
var multi_size: int = 10
var multi_discount_pct: int = 0
var multi_guaranteed_min: String = "SR"
var pity_sr_threshold: int = 0
var pity_ssr_threshold: int = 0

## Désactivable uniquement pour mesurer les taux bruts en test.
var pity_enabled: bool = true

## Guerrier mis en avant par la bannière du moment ("" si aucune) et part qu'il occupe
## dans son propre lot de rareté. Les taux par rareté, eux, ne bougent pas d'un iota :
## la vedette redistribue à l'intérieur du lot SSR, elle ne le gonfle pas.
var featured_id: String = ""
var featured_share: float = 0.5

# Compteurs de pity : tirages depuis le dernier SR+ / SSR obtenu. Sauvegardés via to_dict().
var pulls_since_sr: int = 0
var pulls_since_ssr: int = 0

var rng := RandomNumberGenerator.new()

# rareté -> Array de personnages invocables (hors starters)
var _pools: Dictionary = {}

func _init() -> void:
	rng.randomize()
	_load_config()

func _load_config() -> void:
	var db := DataLoader.characters_db()
	var economy := DataLoader.load_json(DataLoader.ECONOMY_PATH)
	var gacha: Dictionary = economy.get("gacha", {})
	var multi: Dictionary = gacha.get("multi_pull", {})
	var pity: Dictionary = gacha.get("pity", {})

	rarities = db.get("rarities", {})
	cost_single = int(gacha.get("cost_single_eclats", 30))
	multi_size = int(multi.get("size", 10))
	multi_discount_pct = int(multi.get("discount_pct", 0))
	multi_guaranteed_min = str(multi.get("guaranteed_min_rarity", "SR"))
	pity_sr_threshold = int(pity.get("sr_threshold", 10))
	pity_ssr_threshold = int(pity.get("ssr_threshold", 50))

	var total_rate := 0.0
	for rarity_id: String in RARITY_ORDER:
		total_rate += get_drop_rate(rarity_id)
		_pools[rarity_id] = []
	if not is_equal_approx(total_rate, 1.0):
		push_error("GachaSystem: les taux de tirage totalisent %.4f au lieu de 1.0" % total_rate)

	for character: Dictionary in db.get("characters", []):
		if character.get("starter", false):
			continue
		var rarity: String = character.get("rarity", "")
		if _pools.has(rarity):
			_pools[rarity].append(character)
	for rarity_id: String in RARITY_ORDER:
		if _pools[rarity_id].is_empty():
			push_error("GachaSystem: aucun personnage invocable de rareté %s" % rarity_id)

func get_drop_rate(rarity: String) -> float:
	return float(rarities.get(rarity, {}).get("drop_rate", 0.0))

func get_cost(multi: bool) -> int:
	if not multi:
		return cost_single
	return roundi(cost_single * multi_size * (100 - multi_discount_pct) / 100.0)

## Tire une rareté selon les taux annoncés, en appliquant le pity (SSR prioritaire sur SR).
func _roll_rarity() -> String:
	pulls_since_sr += 1
	pulls_since_ssr += 1

	if pity_enabled:
		if pulls_since_ssr >= pity_ssr_threshold:
			return "SSR"
		if pulls_since_sr >= pity_sr_threshold:
			return "SR"

	var roll := rng.randf()
	var cumulative := 0.0
	for rarity_id: String in RARITY_ORDER:
		cumulative += get_drop_rate(rarity_id)
		if roll < cumulative:
			return rarity_id
	return "R" # arrondi flottant : les taux totalisent 1.0

func _reset_pity_for(rarity: String) -> void:
	if rarity == "SR":
		pulls_since_sr = 0
	elif rarity == "SSR":
		pulls_since_sr = 0
		pulls_since_ssr = 0

func _pick_character(rarity: String) -> Dictionary:
	var pool: Array = _pools.get(rarity, [])
	if pool.is_empty():
		return {}
	if featured_id != "" and rng.randf() < featured_share:
		for character: Dictionary in pool:
			if character.get("id", "") == featured_id:
				return character
	return pool[rng.randi_range(0, pool.size() - 1)]

## Raretés dont le lot contient un guerrier donné (sert à savoir où la vedette s'applique).
func rarity_of(character_id: String) -> String:
	for rarity_id: String in RARITY_ORDER:
		for character: Dictionary in _pools.get(rarity_id, []):
			if character.get("id", "") == character_id:
				return rarity_id
	return ""

## Un tirage simple. Retourne {"character": Dictionary, "rarity": String}.
func single_pull() -> Dictionary:
	var rarity := _roll_rarity()
	_reset_pity_for(rarity)
	return {"character": _pick_character(rarity), "rarity": rarity}

## Tirage x10 : garantit au moins un personnage de rang multi_guaranteed_min dans le lot.
func multi_pull() -> Array:
	var results: Array = []
	for i in range(multi_size):
		results.append(single_pull())

	var min_rank: int = RARITY_RANK.get(multi_guaranteed_min, 1)
	for r: Dictionary in results:
		if RARITY_RANK.get(r["rarity"], 0) >= min_rank:
			return results

	# Aucun résultat au rang garanti : le dernier tirage du lot est remplacé.
	results[results.size() - 1] = {
		"character": _pick_character(multi_guaranteed_min),
		"rarity": multi_guaranteed_min,
	}
	_reset_pity_for(multi_guaranteed_min)
	return results

func to_dict() -> Dictionary:
	return {"pulls_since_sr": pulls_since_sr, "pulls_since_ssr": pulls_since_ssr}

func from_dict(data: Dictionary) -> void:
	pulls_since_sr = int(data.get("pulls_since_sr", 0))
	pulls_since_ssr = int(data.get("pulls_since_ssr", 0))
