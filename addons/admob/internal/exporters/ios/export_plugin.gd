# MIT License

# Copyright (c) 2026-present Poing Studios

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

extends EditorExportPlugin

const ExportService := preload("res://addons/admob/internal/services/export_service.gd")
const PbxprojService := preload("res://addons/admob/internal/services/pbxproj_service.gd")
const AppConfig := preload("res://scripts/autoload/app_config.gd")
const PLUGIN_CONFIG_DIR := "res://ios/plugins/"

var _export_path: String = ""
var _spm_dependencies: Array[Dictionary] = []

func _get_name() -> String:
	return "PoingAdMobIOS"

func _supports_platform(platform: EditorExportPlatform) -> bool:
	return platform.get_os_name() == "iOS"

func _export_begin(features: PackedStringArray, is_debug: bool, path: String, flags: int) -> void:
	_export_path = path
	# Godot reads this while it writes Info.plist, which is before _export_end.
	add_ios_plist_content(_tracking_usage_plist())

func _export_end() -> void:
	if _export_path.is_empty():
		return
		
	var export_dir := _export_path.get_base_dir()
	_patch_gad_application_id(export_dir)

	var activated_plugins := ExportService.get_activated_plugins("iOS")
	if activated_plugins.is_empty():
		return

	_spm_dependencies = _collect_spm_dependencies(activated_plugins)
	if _spm_dependencies.is_empty():
		return

	_generate_package_swift(export_dir, _spm_dependencies)
	_generate_dummy_source(export_dir)

	# Godot 4.3 writes the .xcodeproj before _export_end. Headless export then
	# quits without running a deferred call, so the Swift package never lands
	# in project.pbxproj and Xcode cannot link GoogleMobileAds. Patch now.
	_patch_xcodeproj(export_dir)
	_defer_pbxproj_patch.call_deferred(export_dir)

func _defer_pbxproj_patch(export_dir: String) -> void:
	_patch_xcodeproj(export_dir)
	_spm_dependencies.clear()

func _patch_xcodeproj(export_dir: String) -> void:
	var project_name := _export_path.get_file().get_basename()
	var pbxproj_path := export_dir.path_join(project_name + ".xcodeproj/project.pbxproj")
	
	if FileAccess.file_exists(pbxproj_path):
		PbxprojService.patch(pbxproj_path)
		return
	
	var dir := DirAccess.open(export_dir)
	if not dir:
		push_warning("AdMob: Could not open export directory: %s" % export_dir)
		return
	
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".xcodeproj"):
			var found_path := export_dir.path_join(file_name).path_join("project.pbxproj")
			if FileAccess.file_exists(found_path):
				PbxprojService.patch(found_path)
			else:
				push_warning("AdMob: project.pbxproj not found at: %s" % found_path)
			break
		file_name = dir.get_next()

func _collect_spm_dependencies(activated_plugins: Array[String]) -> Array[Dictionary]:
	var deps: Array[Dictionary] = []
	var dir := DirAccess.open(PLUGIN_CONFIG_DIR)
	if not dir:
		return deps
		
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".gdip"):
			var config := ConfigFile.new()
			var err := config.load(PLUGIN_CONFIG_DIR.path_join(file_name))
			if err == OK:
				var plugin_name := config.get_value("config", "name", "")
				if activated_plugins.has(plugin_name):
					if config.has_section_key("dependencies", "admob_packages"):
						var packages: Array = config.get_value("dependencies", "admob_packages", [])
						for pkg_str: String in packages:
							# url@mode:version|product
							var main_parts := pkg_str.split("|")
							var product := main_parts[1] if main_parts.size() > 1 else ""
							
							var url_and_rules := main_parts[0].split("@")
							var url := url_and_rules[0]
							
							if url_and_rules.size() > 1:
								var rules := url_and_rules[1].split(":")
								if rules.size() > 1:
									var dep := {
										"url": url,
										"version": rules[1],
										"kind": rules[0],
										"product": product
									}
									deps.append(dep)
		file_name = dir.get_next()
	return deps

