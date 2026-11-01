extends Area3D

func collect(player: Node) -> void:
    var kind: int = int(get_meta("loot_type", 0))
    match kind:
        0:
            player.medkits += 1
        1:
            player.ammo += 12
        2:
            player.hunger = minf(100.0, player.hunger + 25.0)
            player.thirst = minf(100.0, player.thirst + 15.0)
    queue_free()
