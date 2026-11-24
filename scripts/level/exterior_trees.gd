extends Node3D
# =============================================================================
# Árboles del exterior, generados por código al iniciar el nivel.
#
# Por qué por código: así no necesitamos modelos pesados. Se arma UNA malla de
# pino (tronco + varias "faldas" de ramas en forma de cono irregular) y se
# repite muchas veces con un MultiMeshInstance3D, que dibuja cientos de copias
# en una sola llamada a la GPU (muy barato).
#
# Se colocan en un anillo alrededor del edificio, sin tapar la salida.
# Cambia "seed_value" para obtener otro acomodo de árboles.
# =============================================================================

@export var tree_count: int = 140
@export var seed_value: int = 2026
# Rectángulo que ocupa el edificio (x mín, z mín, x máx, z máx) + margen libre
@export var building_rect: Rect2 = Rect2(-0.5, -0.5, 34.0, 28.5)
@export var clear_margin: float = 7.0 # distancia mínima entre edificio y árboles
@export var max_distance: float = 45.0 # qué tan lejos llega el bosque

var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.seed = seed_value
	var bark := StandardMaterial3D.new()
	bark.albedo_texture = load("res://assets/textures/pbr/corteza/color.jpg")
	bark.normal_enabled = true
	bark.normal_texture = load("res://assets/textures/pbr/corteza/normalgl.jpg")
	bark.albedo_color = Color(0.45, 0.42, 0.4)
	bark.roughness = 1.0
	bark.uv1_scale = Vector3(2, 3, 1)
	var leaves := ShaderMaterial.new()
	leaves.shader = load("res://assets/shaders/follaje.gdshader")

	var transforms := _pick_spots()
	_add_multimesh(_build_trunk(), bark, transforms)
	_add_multimesh(_build_pine(), leaves, transforms)


# Elige posiciones al azar fuera del edificio
func _pick_spots() -> Array[Transform3D]:
	var list: Array[Transform3D] = []
	var center := building_rect.get_center()
	var tries := 0
	while list.size() < tree_count and tries < tree_count * 20:
		tries += 1
		var p := Vector2(rng.randf_range(center.x - max_distance, center.x + max_distance),
			rng.randf_range(center.y - max_distance, center.y + max_distance))
		# Fuera del rectángulo del edificio + margen
		if building_rect.grow(clear_margin).has_point(p):
			continue
		# Deja libre la explanada frente a la salida (lado oeste, z ~ 13)
		if p.x < 0.0 and p.x > -14.0 and absf(p.y - 13.3) < 6.0:
			continue
		var s := rng.randf_range(0.8, 1.5) # tamaño
		var basis := Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3(s, s * rng.randf_range(0.9, 1.25), s))
		list.append(Transform3D(basis, Vector3(p.x, 0.0, p.y)))
	return list


func _add_multimesh(mesh: Mesh, material: Material, transforms: Array[Transform3D]) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = material
	add_child(mmi)


# Tronco: cilindro sencillo (casi no se ve, lo tapan las ramas)
func _build_trunk() -> Mesh:
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.08
	cyl.bottom_radius = 0.2
	cyl.height = 3.0
	cyl.radial_segments = 7
	# El cilindro está centrado: lo subimos para que empiece en el piso
	var st := SurfaceTool.new()
	st.create_from(cyl, 0)
	var arrays := st.commit_to_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in verts.size():
		verts[i].y += 1.5
	arrays[Mesh.ARRAY_VERTEX] = verts
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out


# Pino: 6 faldas cónicas irregulares, cada una más chica que la anterior
func _build_pine() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var layers := 6
	var sides := 11
	for layer in layers:
		var k := float(layer) / layers
		var y_base := 1.1 + layer * 0.85
		var radius := lerpf(2.0, 0.45, k)
		var height := lerpf(1.7, 1.2, k)
		var apex := Vector3(rng.randf_range(-0.05, 0.05), y_base + height, rng.randf_range(-0.05, 0.05))
		var ring: Array[Vector3] = []
		for i in sides:
			var a := TAU * i / sides + rng.randf_range(-0.1, 0.1)
			var r := radius * rng.randf_range(0.75, 1.15)
			# Las puntas de las ramas cuelgan un poco
			ring.append(Vector3(cos(a) * r, y_base - rng.randf_range(0.0, 0.35), sin(a) * r))
		for i in sides:
			var a := ring[i]
			var b := ring[(i + 1) % sides]
			# Lado del cono (UV.y = altura relativa, la usa el shader para el viento)
			st.set_uv(Vector2(0, 0)); st.add_vertex(a)
			st.set_uv(Vector2(1, 1)); st.add_vertex(apex)
			st.set_uv(Vector2(1, 0)); st.add_vertex(b)
			# Parte de abajo de la falda (para que no se vea hueco desde abajo)
			var under := Vector3(0, y_base + 0.25, 0)
			st.set_uv(Vector2(0, 0)); st.add_vertex(b)
			st.set_uv(Vector2(0, 0.2)); st.add_vertex(under)
			st.set_uv(Vector2(0, 0)); st.add_vertex(a)
	st.generate_normals()
	return st.commit()
