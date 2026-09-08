## Loads every FormData script in data/forms. Shared by the game and the tests.
class_name FormLoader

const FORMS_DIR := "res://data/forms"

static func load_all() -> Dictionary:
	var out := {}
	var dir := DirAccess.open(FORMS_DIR)
	if dir == null:
		push_error("FormLoader: cannot open %s" % FORMS_DIR)
		return out
	var files := dir.get_files()
	files.sort()
	for f in files:
		var fname: String = f.replace(".remap", "")
		if not (fname.ends_with(".gd") or fname.ends_with(".gdc")):
			continue
		var script = load(FORMS_DIR + "/" + fname)
		if script == null:
			push_error("FormLoader: failed to load %s" % fname)
			continue
		var form = script.new()
		if not (form is FormData):
			push_error("FormLoader: %s does not extend FormData" % fname)
			continue
		for e in form.validate():
			push_error("FormLoader: " + e)
		out[form.id] = form
	return out

## Human first, then the rest alphabetically by display name.
static func ordered_ids(forms: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for id in forms.keys():
		if id != "human":
			ids.append(id)
	ids.sort_custom(func(a, b): return forms[a].display_name < forms[b].display_name)
	if forms.has("human"):
		ids.push_front("human")
	return ids
