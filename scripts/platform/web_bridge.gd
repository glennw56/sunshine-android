extends Node
class_name WebBridge
## Opens the live bakery-drinks order/board URLs.
## Godot has no built-in WebView; Android uses the system browser / Custom Tabs.
## Native HTTP catalog (OrderClient) is the in-app menu so checkout still works
## without embedding a WebView widget.


static func open(url: String) -> void:
	if url.strip_edges() == "":
		NoticeService.info("No URL to open.")
		return
	var err := OS.shell_open(url)
	if err != OK:
		NoticeService.info("Could not open %s (%s)" % [url, err])


static func open_order() -> void:
	open(AppConfig.order_url())


static func open_board() -> void:
	open(AppConfig.board_url())


static func open_checkout_if_any() -> void:
	if OrderClient.last_checkout_url != "":
		open(OrderClient.last_checkout_url)
	else:
		open_order()
