extends Node
## Runtime config. Priority: OS env → user://config.cfg → project.godot [sunshine].

const USER_CFG := "user://config.cfg"
const WARM_SCENES: PackedStringArray = [
	"res://scenes/main_menu.tscn",
	"res://scenes/order/order.tscn",
	"res://scenes/explore/explore_3d.tscn",
	"res://scenes/explore/customize.tscn",
]

const GOOGLE_TEST_APP_ID := "ca-app-pub-3940256099942544~3347511713"
const GOOGLE_TEST_REWARDED_UNIT := "ca-app-pub-3940256099942544/5224354917"
## Ronald AdMob console (glenn.will799@gmail.com). Play listing link is a CoS follow-up.
const PRODUCTION_APP_ID := "ca-app-pub-2788636443838183~1520526800"
const PRODUCTION_REWARDED_UNIT := "ca-app-pub-2788636443838183/7894363467"

var order_base_url: String = "https://bakery-drinks-k6uuoen7wa-ue.a.run.app"
var explore_base_url: String = "https://sunshine-explore-k6uuoen7wa-ue.a.run.app"
var order_path: String = "/order"
var ad_mode: String = "live"
var admob_app_id: String = PRODUCTION_APP_ID
var admob_rewarded_unit: String = PRODUCTION_REWARDED_UNIT
var staff_pin: String = ""
var bakery_name: String = "Sunshine's Bakery"
var bakery_address: String = "2231 1st Ave S, Irondale AL 35210"
var fresh_batch_mode: String = "auto"


func _ready() -> void:
	_load_project_defaults()
	_load_user_cfg()
	_load_env()
	order_base_url = order_base_url.rstrip("/")
	if not order_path.begins_with("/"):
		order_path = "/" + order_path


func _load_project_defaults() -> void:
	order_base_url = str(ProjectSettings.get_setting("sunshine/order_base_url", order_base_url))
	explore_base_url = str(ProjectSettings.get_setting("sunshine/explore_base_url", explore_base_url))
	order_path = str(ProjectSettings.get_setting("sunshine/order_path", order_path))
	ad_mode = str(ProjectSettings.get_setting("sunshine/ad_mode", ad_mode)).to_lower()
	admob_app_id = str(ProjectSettings.get_setting("sunshine/admob_app_id", admob_app_id))
	admob_rewarded_unit = str(ProjectSettings.get_setting("sunshine/admob_rewarded_unit", admob_rewarded_unit))
	staff_pin = str(ProjectSettings.get_setting("sunshine/staff_pin", staff_pin))
	bakery_name = str(ProjectSettings.get_setting("sunshine/bakery_name", bakery_name))
	bakery_address = str(ProjectSettings.get_setting("sunshine/bakery_address", bakery_address))
	fresh_batch_mode = str(ProjectSettings.get_setting("sunshine/fresh_batch_mode", fresh_batch_mode)).to_lower()


func _load_user_cfg() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(USER_CFG) != OK:
		return
	order_base_url = str(cfg.get_value("sunshine", "order_base_url", order_base_url))
	explore_base_url = str(cfg.get_value("sunshine", "explore_base_url", explore_base_url))
	ad_mode = str(cfg.get_value("sunshine", "ad_mode", ad_mode)).to_lower()
	fresh_batch_mode = str(cfg.get_value("sunshine", "fresh_batch_mode", fresh_batch_mode)).to_lower()
	admob_app_id = str(cfg.get_value("sunshine", "admob_app_id", admob_app_id))
	admob_rewarded_unit = str(cfg.get_value("sunshine", "admob_rewarded_unit", admob_rewarded_unit))
	staff_pin = str(cfg.get_value("sunshine", "staff_pin", staff_pin))


func _load_env() -> void:
	_env_str("SUNSHINE_ORDER_URL", "order_base_url")
	_env_str("SUNSHINE_EXPLORE_URL", "explore_base_url")
	_env_str("SUNSHINE_AD_MODE", "ad_mode")
	_env_str("SUNSHINE_ADMOB_APP_ID", "admob_app_id")
	_env_str("SUNSHINE_ADMOB_REWARDED_UNIT", "admob_rewarded_unit")
	_env_str("SUNSHINE_STAFF_PIN", "staff_pin")
	_env_str("SUNSHINE_FRESH_BATCH", "fresh_batch_mode")
	ad_mode = ad_mode.to_lower()
	fresh_batch_mode = fresh_batch_mode.to_lower()


func _env_str(key: String, field: String) -> void:
	var value := OS.get_environment(key).strip_edges()
	if value != "":
		set(field, value)


func order_url() -> String:
	return order_base_url + order_path


func menu_api() -> String:
	return order_base_url + "/order/api/menu"


func square_online_origin() -> String:
	return "https://www.sunshinebakeshop.com"


func square_commerce_links() -> String:
	## Public Square Online catalog (same merchant as bakery-drinks drinks).
	return square_online_origin() + "/app/website/cms/api/v1/sites/30aacb50-1317-11ef-ad4f-279b7b292d3d/commerce-links"


