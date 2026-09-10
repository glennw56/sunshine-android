extends Node
## Runtime config. Priority: OS env → user://config.cfg → project.godot [sunshine].

const USER_CFG := "user://config.cfg"

var order_base_url: String = "https://bakery-drinks-k6uuoen7wa-ue.a.run.app"
var order_path: String = "/order"
var ad_mode: String = "mock"
var admob_app_id: String = "ca-app-pub-3940256099942544~3347511713"
var admob_rewarded_unit: String = "ca-app-pub-3940256099942544/5224354917"
var staff_pin: String = ""
var bakery_name: String = "Sunshine's Bakery"
var bakery_address: String = "2231 1st Ave S, Irondale AL 35210"


func _ready() -> void:
	_load_project_defaults()
	_load_user_cfg()
	_load_env()
	order_base_url = order_base_url.rstrip("/")
	if not order_path.begins_with("/"):
		order_path = "/" + order_path


func _load_project_defaults() -> void:
	order_base_url = str(ProjectSettings.get_setting("sunshine/order_base_url", order_base_url))
	order_path = str(ProjectSettings.get_setting("sunshine/order_path", order_path))
	ad_mode = str(ProjectSettings.get_setting("sunshine/ad_mode", ad_mode)).to_lower()
	admob_app_id = str(ProjectSettings.get_setting("sunshine/admob_app_id", admob_app_id))
	admob_rewarded_unit = str(ProjectSettings.get_setting("sunshine/admob_rewarded_unit", admob_rewarded_unit))
	staff_pin = str(ProjectSettings.get_setting("sunshine/staff_pin", staff_pin))
	bakery_name = str(ProjectSettings.get_setting("sunshine/bakery_name", bakery_name))
	bakery_address = str(ProjectSettings.get_setting("sunshine/bakery_address", bakery_address))


func _load_user_cfg() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(USER_CFG) != OK:
		return
	order_base_url = str(cfg.get_value("sunshine", "order_base_url", order_base_url))
	ad_mode = str(cfg.get_value("sunshine", "ad_mode", ad_mode)).to_lower()
	admob_app_id = str(cfg.get_value("sunshine", "admob_app_id", admob_app_id))
	admob_rewarded_unit = str(cfg.get_value("sunshine", "admob_rewarded_unit", admob_rewarded_unit))
	staff_pin = str(cfg.get_value("sunshine", "staff_pin", staff_pin))


func _load_env() -> void:
	_env_str("SUNSHINE_ORDER_URL", "order_base_url")
	_env_str("SUNSHINE_AD_MODE", "ad_mode")
	_env_str("SUNSHINE_ADMOB_APP_ID", "admob_app_id")
	_env_str("SUNSHINE_ADMOB_REWARDED_UNIT", "admob_rewarded_unit")
	_env_str("SUNSHINE_STAFF_PIN", "staff_pin")
	ad_mode = ad_mode.to_lower()


func _env_str(key: String, field: String) -> void:
	var value := OS.get_environment(key).strip_edges()
	if value != "":
		set(field, value)


func order_url() -> String:
	return order_base_url + order_path


func menu_api() -> String:
	return order_base_url + "/order/api/menu"


func checkout_api() -> String:
	return order_base_url + "/order/api/checkout"


func status_api() -> String:
	return order_base_url + "/order/api/status"


func board_url() -> String:
	return order_base_url + "/board"


func board_tickets_api(minutes: int = 180) -> String:
	return "%s/board/tickets?minutes=%d" % [order_base_url, minutes]


func board_demo_tick_api(minutes: int = 180) -> String:
	return "%s/board/demo-tick?minutes=%d" % [order_base_url, minutes]


func save_user_overrides(overrides: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.load(USER_CFG)
	for key in overrides.keys():
		cfg.set_value("sunshine", str(key), overrides[key])
	cfg.save(USER_CFG)
	_load_user_cfg()
	_load_env()


func is_mock_ads() -> bool:
	return ad_mode == "mock" or ad_mode == ""


func is_test_ads() -> bool:
	return ad_mode == "test"
