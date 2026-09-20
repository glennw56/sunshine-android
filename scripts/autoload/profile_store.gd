extends Node
## Device vault for COS player_id + avatar recipes.
## Survives logout. Bound to Square customer_id when signed in.
## Signed-in forever store: bakery-drinks GET/PUT /order/api/account/avatar
## (Square customer custom attribute on Cloud Run). Local vault is the offline cache.

signal avatar_changed(recipe: Dictionary)
signal identity_changed

const VAULT_PATH := "user://profile_vault.json"
const CosContracts := preload("res://scripts/contracts/cos_contracts.gd")

var player_id: String = ""
var username: String = ""
var display_name: String = ""
var avatar: Dictionary = {}
var _vault: Dictionary = {}
var _syncing := false
var last_remote_ok := false
var last_remote_error := ""


func _ready() -> void:
	_load_vault()
	_ensure_player_id()
	_hydrate_session()


func current_avatar() -> Dictionary:
	return CosContracts.sanitize_avatar(avatar)


func public_profile() -> Dictionary:
	return CosContracts.public_profile(player_id, username, display_name, current_avatar())


func needs_customize() -> bool:
	if not AccountClient.is_logged_in():
		return false
	var account := _account_row(GameSave.square_customer_id)
	return account.is_empty() or not bool(account.get("customized", false))


func refresh_from_server() -> void:
	if not AccountClient.is_logged_in():
		return
	var result := await _get_remote_avatar()
	if not bool(result.get("ok", false)):
		last_remote_ok = false
		last_remote_error = str(result.get("error", "avatar GET failed"))
		return
	var data: Variant = result.get("data", {})
	if data is Dictionary:
		last_remote_ok = true
		last_remote_error = ""
		_apply_remote(data)


func can_customize() -> bool:
	return AccountClient.is_logged_in()


func set_display_name(value: String) -> String:
	var err := CosContracts.display_name_error(value)
	if err != "":
		return err
	display_name = value.strip_edges()
	GameSave.set_player_name(display_name)
	_persist_account()
	identity_changed.emit()
	return ""


func set_username(value: String) -> String:
	var err := CosContracts.username_error(value)
	if err != "":
		return err
	var name := CosContracts.normalize_username(value)
	if _username_taken(name):
		return "That username is already used on this device."
	username = name
	_persist_account()
	identity_changed.emit()
	return ""


func save_avatar(raw: Dictionary, mark_customized: bool = true) -> Dictionary:
	var recipe := CosContracts.sanitize_avatar(raw)
	avatar = recipe
	GameSave.avatar_recipe = recipe
	GameSave.persist()
	_persist_account(mark_customized)
	avatar_changed.emit(recipe)
	if AccountClient.is_logged_in():
		await _sync_remote(recipe)
	return recipe


func on_login() -> void:
	_ensure_player_id()
	var cid := GameSave.square_customer_id.strip_edges()
	if cid == "":
		return
	var row := _account_row(cid)
	if not row.is_empty():
		username = CosContracts.normalize_username(str(row.get("username", username)))
		display_name = CosContracts.sanitize_display_name(
			str(row.get("display_name", "")),
			AccountClient.first_name() if AccountClient.first_name() != "" else "Sunshine Guest"
		)
		avatar = CosContracts.sanitize_avatar(row.get("avatar", {}) if row.get("avatar") is Dictionary else {})
	else:
		display_name = CosContracts.sanitize_display_name(
			AccountClient.first_name() if AccountClient.first_name() != "" else GameSave.player_name,
			"Sunshine Guest"
		)
		if username == "":
			username = _suggest_username(display_name)
		avatar = CosContracts.sanitize_avatar(GameSave.avatar_recipe)
		_persist_account(false)
	GameSave.player_id = player_id
	GameSave.avatar_recipe = current_avatar()
	GameSave.game_username = username
	GameSave.game_display_name = display_name
	GameSave.set_player_name(display_name)
	GameSave.persist()
	identity_changed.emit()
	avatar_changed.emit(current_avatar())
	if AccountClient.has_session_token():
		refresh_from_server()


func on_logout() -> void:
	_persist_account(bool(_account_row(GameSave.square_customer_id).get("customized", false)))
	username = ""
	display_name = "Sunshine Guest"
	avatar = CosContracts.default_avatar()
	GameSave.avatar_recipe = avatar
	GameSave.game_username = ""
	GameSave.game_display_name = ""
	identity_changed.emit()
	avatar_changed.emit(avatar)


func _hydrate_session() -> void:
	if AccountClient.is_logged_in():
		on_login()
		return
	avatar = CosContracts.sanitize_avatar(GameSave.avatar_recipe)
	if display_name == "":
		display_name = CosContracts.sanitize_display_name(GameSave.player_name)


func _ensure_player_id() -> void:
	player_id = str(_vault.get("player_id", "")).strip_edges()
	if player_id == "":
		player_id = str(GameSave.player_id).strip_edges()
	if player_id == "":
		player_id = CosContracts.new_player_id()
	_vault["player_id"] = player_id
	GameSave.player_id = player_id
	_write_vault()


