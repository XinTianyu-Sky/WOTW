# CraftingUI.gd
# 制作界面 — 查看配方、消耗材料制作物品
class_name CraftingUI
extends CanvasLayer

@onready var panel: Panel = $CraftingPanel
@onready var recipe_list: ItemList = $CraftingPanel/RecipeList
@onready var detail_label: RichTextLabel = $CraftingPanel/Detail
@onready var craft_btn: Button = $CraftingPanel/CraftBtn
@onready var close_btn: Button = $CraftingPanel/CloseBtn

var _recipes: Array = []
var _selected_recipe: Dictionary = {}

func _ready() -> void:
	hide()
	close_btn.pressed.connect(_close)
	EventBus.menu_opened.connect(_on_menu_opened)
	recipe_list.item_selected.connect(_on_recipe_selected)
	craft_btn.pressed.connect(_on_craft)

func _close() -> void:
	hide()
	EventBus.menu_closed.emit("crafting")

func _on_menu_opened(menu_name: String) -> void:
	if menu_name == "crafting":
		show()
		_refresh()
	else:
		hide()

func _refresh() -> void:
	_recipes = DataManager.get_recipes()
	recipe_list.clear()
	detail_label.text = ""
	craft_btn.hide()
	_selected_recipe = {}

	for recipe in _recipes:
		recipe_list.add_item(recipe.get("name", "???"))

func _on_recipe_selected(idx: int) -> void:
	if idx < 0 or idx >= _recipes.size():
		return
	_selected_recipe = _recipes[idx]

	var text = "[b]%s[/b]\n\n" % _selected_recipe.get("name", "")
	text += "[b]所需材料:[/b]\n"

	var copper = GameManager.player_data.get("copper", 0)
	var can_craft = true

	for mat in _selected_recipe.get("materials", []):
		var item_id = mat["itemId"]
		var required = mat["count"]
		var owned = GameManager.inv_get_count(item_id)
		var color = "green" if owned >= required else "red"
		text += "  %s x%d [color=%s](拥有:%d)[/color]\n" % [_get_item_name(item_id), required, color, owned]
		if owned < required:
			can_craft = false

	if _selected_recipe.has("copperCost"):
		var cost = _selected_recipe["copperCost"]
		var color = "green" if copper >= cost else "red"
		text += "  铜钱: %d [color=%s](拥有:%d)[/color]\n" % [cost, color, copper]
		if copper < cost:
			can_craft = false

	detail_label.text = text
	craft_btn.disabled = not can_craft
	craft_btn.show()

func _on_craft() -> void:
	if _selected_recipe.is_empty():
		return

	var copper = GameManager.player_data.get("copper", 0)

	# 检查材料
	for mat in _selected_recipe.get("materials", []):
		if GameManager.inv_get_count(mat["itemId"]) < mat["count"]:
			return

	# 检查铜钱
	var cost = _selected_recipe.get("copperCost", 0)
	if copper < cost:
		return

	# 消耗材料
	for mat in _selected_recipe.get("materials", []):
		GameManager.inv_remove(mat["itemId"], mat["count"])

	# 消耗铜钱
	GameManager.player_data["copper"] = copper - cost

	# 添加产物
	var result_id = _selected_recipe.get("resultItem", "")
	GameManager.inv_add(result_id)

	var item_data = DataManager.get_item(result_id)
	NotificationManager.notify("制作成功：%s" % item_data.get("name", result_id))

	_refresh()
	if _recipes.size() > 0:
		_on_recipe_selected(recipe_list.get_selected_items()[0] if recipe_list.get_selected_items().size() > 0 else -1)

func _get_item_name(item_id: String) -> String:
	var data = DataManager.get_item(item_id)
	return data.get("name", item_id)
