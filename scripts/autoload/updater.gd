## In-game auto-update via GitHub Releases. Autoload as "Updater".
##
## Flow: on launch, fetch the latest release -> compare with the built-in version ->
## lobby shows "Update to vX.Y.Z" -> download the windows zip to user:// -> extract ->
## write a small .bat that waits for us to exit, copies the new files over, relaunches.
## Disabled when running from the editor.
extends Node

signal state_changed()

const REPO := "clout2buy/OmniVerse"
const API := "https://api.github.com/repos/%s/releases/latest"

## Release asset name suffix per platform (see .github/workflows/release.yml).
static func asset_suffix() -> String:
	return "-linux.zip" if OS.get_name() == "Linux" else "-windows.zip"

enum State { IDLE, CHECKING, UP_TO_DATE, AVAILABLE, DOWNLOADING, EXTRACTING, READY, FAILED, DISABLED }

var state: State = State.IDLE
var current_version := "0.0.0"
var latest_version := ""
var download_url := ""
var release_url := ""
var notes := ""
var progress := 0.0
var error := ""

func _ready() -> void:
	current_version = str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	if OS.has_feature("editor") or OS.get_name() not in ["Windows", "Linux"]:
		_set_state(State.DISABLED)
		return
	check()

func _set_state(s: State) -> void:
	state = s
	state_changed.emit()

func status_text() -> String:
	match state:
		State.CHECKING: return "Checking for updates..."
		State.UP_TO_DATE: return "Up to date (v%s)" % current_version
		State.AVAILABLE: return "Update available: v%s (you have v%s)" % [latest_version, current_version]
		State.DOWNLOADING: return "Downloading v%s... %d%%" % [latest_version, int(progress * 100)]
		State.EXTRACTING: return "Installing..."
		State.READY: return "Restarting to finish the update..."
		State.FAILED: return "Update failed: %s" % error
		State.DISABLED: return "v%s (dev build)" % current_version
	return "v%s" % current_version

# ---------------------------------------------------------------- check

func check() -> void:
	_set_state(State.CHECKING)
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_check_done.bind(http))
	var err := http.request(API % REPO, ["User-Agent: OmniVerse", "Accept: application/vnd.github+json"])
	if err != OK:
		_fail("could not start request (%d)" % err)

func _on_check_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_fail("GitHub returned %d" % code)
		return
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json == null or not (json is Dictionary):
		_fail("bad response")
		return
	latest_version = str(json.get("tag_name", "")).trim_prefix("v")
	release_url = str(json.get("html_url", ""))
	notes = str(json.get("body", ""))
	for a in json.get("assets", []):
		if str(a.get("name", "")).ends_with(asset_suffix()):
			download_url = str(a.get("browser_download_url", ""))
	if latest_version == "" or download_url == "":
		_fail("no %s build in the latest release" % OS.get_name())
		return
	if compare_versions(latest_version, current_version) > 0:
		_set_state(State.AVAILABLE)
	else:
		_set_state(State.UP_TO_DATE)

## Returns >0 if a is newer than b, 0 if equal, <0 if older. "1.2.3" style.
static func compare_versions(a: String, b: String) -> int:
	var pa := a.split(".")
	var pb := b.split(".")
	for i in max(pa.size(), pb.size()):
		var x := int(pa[i]) if i < pa.size() else 0
		var y := int(pb[i]) if i < pb.size() else 0
		if x != y:
			return x - y
	return 0

# ---------------------------------------------------------------- download + apply

func apply() -> void:
	if state != State.AVAILABLE:
		return
	_set_state(State.DOWNLOADING)
	var http := HTTPRequest.new()
	add_child(http)
	http.download_file = ProjectSettings.globalize_path("user://update.zip")
	http.request_completed.connect(_on_download_done.bind(http))
	var err := http.request(download_url, ["User-Agent: OmniVerse"])
	if err != OK:
		_fail("could not start download (%d)" % err)

