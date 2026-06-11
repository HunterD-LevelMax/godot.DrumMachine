## ui/drum_theme.gd
## Central style factory for the drum machine UI.
## All StyleBoxFlat construction lives here so that colours and shapes
## are defined in one place and never duplicated across controllers.
class_name DrumTheme

const ROW_COLORS: Array[Color] = [
	Color("#FF3D7F"),  # 0: kick
	Color("#00FFA8"),  # 1: snare
	Color("#1FB6FF"),  # 2: hat
	Color("#FFD54A"),  # 3: bass
	Color("#FF6B35"),  # 4: percussion
	Color("#A855F7"),  # 5: synth
	Color("#06B6D4"),  # 6: fx
	Color("#F43F5E"),  # 7: melody
	Color("#10B981"),  # 8: arp
	Color("#F59E0B"),  # 9: misc
]

const ROW_NAMES: Array[String] = [
	"KICK", "SNARE", "HAT", "BASS",
	"PERC", "SYNTH", "FX", "MELODY",
	"ARP", "MISC",
]

static var _mute_style_cache: Dictionary = {}
static var _slot_style_cache: Dictionary = {}


static func row_color(index: int) -> Color:
	return ROW_COLORS[index % ROW_COLORS.size()]


static func row_name(index: int) -> String:
	return ROW_NAMES[index % ROW_NAMES.size()]


# ── Step buttons ──────────────────────────────────────────────────────────────

## Returns [normal, hover, pressed] StyleBoxFlat for a step button.
static func step_styles(velocity: int, row: int, is_beat: bool) -> Array[StyleBoxFlat]:
	var base   := ROW_COLORS[row % ROW_COLORS.size()]
	var normal := StyleBoxFlat.new()
	normal.set_corner_radius_all(14)

	if velocity > 0:
		var t := velocity / 4.0
		normal.bg_color     = base.darkened(0.08).lerp(Color(0.05, 0.05, 0.09), 1.0 - t)
		normal.border_color = base.lerp(base.darkened(0.55), 1.0 - t)
		normal.set_border_width_all(4)
		normal.shadow_color = base
		normal.shadow_size  = int(7.0 * t)
	else:
		normal.bg_color     = Color(0.08, 0.08, 0.12) if is_beat else Color(0.04, 0.04, 0.07)
		normal.border_color = base.darkened(0.62)
		normal.set_border_width_all(2)

	var hover   := normal.duplicate() as StyleBoxFlat
	var pressed := normal.duplicate() as StyleBoxFlat
	if velocity > 0:
		hover.bg_color    = base.lightened(0.18)
		hover.shadow_size = 12
	else:
		hover.bg_color = base.darkened(0.42)
	pressed.bg_color = base.darkened(0.22)

	return [normal, hover, pressed]


# ── Mute buttons ──────────────────────────────────────────────────────────────

static func mute_style(is_muted: bool, row: int) -> StyleBoxFlat:
	var key := Vector2i(int(is_muted), row)
	if _mute_style_cache.has(key):
		return _mute_style_cache[key]
	var color := ROW_COLORS[row % ROW_COLORS.size()]
	var s     := StyleBoxFlat.new()
	s.set_corner_radius_all(8)
	if is_muted:
		s.bg_color     = color.darkened(0.25)
		s.border_color = color
		s.set_border_width_all(2)
		s.shadow_color = color
		s.shadow_size  = 5
	else:
		s.bg_color     = Color(0.06, 0.06, 0.09)
		s.border_color = color.darkened(0.55)
		s.set_border_width_all(1)
	_mute_style_cache[key] = s
	return s


# ── Save slot buttons ─────────────────────────────────────────────────────────

static func slot_style(row: int, is_active: bool, has_data: bool) -> StyleBoxFlat:
	var key := Vector3i(row, int(is_active), int(has_data))
	if _slot_style_cache.has(key):
		return _slot_style_cache[key]
	var color := ROW_COLORS[row % ROW_COLORS.size()]
	var s     := StyleBoxFlat.new()
	s.set_corner_radius_all(10)
	s.set_border_width_all(2)
	if is_active:
		s.bg_color     = color.darkened(0.2)
		s.border_color = color
		s.shadow_color = color
		s.shadow_size  = 6
	else:
		s.bg_color     = Color(0.05, 0.05, 0.09)
		s.border_color = color.darkened(0.3 if has_data else 0.6)
	_slot_style_cache[key] = s
	return s


