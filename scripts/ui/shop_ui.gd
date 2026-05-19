# ShopUI.gd
# 商店界面：买卖物品
class_name ShopUI
extends CanvasLayer

@onready var panel: Panel = $ShopPanel
@onready var close_btn: Button = $ShopPanel/CloseBtn
@onready var shop_name_label: Label = $ShopPanel/ShopName
@onready var money_label: Label = $ShopPanel/MoneyLabel
@onready var buy_tab: Button = $ShopPanel/TabBar/BuyTab
@onready var sell_tab: Button = $ShopPanel/TabBar/SellTab
@onready var item_list: ItemList = $ShopPanel/ItemList
@onready var item_detail: RichTextLabel = $ShopPanel/ItemDetail
@onready var action_btn: Button = $ShopPanel/ActionBtn
@onready var qty_spin: SpinBox = $ShopPanel/QtySpin

enum Mode { BUY, SELL }

var _shop_data: Dictionary = {}
var _mode: Mode = Mode.BUY
var _selected_item_id: String = ""

func _ready() -> void:
	hide()
	close_btn.pressed.connect(_close)
	buy_tab.pressed.connect(func(): _switch_mode(Mode.BUY))
	sell_tab.pressed.connect(func(): _switch_mode(Mode.SELL))
	item_list.item_selected.connect(_on_item_selected)
	action_btn.pressed.connect(_on_action)
	qty_spin.value_changed.connect(func(_v): _update_action_btn())

func open_shop(shop_id: String) -> void:
	var shops = DataManager.get_data("items").get("shops", [])
	for s in shops:
		if s["id"] == shop_id:
			_shop_data = s
			break
	if _shop_data.is_empty():
		return

	shop_name_label.text = _shop_data.get("name", "商店")
	show()
	_switch_mode(Mode.BUY)
	GameManager.set_phase(GameManager.GamePhase.MENU)

func _switch_mode(mode: Mode) -> void:
	_mode = mode
	buy_tab.button_pressed = (mode == Mode.BUY)
	sell_tab.button_pressed = (mode == Mode.SELL)
	_selected_item_id = ""
	item_detail.text = ""
	action_btn.hide()
	qty_spin.hide()
	_refresh_list()

func _refresh_list() -> void:
	item_list.clear()
	money_label.text = "铜钱: %d" % _get_player_copper()

	if _mode == Mode.BUY:
		for item_id in _shop_data.get("items", []):
			var data = DataManager.get_item(item_id)
			if data.is_empty():
				continue
			var price = _get_buy_price(item_id)
			item_list.add_item("%s  —  %d 文" % [data.get("name", "???"), price])
			item_list.set_item_metadata(item_list.item_count - 1, item_id)
	else:
		var inv = GameManager.player_data.get("inventory", [])
		for item_id in inv:
			var data = DataManager.get_item(item_id)
			if data.is_empty():
				continue
			var price = _get_sell_price(item_id)
			item_list.add_item("%s  —  %d 文" % [data.get("name", "???"), price])
			item_list.set_item_metadata(item_list.item_count - 1, item_id)

func _on_item_selected(idx: int) -> void:
	_selected_item_id = item_list.get_item_metadata(idx)
	var data = DataManager.get_item(_selected_item_id)
	if data.is_empty():
		return

	if _mode == Mode.BUY:
		var price = _get_buy_price(_selected_item_id)
		item_detail.text = "[b]%s[/b]\n%s\n\n价格: %d 文" % [data.get("name", ""), data.get("description", ""), price]
		action_btn.text = "购买"
	else:
		var price = _get_sell_price(_selected_item_id)
		item_detail.text = "[b]%s[/b]\n%s\n\n回收价: %d 文" % [data.get("name", ""), data.get("description", ""), price]
		action_btn.text = "出售"

	qty_spin.value = 1
	qty_spin.max_value = 99
	qty_spin.show()
	action_btn.show()
	_update_action_btn()

func _update_action_btn() -> void:
	if _mode == Mode.BUY:
		var total = _get_buy_price(_selected_item_id) * int(qty_spin.value)
		action_btn.text = "购买 x%d (%d 文)" % [int(qty_spin.value), total]
		action_btn.disabled = total > _get_player_copper()
	else:
		var total = _get_sell_price(_selected_item_id) * int(qty_spin.value)
		action_btn.text = "出售 x%d (%d 文)" % [int(qty_spin.value), total]

func _on_action() -> void:
	var qty = int(qty_spin.value)
	if _mode == Mode.BUY:
		_buy_item(_selected_item_id, qty)
	else:
		_sell_item(_selected_item_id, qty)
	_refresh_list()
	_selected_item_id = ""
	item_detail.text = ""
	action_btn.hide()
	qty_spin.hide()

func _close() -> void:
	hide()
	GameManager.set_phase(GameManager.GamePhase.WORLD_EXPLORATION)

func _buy_item(item_id: String, qty: int) -> void:
	var price = _get_buy_price(item_id) * qty
	var copper = _get_player_copper()
	if copper < price:
		return
	_set_player_copper(copper - price)
	var inv: Array = GameManager.player_data.get("inventory", [])
	for _i in range(qty):
		inv.append(item_id)
	GameManager.player_data["inventory"] = inv
	NotificationManager.notify("购买了 %s x%d" % [DataManager.get_item(item_id).get("name", ""), qty])

func _sell_item(item_id: String, qty: int) -> void:
	var inv: Array = GameManager.player_data.get("inventory", [])
	var sold = 0
	for _i in range(qty):
		var idx = inv.find(item_id)
		if idx == -1:
			break
		inv.remove_at(idx)
		sold += 1
	if sold == 0:
		return
	GameManager.player_data["inventory"] = inv
	var price = _get_sell_price(item_id) * sold
	_set_player_copper(_get_player_copper() + price)
	NotificationManager.notify("出售了 %s x%d" % [DataManager.get_item(item_id).get("name", ""), sold])

func _get_buy_price(item_id: String) -> int:
	var data = DataManager.get_item(item_id)
	var base = data.get("price", 10)
	var discount = _shop_data.get("discount", 0.0)
	return max(1, int(base * (1.0 - discount)))

func _get_sell_price(item_id: String) -> int:
	var data = DataManager.get_item(item_id)
	return max(1, int(data.get("price", 10) * 0.5))

func _get_player_copper() -> int:
	return GameManager.player_data.get("copper", 0)

func _set_player_copper(v: int) -> void:
	GameManager.player_data["copper"] = v