func _account_row(customer_id: String) -> Dictionary:
	var cid := customer_id.strip_edges()
	if cid == "":
		return {}
	var accounts: Variant = _vault.get("accounts", {})
	if accounts is Dictionary and accounts.get(cid) is Dictionary:
		return accounts[cid]
	return {}


func _persist_account(customized: bool = true) -> void:
	var cid := GameSave.square_customer_id.strip_edges()
	if cid == "":
		_write_vault()
		return
	var accounts: Dictionary = _vault.get("accounts", {}) if _vault.get("accounts") is Dictionary else {}
	accounts[cid] = {
		"player_id": player_id,
		"username": username,
		"display_name": display_name,
		"avatar": current_avatar(),
		"customized": customized,
		"updated_unix": int(Time.get_unix_time_from_system()),
	}
	_vault["accounts"] = accounts
	_vault["player_id"] = player_id
	_write_vault()


func _username_taken(name: String) -> bool:
	var accounts: Variant = _vault.get("accounts", {})
	if not accounts is Dictionary:
		return false
	var cid := GameSave.square_customer_id
	for key in accounts.keys():
		if str(key) == cid:
			continue
		var row: Variant = accounts[key]
		if row is Dictionary and CosContracts.normalize_username(str(row.get("username", ""))) == name:
			return true
	return false


func _suggest_username(from_name: String) -> String:
	var base := CosContracts.normalize_username(from_name)
	if base.length() < 3:
		base = "guest"
	var candidate := base
	var n := 1
	while username_error_or_taken(candidate) != "" and n < 99:
		n += 1
		candidate = "%s%d" % [base.substr(0, 16), n]
	return candidate


func username_error_or_taken(raw: String) -> String:
	var err := CosContracts.username_error(raw)
	if err != "":
		return err
	if _username_taken(CosContracts.normalize_username(raw)):
		return "That username is already used on this device."
	return ""


func _avatar_urls() -> PackedStringArray:
	return AppConfig.avatar_api_urls()


func _get_remote_avatar() -> Dictionary:
	var last: Dictionary = {"ok": false, "error": "no avatar API"}
	for url in _avatar_urls():
		var result: Dictionary = await AccountClient.request_account_json(
			url, HTTPClient.METHOD_GET, "", AccountClient.has_session_token()
		)
		if bool(result.get("ok", false)):
			return result
		last = result
	return last


func _sync_remote(recipe: Dictionary) -> void:
	if _syncing:
		return
	_syncing = true
	last_remote_ok = false
	var body := JSON.stringify({
		"player_id": player_id,
		"username": username,
		"display_name": display_name,
		"avatar_recipe": recipe,
	})
	var last: Dictionary = {}
	for url in _avatar_urls():
		var result: Dictionary = await AccountClient.request_account_json(
			url, HTTPClient.METHOD_PUT, body, AccountClient.has_session_token()
		)
		last = result
		if bool(result.get("ok", false)) and result.get("data") is Dictionary:
			last_remote_ok = true
			last_remote_error = ""
			_apply_remote(result["data"], false)
			_syncing = false
			return
	last_remote_error = str(last.get("error", "avatar PUT failed"))
	_syncing = false


func _apply_remote(data: Dictionary, persist: bool = true) -> void:
	var public: Variant = data.get("public", data)
	if not public is Dictionary:
		return
	var remote_id := str(public.get("player_id", "")).strip_edges()
	if remote_id != "":
		player_id = remote_id
		GameSave.player_id = player_id
	var remote_user := CosContracts.normalize_username(str(public.get("username", "")))
	if remote_user != "":
		username = remote_user
	var remote_name := str(public.get("display_name", "")).strip_edges()
	if remote_name != "":
		display_name = CosContracts.sanitize_display_name(remote_name, display_name)
		GameSave.set_player_name(display_name)
	if public.get("avatar") is Dictionary:
		avatar = CosContracts.sanitize_avatar(public["avatar"])
		GameSave.avatar_recipe = avatar
	var customized := bool(data.get("customized", false)) or remote_id != ""
	if persist:
		_persist_account(customized)
		GameSave.persist()
	identity_changed.emit()
	avatar_changed.emit(current_avatar())


func _load_vault() -> void:
	if not FileAccess.file_exists(VAULT_PATH):
		_vault = {"player_id": "", "accounts": {}}
		return
	var fh := FileAccess.open(VAULT_PATH, FileAccess.READ)
	if fh == null:
		_vault = {"player_id": "", "accounts": {}}
		return
	var parsed: Variant = JSON.parse_string(fh.get_as_text())
	if parsed is Dictionary:
		_vault = parsed
	else:
		_vault = {"player_id": "", "accounts": {}}


func _write_vault() -> void:
	var fh := FileAccess.open(VAULT_PATH, FileAccess.WRITE)
	if fh:
		fh.store_string(JSON.stringify(_vault, "\t"))
