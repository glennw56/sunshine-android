# MIT License

# Copyright (c) 2025-present Poing Studios

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

const Library := preload("res://addons/admob/internal/exporters/android/library.gd")

## Manifest App ID. Prefer project.godot [sunshine] admob_app_id (or SUNSHINE_ADMOB_APP_ID at runtime).
## Google sample id is safe for debug. Paste production ca-app-pub-XXXX~YYYY from AdMob console into
## sunshine/admob_app_id and re-export — do not leave a second copy of the live id only here.
var APPLICATION_ID: String = str(ProjectSettings.get_setting(
	"sunshine/admob_app_id",
	"ca-app-pub-3940256099942544~3347511713"
))

var libraries: Array[Library] = [
	# Main Plugin
	Library.new("ads", true), # Disable if you don't want to use AdMob.
	
	# Supported Mediations
	Library.new("adcolony", false),
	Library.new("meta", false),
	Library.new("vungle", false)
]
