extends CharacterBody3D

signal stats_changed(health: float, hunger: float, thirst: float, stamina: float, ammo: int)

const WALK_SPEED := 4.2
const RUN_SPEED := 7.2
const CROUCH_SPEED := 2.1
const JUMP_VELOCITY := 4.4
const GRAVITY := 18.0
const MAGAZINE_SIZE := 12
var health := 100.0
var hunger := 100.0
var thirst := 100.0
var stamina := 100.0
var ammo := 12
var reserve_ammo := 48
var medkits := 2
var food := 2
var water := 2
var bleeding := false
var is_reloading := false
var is_crouching := false
var mouse_sensitivity := 0.0018
var pitch := 0.0
var fire_cooldown := 0.0
var reload_timer := 0.0
var bob_time := 0.0
var base_camera_y := 0.62

@onready var camera: Camera3D = $Head/Camera3D
@onready var head: Node3D = $Head
@onready var ray: RayCast3D = $Head/Camera3D/RayCast3D

func _ready() -> void:
    add_to_group("player")
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    ray.target_position = Vector3(0, 0, -70)
    ray.enabled = true
    ray.collide_with_areas = true

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        rotate_y(-event.relative.x * mouse_sensitivity)
        pitch = clampf(pitch - event.relative.y * mouse_sensitivity, -1.42, 1.42)
        camera.rotation.x = pitch
    if event.is_action_pressed("ui_cancel"):
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_LEFT:
            Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
            shoot()
    if event.is_action_pressed("fire"):
        shoot()
    if event.is_action_pressed("reload"):
        begin_reload()
    if event.is_action_pressed("heal"):
        use_medkit()
    if event.is_action_pressed("eat"):
        consume_food()
    if event.is_action_pressed("drink"):
        consume_water()
    if event.is_action_pressed("interact"):
        interact()

func _physics_process(delta: float) -> void:
    fire_cooldown = maxf(0.0, fire_cooldown - delta)
    if is_reloading:
        reload_timer -= delta
        if reload_timer <= 0.0:
            var needed := MAGAZINE_SIZE - ammo
            var loaded: int = mini(needed, reserve_ammo)
            ammo += loaded
            reserve_ammo -= loaded
            is_reloading = false
    hunger = maxf(0.0, hunger - delta * 0.025)
    thirst = maxf(0.0, thirst - delta * 0.04)
    if hunger <= 0.0 or thirst <= 0.0:
        health = maxf(0.0, health - delta * 1.2)
    if bleeding:
        health = maxf(0.0, health - delta * 0.8)
    if not is_on_floor():
        velocity.y -= GRAVITY * delta
    elif Input.is_action_just_pressed("jump") and stamina >= 12.0 and not is_crouching:
        velocity.y = JUMP_VELOCITY
        stamina -= 12.0

    is_crouching = Input.is_action_pressed("crouch")
    var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
    var wants_run := Input.is_action_pressed("sprint") and not is_crouching and input_dir.length() > 0.1 and stamina > 1.0
    var speed := CROUCH_SPEED if is_crouching else (RUN_SPEED if wants_run else WALK_SPEED)
    if wants_run:
        stamina = maxf(0.0, stamina - delta * 19.0)
    else:
        stamina = minf(100.0, stamina + delta * 11.0)
    if direction:
        velocity.x = direction.x * speed
        velocity.z = direction.z * speed
    else:
        velocity.x = move_toward(velocity.x, 0.0, WALK_SPEED * 2.2)
        velocity.z = move_toward(velocity.z, 0.0, WALK_SPEED * 2.2)
    var target_head_y := 0.35 if is_crouching else base_camera_y
    head.position.y = lerpf(head.position.y, target_head_y, delta * 9.0)
    if is_on_floor() and input_dir.length() > 0.1:
        bob_time += delta * (12.0 if wants_run else 8.0)
        camera.position.y = sin(bob_time) * (0.045 if wants_run else 0.022)
    else:
        camera.position.y = lerpf(camera.position.y, 0.0, delta * 8.0)
    move_and_slide()
    stats_changed.emit(health, hunger, thirst, stamina, ammo)

func shoot() -> void:
    if fire_cooldown > 0.0 or ammo <= 0 or is_reloading:
        if ammo <= 0:
            begin_reload()
        return
    fire_cooldown = 0.24
    ammo -= 1
    get_tree().call_group("zombies", "hear_noise", global_position, 42.0)
    if ray.is_colliding():
        var target = ray.get_collider()
        if target and target.is_in_group("zombies"):
            target.take_damage(38.0)
    stats_changed.emit(health, hunger, thirst, stamina, ammo)

func begin_reload() -> void:
    if not is_reloading and ammo < MAGAZINE_SIZE and reserve_ammo > 0:
        is_reloading = true
        reload_timer = 1.65

func use_medkit() -> void:
    if medkits > 0 and health < 100.0:
        medkits -= 1
        health = minf(100.0, health + 45.0)
        bleeding = false
        stats_changed.emit(health, hunger, thirst, stamina, ammo)

func consume_food() -> void:
    if food > 0:
        food -= 1
        hunger = minf(100.0, hunger + 35.0)
        stats_changed.emit(health, hunger, thirst, stamina, ammo)

func consume_water() -> void:
    if water > 0:
        water -= 1
        thirst = minf(100.0, thirst + 40.0)
        stats_changed.emit(health, hunger, thirst, stamina, ammo)

func interact() -> void:
    if ray.is_colliding():
        var target = ray.get_collider()
        if target and target.is_in_group("loot") and target.has_method("collect"):
            target.collect(self)
    stats_changed.emit(health, hunger, thirst, stamina, ammo)

func take_damage(amount: float) -> void:
    health = maxf(0.0, health - amount)
    if randf() < 0.18:
        bleeding = true
    stats_changed.emit(health, hunger, thirst, stamina, ammo)
    if health <= 0.0:
        get_tree().call_deferred("reload_current_scene")