func _generate_package_swift(export_dir: String, dependencies: Array[Dictionary]) -> void:
	var package_deps_str := ""
	var target_deps_str := ""
	var processed_urls := []
	var processed_products := []
	
	for dep in dependencies:
		var url: String = dep.url
		var product: String = dep.product
		var package_name: String = url.get_file().trim_suffix(".git")

		if not processed_urls.has(url):
			processed_urls.append(url)
			var version_rule := 'exact: "%s"' % dep.version if dep.kind == "exact" else 'from: "%s"' % dep.version
			package_deps_str += '        .package(url: "%s", %s),\n' % [url, version_rule]
			
		if not processed_products.has(product):
			processed_products.append(product)
			target_deps_str += '                .product(name: "%s", package: "%s"),\n' % [product, package_name]

	var content := "// swift-tools-version:5.9\nimport PackageDescription\n\nlet package = Package(\n    name: \"PoingGodotAdMobDeps\",\n    platforms: [.iOS(.v13)],\n    products: [\n        .library(\n            name: \"PoingGodotAdMobDeps\",\n            targets: [\"PoingGodotAdMobDeps\"]),\n    ],\n    dependencies: [\n" + package_deps_str + "    ],\n    targets: [\n        .target(\n            name: \"PoingGodotAdMobDeps\",\n            dependencies: [\n" + target_deps_str + "            ],\n            path: \"PoingGodotAdMobDeps\"\n        )\n    ]\n)\n"

	var file := FileAccess.open(export_dir.path_join("Package.swift"), FileAccess.WRITE)
	if file:
		file.store_string(content)
		file.close()
		print("AdMob: Generated Package.swift at %s" % export_dir)

func _generate_dummy_source(export_dir: String) -> void:
	var source_dir := export_dir.path_join("PoingGodotAdMobDeps")
	if not DirAccess.dir_exists_absolute(source_dir):
		DirAccess.make_dir_recursive_absolute(source_dir)
			
	var content := "// Dummy\nimport Foundation\n\npublic struct PoingGodotAdMobDeps {\n    public init() {}\n}\n"
	var file := FileAccess.open(source_dir.path_join("Dummy.swift"), FileAccess.WRITE)
	if file:
		file.store_string(content)
		file.close()

func _tracking_usage_plist() -> String:
	# Present so an ATT request cannot crash. This build does not call
	# ATTrackingManager; rewarded ads still load without the IDFA.
	return (
		"<key>NSUserTrackingUsageDescription</key><string>"
		+ "Sunshine's Bakery uses this to show ads that support the staff. "
		+ "You can still send a tip if you choose not to allow tracking."
		+ "</string>"
	)

func _resolved_ios_app_id() -> String:
	var env_id := OS.get_environment("SUNSHINE_ADMOB_IOS_APP_ID").strip_edges()
	if env_id != "":
		return AppConfig.ios_app_id_for_plist(env_id)
	var configured := str(ProjectSettings.get_setting("sunshine/admob_ios_app_id", "")).strip_edges()
	return AppConfig.ios_app_id_for_plist(configured)

func _info_plist_path(export_dir: String) -> String:
	var project_name := _export_path.get_file().get_basename()
	var direct := export_dir.path_join(project_name).path_join(project_name + "-Info.plist")
	if FileAccess.file_exists(direct):
		return direct
	return ""

func _patch_gad_application_id(export_dir: String) -> void:
	var plist_path := _info_plist_path(export_dir)
	if plist_path == "":
		push_warning("AdMob: Info.plist not found; GADApplicationIdentifier left as exported.")
		return
	var app_id := _resolved_ios_app_id()
	var text := FileAccess.get_file_as_string(plist_path)
	var key := "<key>GADApplicationIdentifier</key>"
	var key_at := text.find(key)
	if key_at < 0:
		push_warning("AdMob: GADApplicationIdentifier missing from Info.plist.")
		return
	var open_at := text.find("<string>", key_at)
	var close_at := text.find("</string>", open_at)
	if open_at < 0 or close_at < 0:
		push_warning("AdMob: GADApplicationIdentifier string missing from Info.plist.")
		return
	var updated := text.substr(0, open_at + 8) + app_id + text.substr(close_at)
	var file := FileAccess.open(plist_path, FileAccess.WRITE)
	if file == null:
		push_warning("AdMob: could not write " + plist_path)
		return
	file.store_string(updated)
	file.close()
	print("AdMob: GADApplicationIdentifier %s" % app_id)
