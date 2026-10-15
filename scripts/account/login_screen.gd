extends Control
## Phone Continue → POST bakery-drinks login. No text-code step. Skip stays guest.
## Nameless Square customers get first / last / email before the main menu.

const BakeryTheme := preload("res://scripts/ui/bakery_theme.gd")
const StorefrontPhoto := preload("res://scripts/ui/storefront_photo.gd")

@onready var _card: PanelContainer = $Safe/Card
@onready var _phone: LineEdit = $Safe/Card/Pad/Col/Phone
@onready var _continue: Button = $Safe/Card/Pad/Col/Continue
@onready var _skip: Button = $Safe/Card/Pad/Col/Skip
@onready var _loyalty: CheckBox = $Safe/Card/Pad/Col/Loyalty
@onready var _status: Label = $Safe/Card/Pad/Col/Status
@onready var _title: Label = $Safe/Card/Pad/Col/Title
@onready var _copy: Label = $Safe/Card/Pad/Col/Copy
@onready var _profile: PanelContainer = $Safe/ProfileCard
@onready var _first: LineEdit = $Safe/ProfileCard/Pad/Col/FirstName
@onready var _last: LineEdit = $Safe/ProfileCard/Pad/Col/LastName
@onready var _email: LineEdit = $Safe/ProfileCard/Pad/Col/Email
@onready var _save: Button = $Safe/ProfileCard/Pad/Col/Save
@onready var _profile_status: Label = $Safe/ProfileCard/Pad/Col/Status
@onready var _profile_title: Label = $Safe/ProfileCard/Pad/Col/Title
@onready var _profile_copy: Label = $Safe/ProfileCard/Pad/Col/Copy
@onready var _profile_delete: Button = $Safe/ProfileCard/Pad/Col/DeleteAccount
@onready var _account_card: PanelContainer = $Safe/AccountCard
@onready var _account_title: Label = $Safe/AccountCard/Pad/Col/Title
@onready var _account_copy: Label = $Safe/AccountCard/Pad/Col/Copy
@onready var _account_who: Label = $Safe/AccountCard/Pad/Col/Who
@onready var _account_delete: Button = $Safe/AccountCard/Pad/Col/DeleteAccount
@onready var _account_confirm: VBoxContainer = $Safe/AccountCard/Pad/Col/Confirm
@onready var _account_confirm_copy: Label = $Safe/AccountCard/Pad/Col/Confirm/ConfirmCopy
@onready var _account_confirm_delete: Button = $Safe/AccountCard/Pad/Col/Confirm/ConfirmDelete
@onready var _account_cancel: Button = $Safe/AccountCard/Pad/Col/Confirm/Cancel
@onready var _account_back: Button = $Safe/AccountCard/Pad/Col/Back
@onready var _account_status: Label = $Safe/AccountCard/Pad/Col/Status


func _ready() -> void:
	BakeryTheme.apply(self)
	_style()
	_continue.pressed.connect(_on_continue)
	_skip.pressed.connect(_on_skip)
	_phone.text_submitted.connect(func(_t: String): _on_continue())
	_save.pressed.connect(_on_save_profile)
	_email.text_submitted.connect(func(_t: String): _on_save_profile())
	if _profile_delete:
		_profile_delete.pressed.connect(_on_profile_delete)
	if _account_delete:
		_account_delete.pressed.connect(_on_delete_pressed)
	if _account_confirm_delete:
		_account_confirm_delete.pressed.connect(_on_delete_confirmed)
	if _account_cancel:
		_account_cancel.pressed.connect(_hide_delete_confirm)
	if _account_back:
		_account_back.pressed.connect(_on_account_back)
	if GameSave.square_phone != "":
		_phone.text = AccountClient.format_phone(GameSave.square_phone)
	if GameSave.square_email != "":
		_email.text = GameSave.square_email
	var manage := AccountClient.open_account_settings
	AccountClient.open_account_settings = false
	if manage and AccountClient.is_logged_in() and get_tree().current_scene == self:
		show_account_settings()
		return
	if AccountClient.should_skip_login() and get_tree().current_scene == self:
		if AccountClient.needs_profile():
			show_profile_form()
			return
		_go_home()
		return
	OrderClient.preload_menu()
	AppConfig.warmup_ui_scenes()
	_show_phone()


