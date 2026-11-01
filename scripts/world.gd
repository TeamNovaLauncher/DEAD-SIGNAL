extends Node3D

const PLAYER_SCRIPT = preload("res://scripts/player.gd")
const ZOMBIE_SCRIPT = preload("res://scripts/zombie.gd")
const LOOT_SCRIPT = preload("res://scripts/loot.gd")
var player: CharacterBody3D
var hud: CanvasLayer
var elapsed := 0.0
var wave := 1
var spawn_timer := 0.0
var day_clock := 0.22
var status_label: Label
var health_bar: ProgressBar
var hunger_bar: ProgressBar
var thirst_bar: ProgressBar
var ammo_label: Label

func _ready() -> void:
    randomize()
    _setup_input()
    _create_lighting()
    _create_city()
    _create_player()
    _create_hud()
    for i in range(9):
        _spawn_zombie(Vector3(randf_range(-28, 28), 0, randf_range(-28, 28)))
    for i in range(18):
        _spawn_loot(Vector3(randf_range(-32, 32), 0.4, randf_range(-32, 32)), i)

func _setup_input() -> void:
    var actions = {
        "move_forward":[KEY_W, KEY_UP], "move_back":[KEY_S, KEY_DOWN],
        "move_left":[KEY_A, KEY_LEFT], "move_right":[KEY_D, KEY_RIGHT],
        "sprint":[KEY_SHIFT], "jump":[KEY_SPACE], "fire":[KEY_F],
        "heal":[KEY_H], "interact":[KEY_E]
    }
    for action in actions:
        if not InputMap.has_action(action):
            InputMap.add_action(action)
        for keycode in actions[action]:
            var event := InputEventKey.new()
            event.physical_keycode = keycode
            InputMap.action_add_event(action, event)

func _create_lighting() -> void:
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48, -32, 0)
    sun.light_energy = 0.45
    sun.shadow_enabled = true
    add_child(sun)
    var env := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_SKY
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.24, 0.29, 0.34)
    environment.ambient_light_energy = 0.45
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    environment.fog_enabled = true
    environment.fog_light_color = Color(0.12, 0.16, 0.18)
    environment.fog_density = 0.008
    env.environment = environment
    add_child(env)

func _create_city() -> void:
    _box(Vector3(0, -0.35, 0), Vector3(100, 0.6, 100), Color(0.12, 0.13, 0.13), true)
    for x in range(-4, 5):
        for z in range(-4, 5):
            if abs(x) < 2 and abs(z) < 2:
                continue
            var height := randf_range(5.0, 15.0)
            var width := randf_range(5.0, 8.0)
            var building := _box(Vector3(x * 12.0, height * 0.5, z * 12.0), Vector3(width, height, width), Color(randf_range(0.12,0.25), randf_range(0.14,0.23), randf_range(0.16,0.25)), true)
            building.name = "RuinedBuilding"
            for floor_i in range(1, int(height / 2.5)):
                for side in [-1, 1]:
                    _box(Vector3(x*12.0 + side*(width/2+0.015), floor_i*2.5, z*12.0), Vector3(0.04, 0.8, 1.1), Color(0.08,0.12,0.14), false)
    for i in range(22):
        var pos := Vector3(randf_range(-42,42), 0.18, randf_range(-42,42))
        var wreck := _box(pos, Vector3(randf_range(1.5,2.8), 0.35, randf_range(3.0,5.0)), Color(0.18,0.08,0.055), true)
        wreck.rotation.y = randf_range(0, TAU)
    for i in range(35):
        var pos := Vector3(randf_range(-45,45), 0.5, randf_range(-45,45))
        _box(pos, Vector3(0.5, randf_range(0.5,1.8), 0.5), Color(0.22,0.24,0.23), true)

func _create_player() -> void:
    player = CharacterBody3D.new()
    player.name = "Survivor"
    player.set_script(PLAYER_SCRIPT)
    player.position = Vector3(0, 1.2, 0)
    var collision := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.38
    capsule.height = 1.8
    collision.shape = capsule
    player.add_child(collision)
    var head := Node3D.new()
    head.name = "Head"
    head.position.y = 0.62
    player.add_child(head)
    var camera := Camera3D.new()
    camera.current = true
    camera.fov = 82
    head.add_child(camera)
    var ray := RayCast3D.new()
    ray.name = "RayCast3D"
    camera.add_child(ray)
    add_child(player)

