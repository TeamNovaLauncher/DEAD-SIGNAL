extends Control

var player: CharacterBody3D
var left_finger := -1
var look_finger := -1
var stick_origin := Vector2.ZERO
var stick_vector := Vector2.ZERO
var look_sensitivity := 1.0
var held_actions: Array[String] = []

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _make_button("FIRE", Vector2(0.86, 0.76), "fire", true)
    _make_button("RELOAD", Vector2(0.86, 0.91), "reload", false)
    _make_button("JUMP", Vector2(0.70, 0.88), "jump", false)
    _make_button("SPRINT", Vector2(0.53, 0.88), "sprint", true)
    _make_button("CROUCH", Vector2(0.70, 0.72), "crouch", true)
    _make_button("USE", Vector2(0.53, 0.72), "interact", false)
    _make_button("HEAL", Vector2(0.86, 0.59), "heal", false)
    _make_button("EAT", Vector2(0.70, 0.56), "eat", false)
    _make_button("WATER", Vector2(0.53, 0.56), "drink", false)

func _make_button(caption: String, anchor: Vector2, action: String, hold: bool) -> void:
    var b := Button.new()
    b.text = caption
    b.anchor_left = anchor.x
    b.anchor_right = anchor.x
    b.anchor_top = anchor.y
    b.anchor_bottom = anchor.y
    b.offset_left = -43
    b.offset_right = 43
    b.offset_top = -25
    b.offset_bottom = 25
    b.add_theme_font_size_override("font_size", 13)
    b.modulate = Color(1.0, 1.0, 1.0, 0.78)
    b.focus_mode = Control.FOCUS_NONE
    add_child(b)
    if hold:
        b.button_down.connect(func(): Input.action_press(action))
        b.button_up.connect(func(): Input.action_release(action))
    else:
        b.pressed.connect(func(): _tap_action(action))

func _tap_action(action: String) -> void:
    Input.action_press(action)
    await get_tree().create_timer(0.08).timeout
    Input.action_release(action)

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            if event.position.x < size.x * 0.43 and event.position.y > size.y * 0.48:
                left_finger = event.index
                stick_origin = event.position
                stick_vector = Vector2.ZERO
                _update_movement()
                queue_redraw()
            elif event.position.x > size.x * 0.43:
                look_finger = event.index
        else:
            if event.index == left_finger:
                left_finger = -1
                stick_vector = Vector2.ZERO
                _update_movement()
                queue_redraw()
            if event.index == look_finger:
                look_finger = -1
    elif event is InputEventScreenDrag:
        if event.index == left_finger:
            stick_vector = (event.position - stick_origin).limit_length(90.0) / 90.0
            _update_movement()
            queue_redraw()
        elif event.index == look_finger and is_instance_valid(player):
            player.rotate_camera(event.relative * look_sensitivity)

func _update_movement() -> void:
    _set_axis("move_left", stick_vector.x < -0.18)
    _set_axis("move_right", stick_vector.x > 0.18)
    _set_axis("move_forward", stick_vector.y < -0.18)
    _set_axis("move_back", stick_vector.y > 0.18)

func _set_axis(action: String, pressed: bool) -> void:
    if pressed and not Input.is_action_pressed(action):
        Input.action_press(action)
    elif not pressed and Input.is_action_pressed(action):
        Input.action_release(action)

func _draw() -> void:
    if left_finger != -1:
        draw_circle(stick_origin, 55.0, Color(0.1, 0.85, 0.75, 0.20))
        draw_circle(stick_origin + stick_vector * 48.0, 24.0, Color(0.35, 0.95, 0.85, 0.55))

func _exit_tree() -> void:
    for action in ["move_left", "move_right", "move_forward", "move_back", "fire", "jump", "sprint", "crouch"]:
        Input.action_release(action)