func _style() -> void:
	StorefrontPhoto.apply(get_node_or_null("Storefront") as TextureRect)
	for card in [_card, _profile, _account_card]:
		if card:
			card.add_theme_stylebox_override("panel", BakeryTheme.card_style())
	_title.add_theme_color_override("font_color", BakeryTheme.WINE)
	_title.add_theme_font_size_override("font_size", BakeryTheme.SIZE_TITLE)
	_copy.add_theme_color_override("font_color", BakeryTheme.MUTED)
	_copy.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BODY)
	_status.add_theme_color_override("font_color", BakeryTheme.WINE)
	_status.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BODY)
	_continue.custom_minimum_size = Vector2(0, 72)
	_continue.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BUTTON)
	_skip.theme_type_variation = "SecondaryButton"
	_skip.custom_minimum_size = Vector2(0, 64)
	_skip.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BUTTON)
	_loyalty.add_theme_color_override("font_color", BakeryTheme.INK)
	_loyalty.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BODY)
	_phone.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PHONE
	_phone.secret = false
	_phone.custom_minimum_size = Vector2(0, 64)
	_profile_title.add_theme_color_override("font_color", BakeryTheme.WINE)
	_profile_title.add_theme_font_size_override("font_size", BakeryTheme.SIZE_TITLE)
	_profile_copy.add_theme_color_override("font_color", BakeryTheme.MUTED)
	_profile_copy.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BODY)
	_profile_status.add_theme_color_override("font_color", BakeryTheme.WINE)
	_profile_status.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BODY)
	_save.custom_minimum_size = Vector2(0, 72)
	_save.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BUTTON)
	_email.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	if _profile_delete:
		_profile_delete.theme_type_variation = "SecondaryButton"
		_profile_delete.custom_minimum_size = Vector2(0, 64)
		_profile_delete.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BUTTON)
	if _account_title:
		_account_title.add_theme_color_override("font_color", BakeryTheme.WINE)
		_account_title.add_theme_font_size_override("font_size", BakeryTheme.SIZE_TITLE)
	if _account_copy:
		_account_copy.add_theme_color_override("font_color", BakeryTheme.MUTED)
		_account_copy.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BODY)
	if _account_who:
		_account_who.add_theme_color_override("font_color", BakeryTheme.INK)
		_account_who.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BODY)
	if _account_confirm_copy:
		_account_confirm_copy.add_theme_color_override("font_color", BakeryTheme.INK)
		_account_confirm_copy.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BODY)
	if _account_status:
		_account_status.add_theme_color_override("font_color", BakeryTheme.WINE)
		_account_status.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BODY)
	for btn in [_account_delete, _account_confirm_delete, _account_cancel, _account_back]:
		if btn == null:
			continue
		btn.custom_minimum_size = Vector2(0, 64)
		btn.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BUTTON)
	if _account_delete:
		_account_delete.theme_type_variation = "SecondaryButton"
	if _account_cancel:
		_account_cancel.theme_type_variation = "SecondaryButton"
	if _account_back:
		_account_back.theme_type_variation = "SecondaryButton"
	if _account_confirm_delete:
		_account_confirm_delete.custom_minimum_size = Vector2(0, 72)


func _show_phone() -> void:
	_card.visible = true
	_profile.visible = false
	if _account_card:
		_account_card.visible = false


func show_profile_form() -> void:
	_card.visible = false
	_profile.visible = true
	if _account_card:
		_account_card.visible = false
	_profile_status.text = ""
	if _first.text.strip_edges() == "":
		_first.grab_focus()


