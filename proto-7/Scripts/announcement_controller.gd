extends NinePatchRect

const GENERAL_POSITION := Vector2(216, 108)
const LARGE_POSITION := Vector2(72, 144)
const LINE_STEP := Vector2(8, 8)
const PADDING := Vector2(8, 4)
const GAP := 4.0

@onready var label: Label = $Label
var revision := 0
var preferred_position := GENERAL_POSITION


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()


func announce(message: String, preferred: Vector2 = GENERAL_POSITION, delay: float = 0.0) -> void:
	revision += 1
	var request := revision
	if delay > 0.0:
		hide()
		await get_tree().create_timer(delay).timeout
		if request != revision:
			return
	show_line(message, preferred)


func announce_hit(bases: int, grounder: bool = false) -> void:
	revision += 1
	var request := revision
	hide()
	await get_tree().create_timer(0.12).timeout
	var lines: Array = [AnnouncementText.GROUND_BALL] if grounder else AnnouncementText.HIT_LINES[bases]
	for i in range(lines.size()):
		if request != revision:
			return
		show_line(lines[i], GENERAL_POSITION + LINE_STEP * (i + 1))
		if i + 1 < lines.size():
			await get_tree().create_timer(0.85).timeout


func show_line(message: String, preferred: Vector2) -> void:
	preferred_position = preferred
	label.text = AnnouncementText.QUOTED_LINE % message
	if layout_message():
		show()


func layout_message() -> bool:
	var obstacles: Array[Rect2] = []
	for box in get_parent().find_children("*", "NinePatchRect", true, false):
		if box != self and box.is_visible_in_tree():
			obstacles.append(box.get_global_rect().grow(GAP))
	var bounds := Rect2(Vector2.ONE * GAP, get_viewport_rect().size - Vector2.ONE * GAP * 2.0)
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	var natural_width := ceilf(font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	for max_width in [352.0, 280.0, 420.0, 216.0, 160.0]:
		var width := minf(natural_width, max_width - PADDING.x * 2.0)
		var text_size := font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, -1, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE)
		var line_count := maxi(1, roundi(text_size.y / font.get_height(font_size)))
		var text_height := ceilf(text_size.y) + label.get_theme_constant("line_spacing") * (line_count - 1)
		var box_size := Vector2(width, text_height) + PADDING * 2.0
		var candidates := [preferred_position, LARGE_POSITION, GENERAL_POSITION]
		for point in candidates:
			if fits(Rect2(point, box_size), bounds, obstacles):
				place_box(point, box_size)
				return true
		for y in range(4, int(bounds.end.y - box_size.y) + 1, 8):
			for x in range(4, int(bounds.end.x - box_size.x) + 1, 8):
				var point := Vector2(x, y)
				if fits(Rect2(point, box_size), bounds, obstacles):
					place_box(point, box_size)
					return true
	# shortcut: dialogue must fit one free rectangle; paginate when adding longer speeches.
	hide()
	push_warning("Announcement has no free space on screen")
	return false


func fits(rect: Rect2, bounds: Rect2, obstacles: Array[Rect2]) -> bool:
	if not bounds.encloses(rect):
		return false
	for obstacle in obstacles:
		if rect.intersects(obstacle):
			return false
	return true


func place_box(point: Vector2, box_size: Vector2) -> void:
	global_position = point.round()
	size = box_size
	label.position = PADDING
	label.size.x = box_size.x - PADDING.x * 2.0
	label.size.y = box_size.y - PADDING.y * 2.0