func _process(_delta: float) -> void:
	if state != State.DOWNLOADING:
		return
	for c in get_children():
		if c is HTTPRequest and c.download_file != "":
			var total: int = c.get_body_size()
			if total > 0:
				progress = float(c.get_downloaded_bytes()) / float(total)
				state_changed.emit()

func _on_download_done(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_fail("download failed (%d / %d)" % [result, code])
		return
	_set_state(State.EXTRACTING)
	await get_tree().process_frame
	var out_dir := ProjectSettings.globalize_path("user://update_new")
	if not _extract(ProjectSettings.globalize_path("user://update.zip"), out_dir):
		return
	_launch_swapper(out_dir)

func _extract(zip_path: String, out_dir: String) -> bool:
	var zr := ZIPReader.new()
	if zr.open(zip_path) != OK:
		_fail("bad zip")
		return false
	# Wipe any previous attempt.
	if DirAccess.dir_exists_absolute(out_dir):
		OS.move_to_trash(out_dir)
	DirAccess.make_dir_recursive_absolute(out_dir)
	for f in zr.get_files():
		if f.ends_with("/"):
			DirAccess.make_dir_recursive_absolute(out_dir.path_join(f))
			continue
		var dest := out_dir.path_join(f)
		DirAccess.make_dir_recursive_absolute(dest.get_base_dir())
		var fa := FileAccess.open(dest, FileAccess.WRITE)
		if fa == null:
			_fail("cannot write " + f)
			return false
		fa.store_buffer(zr.read_file(f))
		fa.close()
	zr.close()
	return true

func _launch_swapper(src: String) -> void:
	var exe := OS.get_executable_path()
	var dst := exe.get_base_dir()
	var bat_path := ProjectSettings.globalize_path("user://apply_update.bat")
	var pid := OS.get_process_id()
	var bat := "\r\n".join([
		"@echo off",
		"title OmniVerse update",
		"echo Waiting for OmniVerse to close...",
		":wait",
		"tasklist /FI \"PID eq %d\" 2>NUL | find \"%d\" >NUL" % [pid, pid],
		"if not errorlevel 1 (timeout /t 1 /nobreak >NUL & goto wait)",
		"echo Installing update...",
		"xcopy /E /Y /I /Q \"%s\" \"%s\" >NUL" % [src.replace("/", "\\"), dst.replace("/", "\\")],
		"if errorlevel 1 (echo Update copy failed. & pause & exit /b 1)",
		"rmdir /S /Q \"%s\" >NUL 2>&1" % src.replace("/", "\\"),
		"start \"\" \"%s\"" % exe.replace("/", "\\"),
		"exit",
	])
	var fa := FileAccess.open(bat_path, FileAccess.WRITE)
	if fa == null:
		_fail("cannot write updater script")
		return
	fa.store_string(bat + "\r\n")
	fa.close()
	_set_state(State.READY)
	await get_tree().create_timer(0.8).timeout
	OS.create_process("cmd.exe", ["/c", ProjectSettings.globalize_path(bat_path).replace("/", "\\")])
	get_tree().quit()

func _launch_swapper_linux(src: String, dst: String, exe: String, pid: int) -> void:
	var sh_path := ProjectSettings.globalize_path("user://apply_update.sh")
	var sh := "\n".join([
		"#!/bin/sh",
		"while kill -0 %d 2>/dev/null; do sleep 1; done" % pid,
		"cp -r \"%s\"/. \"%s\"/ || { echo 'Update copy failed'; read x; exit 1; }" % [src, dst],
		"chmod +x \"%s\"" % exe,
		"rm -rf \"%s\"" % src,
		"\"%s\" &" % exe,
	])
	var fa := FileAccess.open(sh_path, FileAccess.WRITE)
	if fa == null:
		_fail("cannot write updater script")
		return
	fa.store_string(sh + "\n")
	fa.close()
	_set_state(State.READY)
	await get_tree().create_timer(0.8).timeout
	OS.create_process("/bin/sh", [sh_path])
	get_tree().quit()

func _fail(msg: String) -> void:
	error = msg
	push_warning("Updater: " + msg)
	_set_state(State.FAILED)
