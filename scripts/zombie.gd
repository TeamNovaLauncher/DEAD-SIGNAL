extends CharacterBody3D

enum InfectedType { SHAMBLER, RUNNER, BRUTE, NIGHT_STALKER }
@export var infected_type: InfectedType = InfectedType.SHAMBLER
var health := 100.0
var speed := 1.55
var damage := 9.0
var attack_range := 1.55
var sight_range := 22.0
var hearing_range := 30.0
var attack_timer := 0.0
var target: Node3D
var last_known_position := Vector3.ZERO
var alert_timer := 0.0
var wander_time := 0.0
var gravity := 18.0

func _ready() -> void:
    add_to_group("zombies")
    match infected_type:
        InfectedType.RUNNER:
            health = 65.0
            speed = 3.8
            damage = 7.0
            hearing_range = 48.0
        InfectedType.BRUTE:
            health = 260.0
            speed = 1.0
            damage = 24.0
            attack_range = 2.0
        InfectedType.NIGHT_STALKER:
            health = 90.0
            speed = 2.8
            damage = 14.0
            sight_range = 34.0
    target = get_tree().get_first_node_in_group("player")

func hear_noise(noise_position: Vector3, radius: float) -> void:
    if global_position.distance_to(noise_position) <= minf(radius, hearing_range):
        last_known_position = noise_position
        alert_timer = 12.0

func _physics_process(delta: float) -> void:
    attack_timer = maxf(0.0, attack_timer - delta)
    alert_timer = maxf(0.0, alert_timer - delta)
    if not is_instance_valid(target):
        target = get_tree().get_first_node_in_group("player")
        return
    var distance := global_position.distance_to(target.global_position)
    var can_see := distance < sight_range
    if can_see:
        var space := get_world_3d().direct_space_state
        var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, target.global_position + Vector3.UP * 0.5)
        query.exclude = [get_rid()]
        var hit := space.intersect_ray(query)
        can_see = hit.is_empty() or hit.get("collider") == target
    if can_see:
        last_known_position = target.global_position
        alert_timer = 4.0
    if can_see or alert_timer > 0.0:
        var destination := target.global_position if can_see else last_known_position
        var direction := destination - global_position
        direction.y = 0.0
        if direction.length() > 0.25:
            velocity.x = direction.normalized().x * speed
            velocity.z = direction.normalized().z * speed
            look_at(Vector3(destination.x, global_position.y, destination.z))
        else:
            velocity.x = move_toward(velocity.x, 0.0, speed)
            velocity.z = move_toward(velocity.z, 0.0, speed)
        if distance < attack_range and can_see and attack_timer <= 0.0:
            attack_timer = 1.15
            target.take_damage(damage)
    else:
        wander_time -= delta
        if wander_time <= 0.0:
            wander_time = randf_range(2.0, 5.0)
            rotation.y += randf_range(-2.5, 2.5)
        velocity.x = -global_basis.z.x * speed * 0.25
        velocity.z = -global_basis.z.z * speed * 0.25
    if not is_on_floor():
        velocity.y -= gravity * delta
    move_and_slide()

func take_damage(amount: float) -> void:
    health -= amount
    if health <= 0.0:
        queue_free()