func show_account_settings() -> void:
	_card.visible = false
	_profile.visible = false
	if _account_card:
		_account_card.visible = true
	_hide_delete_confirm()
	var who := AccountClient.display_name()
	var phone := AccountClient.format_phone(GameSave.square_phone)
	if who != "" and phone != "":
		_account_who.text = "%s\n%s" % [who, phone]
	elif phone != "":
		_account_who.text = phone
	elif who != "":
		_account_who.text = who
	else:
		_account_who.text = "Signed in"
	if _account_status:
		_account_status.text = ""


func _on_profile_delete() -> void:
	show_account_settings()
	_on_delete_pressed()


func _on_delete_pressed() -> void:
	if _account_delete:
		_account_delete.visible = false
	if _account_confirm:
		_account_confirm.visible = true
	if _account_status:
		_account_status.text = ""


func _hide_delete_confirm() -> void:
	if _account_confirm:
		_account_confirm.visible = false
	if _account_delete:
		_account_delete.visible = true
		_account_delete.disabled = false
	if _account_confirm_delete:
		_account_confirm_delete.disabled = false
	if _account_cancel:
		_account_cancel.disabled = false
	if _account_back:
		_account_back.disabled = false


func _on_delete_confirmed() -> void:
	if _account_confirm_delete:
		_account_confirm_delete.disabled = true
	if _account_cancel:
		_account_cancel.disabled = true
	if _account_back:
		_account_back.disabled = true
	if _account_status:
		_account_status.text = "Deleting account…"
	var result: Dictionary = await AccountClient.delete_account()
	if not is_inside_tree():
		return
	if not result.get("ok", false):
		_hide_delete_confirm()
		_on_delete_pressed()
		if _account_status:
			_account_status.text = str(result.get("error", "Could not delete the account."))
		return
	NoticeService.info("Account deleted.")
	_show_phone()
	_status.text = "Account deleted. You are signed out."


func _on_account_back() -> void:
	if not AccountClient.is_logged_in():
		_show_phone()
		return
	if AccountClient.needs_profile():
		show_profile_form()
		return
	AppConfig.go("res://scenes/main_menu.tscn")


func _on_continue() -> void:
	var e164 := AccountClient.normalize_phone(_phone.text)
	if e164 == "":
		_status.text = "Enter a US phone number (10 digits)."
		return
	_busy(true, "Looking up Square customer…")
	var result: Dictionary = await AccountClient.login_or_signup(e164, _loyalty.button_pressed)
	if not result.get("ok", false):
		_busy(false, str(result.get("error", "Square login failed.")))
		return
	var created := bool(result.get("created", false))
	if AccountClient.needs_profile():
		NoticeService.info("Account created on Square." if created else "Add your name for Square.")
		_busy(false, "")
		show_profile_form()
		return
	NoticeService.info("Account created on Square." if created else "Signed in.")
	_go_home()


func _on_save_profile() -> void:
	var invalid := AccountClient.profile_error(_first.text, _last.text, _email.text)
	if invalid != "":
		_profile_status.text = invalid
		return
	_save.disabled = true
	_first.editable = false
	_last.editable = false
	_email.editable = false
	_profile_status.text = "Updating Square customer…"
	var result: Dictionary = await AccountClient.update_profile(_first.text, _last.text, _email.text)
	if not result.get("ok", false):
		_save.disabled = false
		_first.editable = true
		_last.editable = true
		_email.editable = true
		_profile_status.text = str(result.get("error", "Square profile update failed."))
		return
	NoticeService.info("Hi, %s" % AccountClient.first_name())
	_go_home()


func _on_skip() -> void:
	AccountClient.skip_as_guest()
	_go_home()


func _busy(on: bool, message: String) -> void:
	_continue.disabled = on
	_skip.disabled = on
	_phone.editable = not on
	_status.text = message


func _go_home() -> void:
	if AccountClient.is_logged_in():
		await ProfileStore.refresh_from_server()
		if ProfileStore.needs_customize():
			AppConfig.go("res://scenes/explore/customize.tscn")
			return
	AppConfig.go("res://scenes/main_menu.tscn")
