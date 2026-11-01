extends CharacterBody3D

var health := 100.0
var speed := 1.65
var attack_timer := 0.0
var target: Node3D
var wander_time := 0.0

func _ready() -> void:
    add_to_group("zombies")
    target = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
    attack_timer = maxf(0.0, attack_timer - delta)
    if not is_instance_valid(target):
        target = get_tree().get_first_node_in_group("player")
        return
    var distance := global_position.distance_to(target.global_position)
    if distance < 24.0:
        var direction := target.global_position - global_position
        direction.y = 0
        if direction.length() > 0.1:
            velocity.x = direction.normalized().x * speed
            velocity.z = direction.normalized().z * speed
            look_at(Vector3(target.global_position.x, global_position.y, target.global_position.z))
        if distance < 1.55 and attack_timer <= 0.0:
            attack_timer = 1.1
            target.take_damage(9.0)
    else:
        wander_time -= delta
        if wander_time <= 0.0:
            wander_time = randf_range(2.0, 5.0)
            rotation.y += randf_range(-2.5, 2.5)
        velocity.x = -global_basis.z.x * speed * 0.35
        velocity.z = -global_basis.z.z * speed * 0.35
    if not is_on_floor():
        velocity.y -= 18.0 * delta
    move_and_slide()

func take_damage(amount: float) -> void:
    health -= amount
    if health <= 0.0:
        queue_free()