func square_store_catalog() -> String:
	## Published Square Online storefront catalog (Fastly-cached /v28/editor).
	## Each product includes price.low_subunits — commerce-links does not.
	return (
		"https://cdn5.editmysite.com/app/store/api/v28/editor/users/149698726"
		+ "/sites/159839133986356010/store-locations/L4CK6YWGT5XQX/products"
		+ "?per_page=100&include=images,options,modifiers&cache-version=2026-03-25"
	)


func checkout_api() -> String:
	return order_base_url + "/order/api/checkout"


func status_api() -> String:
	return order_base_url + "/order/api/status"


func account_phone_api() -> String:
	return order_base_url + "/order/api/account/phone"


func account_profile_api() -> String:
	## Live bakery-drinks: POST with Bearer session + given_name, family_name, email.
	return order_base_url + "/order/api/account/profile"


func customer_profile_api() -> String:
	return order_base_url + "/order/api/customer/profile"


func account_avatar_api() -> String:
	## Live bakery-drinks after the avatar-forever drinks redeploy.
	## 404 means Cloud Run has not been updated yet; the local vault still works.
	return order_base_url + "/order/api/account/avatar"


func explore_http_origin() -> String:
	var url := explore_base_url.strip_edges().rstrip("/")
	if url == "":
		return order_base_url
	return url


func explore_ws_url() -> String:
	var origin := explore_http_origin()
	if origin.begins_with("https://"):
		return "wss://" + origin.substr(8) + "/explore/ws"
	if origin.begins_with("http://"):
		return "ws://" + origin.substr(7) + "/explore/ws"
	return ""


func explore_ticket_api() -> String:
	return explore_http_origin() + "/explore/ticket"


func explore_tick_api() -> String:
	return explore_http_origin() + "/explore/tick"


func explore_avatar_api() -> String:
	var pid := ProfileStore.player_id.strip_edges().uri_encode() if ProfileStore else ""
	var url := explore_http_origin() + "/order/api/account/avatar"
	if pid != "":
		url += "?player_id=" + pid
	return url


func avatar_api_urls() -> PackedStringArray:
	var urls := PackedStringArray()
	urls.append(account_avatar_api())
	if explore_base_url.strip_edges() != "" and explore_base_url.rstrip("/") != order_base_url:
		urls.append(explore_avatar_api())
	return urls


func account_login_api() -> String:
	return order_base_url + "/order/api/account/login"


func login_api() -> String:
	return order_base_url + "/order/api/login"


func session_api() -> String:
	return order_base_url + "/order/api/session"


func account_me_api() -> String:
	return order_base_url + "/order/api/me"


func account_api() -> String:
	return order_base_url + "/order/api/account"


func account_status_api() -> String:
	return order_base_url + "/order/api/account/status"


func customer_api() -> String:
	return order_base_url + "/order/api/customer"


func customer_orders_api() -> String:
	return order_base_url + "/order/api/orders"


func account_order_api(order_id: String) -> String:
	var oid := order_id.strip_edges().uri_encode()
	return order_base_url + "/order/api/account/orders/" + oid


func customer_order_api(order_id: String) -> String:
	var oid := order_id.strip_edges().uri_encode()
	return order_base_url + "/order/api/orders/" + oid


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


func is_live_ads() -> bool:
	return ad_mode == "live"


func is_debug_sideload() -> bool:
	return OS.is_debug_build()


func should_use_google_test_unit() -> bool:
	## Debug APKs use Google sample rewarded ads. Production Play AABs use tip_reward.
	## Play package is not linked in AdMob yet, so live units often return no-fill.
	return is_test_ads() or is_debug_sideload()


func effective_app_id() -> String:
	## Manifest APPLICATION_ID stays production. Test/debug only swaps the rewarded unit.
	if should_use_google_test_unit():
		return GOOGLE_TEST_APP_ID
	return admob_app_id.strip_edges()


func effective_rewarded_unit() -> String:
	if should_use_google_test_unit():
		return GOOGLE_TEST_REWARDED_UNIT
	return admob_rewarded_unit.strip_edges()


func uses_google_sample_ids() -> bool:
	return effective_rewarded_unit() == GOOGLE_TEST_REWARDED_UNIT or effective_app_id() == GOOGLE_TEST_APP_ID


func warmup_ui_scenes() -> void:
	## Load Menu / Order / Explore off the tap path so navigation does not hitch on parse.
	for path in WARM_SCENES:
		if ResourceLoader.has_cached(path):
			continue
		ResourceLoader.load_threaded_request(path)


func go(path: String) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var status := ResourceLoader.load_threaded_get_status(path)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		var packed: Resource = ResourceLoader.load_threaded_get(path)
		if packed is PackedScene:
			tree.change_scene_to_packed(packed as PackedScene)
			ResourceLoader.load_threaded_request(path)
			return
	tree.change_scene_to_file(path)
