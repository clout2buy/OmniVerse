## In-match HUD, drawn in code. Smite-style: health + ability bar bottom center,
## Mutrix status top left, kill feed top right, scoreboard on Tab.
class_name Hud
extends CanvasLayer

const KEYS := ["LMB", "Q", "E", "R"]
const GREEN := Color(0.24, 0.95, 0.54)
const RED := Color(0.95, 0.25, 0.3)
const PANEL := Color(0.04, 0.05, 0.08, 0.75)

var player: Player
var canvas: Control
var feed: Array = []
var font: Font

func _ready() -> void:
	font = ThemeDB.fallback_font
	canvas = Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	canvas.draw.connect(_draw_hud)
	Game.kill_feed.connect(_on_kill)

func _on_kill(text: String) -> void:
	feed.push_front([text, Time.get_ticks_msec() + 6000])
	if feed.size() > 5:
		feed.resize(5)

func _process(_delta: float) -> void:
	canvas.queue_redraw()

func _text(pos: Vector2, s: String, size: int, color: Color = Color.WHITE, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	canvas.draw_string(font, pos, s, align, width, size, color)

func _draw_hud() -> void:
	if player == null or player.form == null:
		return
	var sz := canvas.size
	var now := Time.get_ticks_msec()

	# Crosshair
	var c := sz * 0.5
	canvas.draw_arc(c, 6, 0, TAU, 24, Color(1, 1, 1, 0.9), 1.5)
	canvas.draw_circle(c, 1.5, Color(1, 1, 1, 0.9))

	# --- bottom center: health + abilities
	var bar_w := 420.0
	var bar_h := 22.0
	var bx := c.x - bar_w * 0.5
	var by := sz.y - 120.0
	canvas.draw_rect(Rect2(bx - 8, by - 34, bar_w + 16, 150), PANEL)
	_text(Vector2(bx, by - 12), "%s  [%s]" % [player.form.display_name, player.form.role.to_upper()], 16, player.form.color.lightened(0.5))
	canvas.draw_rect(Rect2(bx, by, bar_w, bar_h), Color(0.15, 0.05, 0.06))
	var frac: float = clamp(player.health / max(player.max_health, 1.0), 0.0, 1.0)
	canvas.draw_rect(Rect2(bx, by, bar_w * frac, bar_h), GREEN.lerp(RED, 1.0 - frac))
	_text(Vector2(bx, by + 16), "%d / %d" % [ceil(player.health), player.max_health], 13, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, bar_w)

	var box := 92.0
	var gap := 12.0
	var total := box * 4 + gap * 3
	var ax := c.x - total * 0.5
	var ay := by + 36
	for i in 4:
		var ab: AbilityData = player.form.abilities[i]
		var r := Rect2(ax + i * (box + gap), ay, box, 70)
		canvas.draw_rect(r, Color(0.1, 0.11, 0.16))
		var rem := player.cooldown_remaining(i)
		if rem > 0.0 and player.cd_total[i] > 0.0:
			var f: float = clamp(rem / player.cd_total[i], 0.0, 1.0)
			canvas.draw_rect(Rect2(r.position.x, r.position.y + r.size.y * (1.0 - f), r.size.x, r.size.y * f), Color(0, 0, 0, 0.6))
			_text(r.position + Vector2(0, 44), "%.1f" % rem, 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, box)
		canvas.draw_rect(r, ab.color, false, 2.0)
		_text(r.position + Vector2(6, 16), KEYS[i], 12, Color(0.8, 0.8, 0.8))
		_text(r.position + Vector2(0, 32), ab.display_name, 12, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, box)

	# --- top left: Mutrix
	var mx := 24.0
	var my := 24.0
	canvas.draw_rect(Rect2(mx - 8, my - 8, 260, 40 + 24 * Game.form_order.size()), PANEL)
	var lock := player.mutrix_lock_remaining()
	if player.dead:
		_text(Vector2(mx, my + 16), "MUTRIX  OFFLINE", 16, RED)
	elif lock <= 0.0:
		_text(Vector2(mx, my + 16), "MUTRIX  READY", 16, GREEN)
	else:
		_text(Vector2(mx, my + 16), "MUTRIX  LOCKED  %.1fs" % lock, 16, RED)
	if player.is_overcharged():
		_text(Vector2(mx + 150, my + 16), "OVERCHARGE", 12, GREEN)
	for i in Game.form_order.size():
		var fid: String = Game.form_order[i]
		var f: FormData = Game.get_form(fid)
		var col := Color(0.7, 0.7, 0.7)
		var prefix := "%d  " % (i + 1)
		if fid == player.form_id:
			col = f.color.lightened(0.6)
			prefix = "> "
		_text(Vector2(mx, my + 44 + i * 24), prefix + f.display_name, 14, col)

	# --- top right: kill feed
	var fx := sz.x - 24.0
	var fy := 36.0
	var alive: Array = []
	for item in feed:
		if item[1] > now:
			alive.append(item)
			_text(Vector2(fx - 400, fy), item[0], 14, Color(1, 1, 1, 0.9), HORIZONTAL_ALIGNMENT_RIGHT, 400)
			fy += 20
	feed = alive

	# --- status
	if player.dead:
		_text(Vector2(0, c.y - 40), "YOU WERE DESTROYED", 36, RED, HORIZONTAL_ALIGNMENT_CENTER, sz.x)
		_text(Vector2(0, c.y), "Respawning...", 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, sz.x)
	elif player.is_stunned():
		_text(Vector2(0, c.y - 60), "STUNNED", 24, Color(1, 1, 0.5), HORIZONTAL_ALIGNMENT_CENTER, sz.x)
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		_text(Vector2(0, c.y + 80), "Mouse released. Press Esc to return.", 16, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_CENTER, sz.x)

	_text(Vector2(24, sz.y - 20), "WASD move  Space jump  LMB/Q/E/R abilities  1-4 mutate  Tab scores  Esc mouse", 12, Color(1, 1, 1, 0.45))

	# --- scoreboard
	if Input.is_action_pressed("scoreboard"):
		var w := 380.0
		var rows: Array = Game.scores.values()
		rows.sort_custom(func(a, b): return a.kills > b.kills)
		var h := 50.0 + rows.size() * 24.0
		var r := Rect2(c.x - w * 0.5, c.y - h * 0.5 - 100, w, h)
		canvas.draw_rect(r, Color(0.04, 0.05, 0.08, 0.9))
		_text(r.position + Vector2(16, 26), "PLAYER", 14, Color(0.7, 0.7, 0.7))
		_text(r.position + Vector2(w - 140, 26), "K", 14, Color(0.7, 0.7, 0.7))
		_text(r.position + Vector2(w - 70, 26), "D", 14, Color(0.7, 0.7, 0.7))
		for i in rows.size():
			var y := r.position.y + 52 + i * 24
			_text(Vector2(r.position.x + 16, y), rows[i].name, 15)
			_text(Vector2(r.position.x + w - 140, y), str(rows[i].kills), 15)
			_text(Vector2(r.position.x + w - 70, y), str(rows[i].deaths), 15)
