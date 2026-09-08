## Turns a FormData into a visual model. Loads the .glb if it exists,
## otherwise builds a colored primitive body so the game always runs.
class_name ModelFactory

static func build(form: FormData) -> Node3D:
	var root := Node3D.new()
	root.name = "Model"
	var loaded := false
	if form.model_path != "" and ResourceLoader.exists(form.model_path):
		var scene = load(form.model_path)
		if scene is PackedScene:
			root.add_child((scene as PackedScene).instantiate())
			loaded = true
	if not loaded:
		root.add_child(_primitive(form))
	Cel.apply(root, form.color)
	root.scale = Vector3.ONE * form.size
	return root

## Simple capsule person with a head and a visor so you can tell which way it faces.
static func _primitive(form: FormData) -> Node3D:
	var n := Node3D.new()
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.35
	cap.height = 1.3
	body.mesh = cap
	body.position = Vector3(0, 0.85, 0)
	n.add_child(body)

	var head := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.26
	sph.height = 0.52
	head.mesh = sph
	head.position = Vector3(0, 1.75, 0)
	n.add_child(head)

	var visor := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.3, 0.1, 0.12)
	visor.mesh = box
	visor.position = Vector3(0, 1.78, -0.22)
	var vm := StandardMaterial3D.new()
	vm.albedo_color = Color(0.1, 0.1, 0.12)
	visor.material_override = null
	visor.set_surface_override_material(0, vm)
	n.add_child(visor)

	# Mutrix on the left wrist
	var watch := MeshInstance3D.new()
	var wb := BoxMesh.new()
	wb.size = Vector3(0.14, 0.08, 0.14)
	watch.mesh = wb
	watch.position = Vector3(-0.42, 0.85, 0)
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.24, 0.95, 0.54)
	watch.set_surface_override_material(0, wm)
	n.add_child(watch)
	return n
