extends CharacterBody3D

signal stats_changed(health: float, hunger: float, thirst: float, ammo: int)

const SPEED := 5.0
const SPRINT_SPEED := 8.0
const JUMP_VELOCITY := 4.5
const GRAVITY := 18.0
var health := 100.0
var hunger := 100.0
var thirst := 100.0
var ammo := 24
var medkits := 2
var mouse_sensitivity := 0.002
var pitch := 0.0
var fire_cooldown := 0.0
var interact_message := ""

@onready var camera: Camera3D = $Head/Camera3D
@onready var ray: RayCast3D = $Head/Camera3D/RayCast3D

func _ready() -> void:
    add_to_group("player")
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    ray.target_position = Vector3(0, 0, -60)
    ray.enabled = true

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        rotate_y(-event.relative.x * mouse_sensitivity)
        pitch = clampf(pitch - event.relative.y * mouse_sensitivity, -1.45, 1.45)
        camera.rotation.x = pitch
    if event.is_action_pressed("ui_cancel"):
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    if event.is_action_pressed("fire"):
        shoot()
    if event.is_action_pressed("heal"):
        use_medkit()
    if event.is_action_pressed("interact"):
        interact()

func _physics_process(delta: float) -> void:
    fire_cooldown = maxf(0.0, fire_cooldown - delta)
    hunger = maxf(0.0, hunger - delta * 0.035)
    thirst = maxf(0.0, thirst - delta * 0.055)
    if hunger <= 0.0 or thirst <= 0.0:
        health = maxf(0.0, health - delta * 1.5)
    if not is_on_floor():
        velocity.y -= GRAVITY * delta
    elif Input.is_action_just_pressed("jump"):
        velocity.y = JUMP_VELOCITY
    var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
    var speed := SPRINT_SPEED if Input.is_action_pressed("sprint") else SPEED
    if direction:
        velocity.x = direction.x * speed
        velocity.z = direction.z * speed
    else:
        velocity.x = move_toward(velocity.x, 0, SPEED)
        velocity.z = move_toward(velocity.z, 0, SPEED)
    move_and_slide()
    stats_changed.emit(health, hunger, thirst, ammo)

func shoot() -> void:
    if fire_cooldown > 0.0 or ammo <= 0:
        return
    fire_cooldown = 0.22
    ammo -= 1
    if ray.is_colliding():
        var target = ray.get_collider()
        if target and target.is_in_group("zombies"):
            target.take_damage(34.0)
    stats_changed.emit(health, hunger, thirst, ammo)

func use_medkit() -> void:
    if medkits > 0 and health < 100.0:
        medkits -= 1
        health = minf(100.0, health + 45.0)
        stats_changed.emit(health, hunger, thirst, ammo)

func interact() -> void:
    if ray.is_colliding():
        var target = ray.get_collider()
        if target and target.is_in_group("loot"):
            if target.has_method("collect"):
                target.collect(self)
    stats_changed.emit(health, hunger, thirst, ammo)

func take_damage(amount: float) -> void:
    health = maxf(0.0, health - amount)
    stats_changed.emit(health, hunger, thirst, ammo)
    if health <= 0.0:
        get_tree().call_deferred("reload_current_scene")
