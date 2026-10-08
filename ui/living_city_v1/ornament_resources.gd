extends RefCounted
## Manifest v1.3-art-20260929 profiles, kept explicit for export dependency discovery.
## Keeps the original PNG intact; cached in-memory texture regions only.

const SOURCES: Dictionary = {
  "lacquer_bar": {
    "path": "res://ui/living_city_v1/assets/ornaments/v1_3/lacquer_bar.png",
    "rect": [
      2,
      356,
      1847,
      135
    ]
  },
  "primary_red": {
    "path": "res://ui/living_city_v1/assets/ornaments/v1_3/primary_red.png",
    "rect": [
      40,
      260,
      1894,
      250
    ]
  },
  "work_panel_frame": {
    "path": "res://ui/living_city_v1/assets/ornaments/v1_3/work_panel_frame.png",
    "rect": [
      29,
      48,
      1017,
      1367
    ]
  },
  "candidate_frame": {
    "path": "res://ui/living_city_v1/assets/ornaments/v1_3/candidate_frame.png",
    "rect": [
      25,
      85,
      1360,
      938
    ]
  },
  "title_divider": {
    "path": "res://ui/living_city_v1/assets/ornaments/v1_3/title_divider.png",
    "rect": [
      48,
      318,
      2095,
      61
    ]
  },
  "city_heading_frame": {
    "path": "res://ui/living_city_v1/assets/ornaments/v1_3/city_heading_frame.png",
    "rect": [
      28,
      285,
      2055,
      174
    ]
  }
}
const PROFILES: Dictionary = {
  "top": {
    "asset": "lacquer_bar",
    "logical_texture_size": [
      1920,
      88
    ],
    "example_draw_size": [
      1920,
      78
    ],
    "slice_lrtb": [
      64,
      64,
      12,
      12
    ]
  },
  "bottom": {
    "asset": "lacquer_bar",
    "logical_texture_size": [
      1920,
      88
    ],
    "example_draw_size": [
      1920,
      88
    ],
    "slice_lrtb": [
      64,
      64,
      16,
      16
    ]
  },
  "primary": {
    "asset": "primary_red",
    "logical_texture_size": [
      648,
      72
    ],
    "example_draw_size": [
      648,
      72
    ],
    "slice_lrtb": [
      48,
      48,
      16,
      16
    ]
  },
  "work_panel": {
    "asset": "work_panel_frame",
    "logical_texture_size": [
      672,
      914
    ],
    "example_draw_size": [
      672,
      914
    ],
    "slice_lrtb": [
      24,
      24,
      24,
      24
    ]
  },
  "candidate": {
    "asset": "candidate_frame",
    "logical_texture_size": [
      192,
      152
    ],
    "example_draw_size": [
      185,
      147
    ],
    "slice_lrtb": [
      16,
      16,
      16,
      16
    ]
  },
  "officer_card": {
    "asset": "candidate_frame",
    "logical_texture_size": [
      192,
      152
    ],
    "example_draw_size": [
      648,
      182
    ],
    "slice_lrtb": [
      16,
      16,
      16,
      16
    ]
  },
  "nav_border": {
    "asset": "candidate_frame",
    "logical_texture_size": [
      192,
      152
    ],
    "example_draw_size": [
      279,
      64
    ],
    "slice_lrtb": [
      16,
      16,
      16,
      16
    ]
  },
  "divider": {
    "asset": "title_divider",
    "logical_texture_size": [
      648,
      12
    ],
    "example_draw_size": [
      648,
      12
    ],
    "slice_lrtb": [
      40,
      40,
      0,
      0
    ]
  },
  "nav_underline": {
    "asset": "title_divider",
    "logical_texture_size": [
      648,
      12
    ],
    "example_draw_size": [
      279,
      12
    ],
    "slice_lrtb": [
      40,
      40,
      0,
      0
    ]
  },
  "city_heading": {
    "asset": "city_heading_frame",
    "logical_texture_size": [
      1196,
      84
    ],
    "example_draw_size": [
      1196,
      83
    ],
    "slice_lrtb": [
      32,
      32,
      12,
      12
    ]
  }
}

const IMPORTED: Dictionary = {
    "lacquer_bar": preload("res://ui/living_city_v1/assets/ornaments/v1_3/generated/lacquer_bar.res"),
    "primary_red": preload("res://ui/living_city_v1/assets/ornaments/v1_3/generated/primary_red.res"),
    "work_panel_frame": preload("res://ui/living_city_v1/assets/ornaments/v1_3/generated/work_panel_frame.res"),
    "candidate_frame": preload("res://ui/living_city_v1/assets/ornaments/v1_3/generated/candidate_frame.res"),
    "title_divider": preload("res://ui/living_city_v1/assets/ornaments/v1_3/generated/title_divider.res"),
    "city_heading_frame": preload("res://ui/living_city_v1/assets/ornaments/v1_3/generated/city_heading_frame.res")
}
static var _textures: Dictionary = {}

static func texture(profile_name: String) -> Texture2D:
    if not PROFILES.has(profile_name):
        push_error("Unknown ornament profile: " + profile_name)
        return null
    var profile: Dictionary = PROFILES[profile_name]
    var asset_key: String = str(profile["asset"])
    var dims: Array = profile["logical_texture_size"]
    var cache_key: String = "%s:%s:%s" % [asset_key, dims[0], dims[1]]
    if _textures.has(cache_key):
        return _textures[cache_key] as Texture2D
    var source: Dictionary = SOURCES[asset_key]
    var imported: Texture2D = IMPORTED[asset_key]
    if imported == null:
        push_error("Missing ornament texture: " + str(source["path"]))
        return null
    var pixels: Image = imported.get_image()
    if pixels == null or pixels.is_empty():
        return null
    if pixels.is_compressed():
        if pixels.decompress() != OK:
            push_error("Cannot decompress ornament texture")
            return null
    var coords: Array = source["rect"]
    var region: Rect2i = Rect2i(int(coords[0]), int(coords[1]), int(coords[2]), int(coords[3]))
    if not Rect2i(Vector2i.ZERO, pixels.get_size()).encloses(region):
        push_error("Ornament source region is out of bounds")
        return null
    var result: ImageTexture = ImageTexture.create_from_image(pixels.get_region(region))
    result.set_size_override(Vector2i(int(dims[0]), int(dims[1])))
    _textures[cache_key] = result
    return result

## content_ltrb is LEFT, TOP, RIGHT, BOTTOM. Pass existing layout padding.
## For an overlay use zero; do not add it as a new Container layout item.
static func style(profile_name: String, tint: Color = Color.WHITE,
        content_ltrb: Vector4 = Vector4.ZERO) -> StyleBoxTexture:
    var tex: Texture2D = texture(profile_name)
    if tex == null:
        return null
    var profile: Dictionary = PROFILES[profile_name]
    var margins: Array = profile["slice_lrtb"]
    var box: StyleBoxTexture = StyleBoxTexture.new()
    box.texture = tex
    box.texture_margin_left = float(margins[0])
    box.texture_margin_right = float(margins[1])
    box.texture_margin_top = float(margins[2])
    box.texture_margin_bottom = float(margins[3])
    box.content_margin_left = content_ltrb.x
    box.content_margin_top = content_ltrb.y
    box.content_margin_right = content_ltrb.z
    box.content_margin_bottom = content_ltrb.w
    box.modulate_color = tint
    box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
    box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
    return box

