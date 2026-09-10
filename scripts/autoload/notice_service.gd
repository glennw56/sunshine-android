extends CanvasLayer
## In-app customer + staff notices (toasts). Works in the editor and on Android.

enum Kind { CUSTOMER, STAFF, INFO }

var _queue: Array[Dictionary] = []
var _busy := false
var _panel: PanelContainer
var _label: Label
var _kind_label: Label


func _ready() -> void:
	layer = 128
	_build()


func customer(message: String) -> void:
	_enqueue(Kind.CUSTOMER, "Order", message)


func staff(message: String) -> void:
	_enqueue(Kind.STAFF, "Shop", message)


func info(message: String) -> void:
	_enqueue(Kind.INFO, "Sunshine's", message)


func order_ready(order_label: String = "") -> void:
	var extra := " Order %s." % order_label if order_label != "" and order_label != "—" else ""
	customer("Your order is ready — head to the pickup counter.%s" % extra)


func order_making(order_label: String = "") -> void:
	customer("We're making it%s." % ((" · " + order_label) if order_label != "" else ""))


func staff_ready(summary: String) -> void:
	staff("Ready for pickup: %s" % summary)


func staff_complete(summary: String) -> void:
	staff("Complete: %s" % summary)


func _enqueue(kind: Kind, title: String, message: String) -> void:
	_queue.append({"kind": kind, "title": title, "message": message})
	if not _busy:
		_pump()


func _pump() -> void:
	if _queue.is_empty():
		_busy = false
		_panel.visible = false
		return
	_busy = true
	var item: Dictionary = _queue.pop_front()
	_kind_label.text = str(item["title"]).to_upper()
	_label.text = str(item["message"])
	var kind: Kind = item["kind"]
	var style := _panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	match kind:
		Kind.CUSTOMER:
			style.bg_color = Color("4a2c2a")
		Kind.STAFF:
			style.bg_color = Color("3d5a45")
		_:
			style.bg_color = Color("7a4e2e")
	_panel.add_theme_stylebox_override("panel", style)
	_panel.visible = true
	_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 1.0, 0.18)
	tween.tween_interval(3.4)
	tween.tween_property(_panel, "modulate:a", 0.0, 0.25)
	await tween.finished
	_pump()


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("4a2c2a")
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	_panel.add_theme_stylebox_override("panel", style)
	_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_panel.offset_left = 24
	_panel.offset_right = -24
	_panel.offset_top = 28
	_panel.offset_bottom = 0
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_kind_label = Label.new()
	_kind_label.add_theme_font_size_override("font_size", 12)
	_kind_label.add_theme_color_override("font_color", Color("f4c430"))
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color("fff6ea"))
	vbox.add_child(_kind_label)
	vbox.add_child(_label)
	_panel.add_child(vbox)
	add_child(_panel)
