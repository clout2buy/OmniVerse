## Headless sanity tests. Run:  godot --headless --path . -s tests/run_tests.gd
## Exit code 0 on success, 1 on any failure. Ares must keep this green.
extends SceneTree

var failures := 0

func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failures += 1
		printerr("  FAIL ", msg)

func _init() -> void:
	print("== OmniVerse tests ==")
	_test_forms()
	_test_join_code()
	_test_scripts_parse()
	if failures == 0:
		print("All tests passed.")
		quit(0)
	else:
		printerr("%d failure(s)." % failures)
		quit(1)

func _test_forms() -> void:
	print("forms:")
	var forms := FormLoader.load_all()
	check(forms.size() >= 4, "at least 4 forms loaded (got %d)" % forms.size())
	check(forms.has("human"), "human form exists")
	for id in forms:
		var f: FormData = forms[id]
		var errs := f.validate()
		check(errs.is_empty(), "%s validates %s" % [id, errs])
		check(f.abilities.size() == 4, "%s has 4 abilities" % id)
		for a in f.abilities:
			check(a.id != "" and a.display_name != "", "%s ability has id + name" % id)
			check(a.cooldown >= 0.0, "%s/%s cooldown >= 0" % [id, a.id])
	var order := FormLoader.ordered_ids(forms)
	check(order.size() == forms.size() and order[0] == "human", "human is first in order")
	var roles := {}
	for id in forms:
		roles[forms[id].role] = true
	for r in ["human", "assassin", "tank", "speedster"]:
		check(roles.has(r), "role %s present" % r)

func _test_join_code() -> void:
	print("join codes:")
	for ip in ["192.168.1.42", "8.8.8.8", "255.255.255.255", "0.0.0.0", "73.12.200.9"]:
		for port in [7777, 1, 65535]:
			var code := JoinCode.encode(ip, port)
			var back := JoinCode.decode(code)
			check(back.get("ip") == ip and back.get("port") == port, "roundtrip %s:%d -> %s" % [ip, port, code])
			check(code.length() == 11 and code[5] == "-", "code format %s" % code)
	check(JoinCode.decode("nope").is_empty(), "garbage rejected")
	check(JoinCode.decode("localhost").get("ip") == "127.0.0.1", "localhost shortcut")
	check(JoinCode.decode("10.0.0.5:8000").get("port") == 8000, "ip:port shortcut")
	var lower := JoinCode.encode("1.2.3.4", 7777).to_lower()
	check(JoinCode.decode(lower).get("ip") == "1.2.3.4", "case-insensitive")

func _test_scripts_parse() -> void:
	print("scripts:")
	# Scripts that reference the Game/Net autoloads cannot compile in -s mode;
	# those are covered by the headless smoke run in tools/check.ps1 (--solo).
	var paths := [
		"res://scripts/combat/ability_runner.gd", "res://scripts/combat/projectile.gd",
		"res://scripts/combat/fx.gd", "res://scripts/world/dummy.gd", "res://scripts/world/cel.gd",
		"res://scripts/world/model_factory.gd", "res://scripts/autoload/game.gd",
		"res://scripts/autoload/net.gd", "res://scripts/net/join_code.gd",
	]
	for p in paths:
		var s = load(p)
		check(s != null and s is GDScript and (s as GDScript).can_instantiate(), "compiles: " + p)
