extends KinematicBody

export var speed := 5
export var gravity := -5
export var rotation_speed := 0.35
export(NodePath) var ground_path := "../Ground"

onready var cam_rig: Position3D = $CameraRig
onready var smp := $StateMachinePlayer
onready var ground := get_node(ground_path)
onready var marker: MeshInstance = get_node(String(ground_path)+"/Marker")
onready var tween: Tween = $Tween

var target = null
var velocity := Vector3.ZERO
var is_held := false

func _ready() -> void:
	assert(ground.connect("input_event", self, "_on_Ground_input_event") == OK)
	assert(ground.connect("mouse_exited", self, "_on_Ground_mouse_exited") == OK)
	cam_rig.set_as_toplevel(true)
	DebugOverlay.visible = true
	# warning-ignore:return_value_discarded
	DebugOverlay.add_monitor("Current state", self, "StateMachinePlayer:current")

func _process(_delta: float) -> void:
	cam_rig.transform.origin = transform.origin
	if target:
		transform = transform.orthonormalized()
		var new_transform := transform.looking_at(target, Vector3.UP)
		tween.interpolate_property(self, ":transform:basis", transform.basis, new_transform.basis, rotation_speed)
		transform.basis.y = Vector3.UP
		if not tween.is_active():
			tween.start()

func _on_Ground_input_event(_camera: Camera, event: InputEvent, click_position: Vector3, _click_normal: Vector3, _shape_idx: int) -> void:
	if event.is_action("move"):
		if transform.origin.distance_to(click_position) > 0.5:
			# Start is_held if the click is on the sprite.
			if not is_held and event.pressed:
				is_held = true
				marker.show()
				smp.set_trigger("target_set")

		# Stop is_held if the button is released.
		if is_held and not event.pressed:
			is_held = false
			smp.set_trigger("target_set")

	if event is InputEventMouseMotion and is_held:
		# While is_held, move the sprite with the mouse.
		target = click_position
		marker.transform.origin = target


func _on_Ground_mouse_exited() -> void:
	is_held = false

func _physics_process(delta: float) -> void:
	velocity.y += gravity * delta
	if target:
		velocity = -transform.basis.z * speed
		if transform.origin.distance_to(target) <= 0.75:
			target = null
			velocity = Vector3.ZERO
			smp.set_trigger("arrived")
			marker.hide()

	velocity = move_and_slide(velocity, Vector3.UP)


func _on_StateMachinePlayer_updated(state: String, _delta: float) -> void:
	match state:
		"Idle":
			set_physics_process(false)
		"Rotating":
			set_physics_process(false)
		"Moving":
			set_physics_process(true)

func _on_Tween_tween_completed(_object: Object, key: NodePath) -> void:
	if key == ":transform:basis":
		smp.set_trigger("finished_rotating")