func _create_hud() -> void:
    hud = CanvasLayer.new()
    add_child(hud)
    var panel := PanelContainer.new()
    panel.position = Vector2(18, 18)
    panel.custom_minimum_size = Vector2(245, 142)
    hud.add_child(panel)
    var column := VBoxContainer.new()
    panel.add_child(column)
    var title := Label.new()
    title.text = "DEAD SIGNAL  //  SURVIVOR"
    title.add_theme_color_override("font_color", Color(0.8,0.91,0.86))
    column.add_child(title)
    health_bar = _add_stat(column, "HEALTH", Color(0.75,0.12,0.1))
    hunger_bar = _add_stat(column, "HUNGER", Color(0.8,0.55,0.12))
    thirst_bar = _add_stat(column, "THIRST", Color(0.12,0.55,0.8))
    ammo_label = Label.new()
    ammo_label.text = "AMMO: 24  |  MEDKITS: 2"
    column.add_child(ammo_label)
    status_label = Label.new()
    status_label.position = Vector2(18, 172)
    status_label.text = "WASD move  |  SHIFT sprint  |  F fire  |  H medkit  |  E loot"
    hud.add_child(status_label)
    var cross := Label.new()
    cross.text = "+"
    cross.add_theme_font_size_override("font_size", 28)
    cross.position = Vector2(632, 342)
    hud.add_child(cross)
    player.stats_changed.connect(_update_hud)

func _add_stat(parent: VBoxContainer, label_text: String, color: Color) -> ProgressBar:
    var label := Label.new()
    label.text = label_text
    parent.add_child(label)
    var bar := ProgressBar.new()
    bar.max_value = 100
    bar.value = 100
    bar.show_percentage = false
    bar.custom_minimum_size = Vector2(210, 10)
    parent.add_child(bar)
    return bar

func _update_hud(h: float, food: float, water: float, bullets: int) -> void:
    health_bar.value = h
    hunger_bar.value = food
    thirst_bar.value = water
    ammo_label.text = "AMMO: %d  |  MEDKITS: %d" % [bullets, player.medkits]
    if h <= 25:
        status_label.text = "CRITICAL: FIND MEDICAL SUPPLIES!"

func _spawn_zombie(pos: Vector3) -> void:
    var zombie := CharacterBody3D.new()
    zombie.set_script(ZOMBIE_SCRIPT)
    zombie.position = pos
    var shape := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.38
    capsule.height = 1.8
    shape.shape = capsule
    zombie.add_child(shape)
    var body := MeshInstance3D.new()
    var mesh := CapsuleMesh.new()
    mesh.radius = 0.38
    mesh.height = 1.8
    body.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.22, 0.34, 0.19)
    mat.roughness = 0.95
    body.material_override = mat
    zombie.add_child(body)
    var eyes := MeshInstance3D.new()
    var eye_mesh := SphereMesh.new()
    eye_mesh.radius = 0.07
    eye_mesh.height = 0.14
    eyes.mesh = eye_mesh
    eyes.position = Vector3(0.15, 0.55, -0.3)
    var eye_mat := StandardMaterial3D.new()
    eye_mat.albedo_color = Color(0.8, 0.04, 0.02)
    eye_mat.emission_enabled = true
    eye_mat.emission = Color(0.5,0.01,0.0)
    eyes.material_override = eye_mat
    zombie.add_child(eyes)
    add_child(zombie)

func _spawn_loot(pos: Vector3, index: int) -> void:
    var item := Area3D.new()
    item.add_to_group("loot")
    item.position = pos
    var collision := CollisionShape3D.new()
    var sphere := SphereShape3D.new()
    sphere.radius = 0.9
    collision.shape = sphere
    item.add_child(collision)
    var visual := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = Vector3(0.55,0.55,0.55)
    visual.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = [Color(0.8,0.12,0.1), Color(0.12,0.55,0.8), Color(0.75,0.65,0.2)][index % 3]
    mat.emission_enabled = true
    mat.emission = mat.albedo_color * 0.3
    visual.material_override = mat
    item.add_child(visual)
    item.set_script(LOOT_SCRIPT)
    item.set_meta("loot_type", index % 3)
    add_child(item)

func _box(pos: Vector3, size: Vector3, color: Color, solid: bool) -> StaticBody3D:
    var body := StaticBody3D.new()
    body.position = pos
    var mesh_instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh_instance.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.92
    mesh_instance.material_override = mat
    body.add_child(mesh_instance)
    if solid:
        var collision := CollisionShape3D.new()
        var box_shape := BoxShape3D.new()
        box_shape.size = size
        collision.shape = box_shape
        body.add_child(collision)
    add_child(body)
    return body