# ── Action buttons (Save / Load) ──────────────────────────────────────────────

## Returns [normal, hover, pressed] StyleBoxFlat.
static func action_button_styles(color: Color) -> Array[StyleBoxFlat]:
	var s := StyleBoxFlat.new()
	s.set_corner_radius_all(10)
	s.set_border_width_all(2)
	s.bg_color     = color.darkened(0.72)
	s.border_color = color.darkened(0.15)
	s.shadow_color = color
	s.shadow_size  = 4

	var sh := s.duplicate() as StyleBoxFlat
	sh.shadow_size = 10
	sh.bg_color    = color.darkened(0.55)

	var sp := s.duplicate() as StyleBoxFlat
	sp.bg_color = color.darkened(0.40)

	return [s, sh, sp]


# ── Velocity popup ────────────────────────────────────────────────────────────

static func velocity_popup_bg(row: int) -> StyleBoxFlat:
	var color := row_color(row)
	var s     := StyleBoxFlat.new()
	s.bg_color     = Color(0.06, 0.06, 0.12, 0.98)
	s.border_color = color.darkened(0.38)
	s.set_border_width_all(1)
	s.set_corner_radius_all(12)
	s.shadow_color = color.darkened(0.15)
	s.shadow_size  = 4
	return s


# ── Scrollbar ─────────────────────────────────────────────────────────────────

## Applies a thick, styled vertical scrollbar to any ScrollContainer.
static func style_scrollbar(scroll: ScrollContainer) -> void:
	_style_bar(scroll.get_v_scroll_bar(), true)


## Applies a thick, styled horizontal scrollbar to any ScrollContainer.
static func style_h_scrollbar(scroll: ScrollContainer) -> void:
	_style_bar(scroll.get_h_scroll_bar(), false)


static func _style_bar(sb: ScrollBar, vertical: bool) -> void:
	if vertical:
		sb.custom_minimum_size.x = 16
	else:
		sb.custom_minimum_size.y = 16

	var bg := StyleBoxEmpty.new()
	sb.add_theme_stylebox_override("scroll", bg)

	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(0, 0.83, 1, 0.45)
	grabber.set_corner_radius_all(8)
	if vertical:
		grabber.content_margin_left  = 3
		grabber.content_margin_right = 3
	else:
		grabber.content_margin_top    = 3
		grabber.content_margin_bottom = 3
	sb.add_theme_stylebox_override("grabber", grabber)

	var grabber_hl := grabber.duplicate() as StyleBoxFlat
	grabber_hl.bg_color = Color(0, 0.83, 1, 0.75)
	sb.add_theme_stylebox_override("grabber_highlight", grabber_hl)
	sb.add_theme_stylebox_override("grabber_pressed",   grabber_hl)


## Returns [normal, hover] StyleBoxFlat for a single velocity choice button.
static func velocity_button_styles(v: int, current_v: int, row: int) -> Array[StyleBoxFlat]:
	var color := row_color(row)
	var s     := StyleBoxFlat.new()
	s.set_corner_radius_all(7)
	s.content_margin_left   = 12.0
	s.content_margin_right  = 12.0
	s.content_margin_top    = 6.0
	s.content_margin_bottom = 6.0
	if v == current_v:
		s.bg_color     = color.darkened(0.52)
		s.border_color = color.darkened(0.18)
		s.set_border_width_all(1)
		s.shadow_color = color.darkened(0.1)
		s.shadow_size  = 3
	else:
		s.bg_color     = Color(0.0, 0.0, 0.0, 0.0)
		s.set_border_width_all(0)

	var sh := s.duplicate() as StyleBoxFlat
	sh.bg_color     = color.darkened(0.62)
	sh.border_color = color.darkened(0.32)
	sh.set_border_width_all(1)
	sh.shadow_size  = 0
	return [s, sh]
