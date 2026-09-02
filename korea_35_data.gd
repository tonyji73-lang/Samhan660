extends RefCounted

# 확정된 한반도 35개 전략 지역 데이터.
# 기존 WorldMapData를 대체하지 않고 한국 데이터만 병합하기 위한 모듈입니다.

# 배경 지도의 실제 픽셀 크기입니다. UV(0~1)는 정사각 좌표계라서
# 수직 방향을 UV에서 바로 계산하면 화면에서는 수직이 아니게 됩니다.
const MAP_PIXEL_SIZE: Vector2 = Vector2(6144.0, 4096.0)

# 도로가 휘는 정도를 "길이에 대한 비율"로 정의합니다. 절대값을 쓰면
# 짧은 도로가 자기 길이보다 크게 부풀어 올라 고리처럼 보입니다.
const BEND_RATIO_LAND: float = 0.10
const BEND_RATIO_MOUNTAIN: float = 0.14
const BEND_RATIO_SEA: float = 0.16

# 아주 긴 항로가 지도를 가로지르며 과하게 휘는 것을 막는 상한선(픽셀)입니다.
const BEND_MAX_PIXELS: float = 140.0

const FIXED_COORDINATES: Dictionary = {
	"ansi": Vector2(0.435, 0.365),
	"gungnae": Vector2(0.530, 0.335),
	"pyongyang": Vector2(0.500, 0.450),
	"ungjin": Vector2(0.515, 0.555),
	"sabi": Vector2(0.520, 0.585),
	"gosa": Vector2(0.515, 0.615),
	"gukwon": Vector2(0.550, 0.540),
	"sabeol": Vector2(0.560, 0.580),
	"geumseong": Vector2(0.595, 0.610),
}

const PROVINCE_IDS: Array[String] = [
	"shinseong", "sokgunseong", "ansi", "geonanseong", "gungnae",
	"chaekseong", "bireyeolhol", "pyongyang", "daedonggang", "goksan",
	"hwanghae", "bukhansan", "danghangseong", "samnyeonsanseong", "gukwon",
	"haslla", "siljik", "imjonseong", "ungjin", "sabi", "geummajeo",
	"gosa", "juryuseong", "yeongsangang", "geumseong", "sabeol",
	"dalgubeol", "daegaya", "geumgwan", "sogaya", "tamna", "ulleung",
	"ganghwa", "jukryeong", "chupungnyeong",
]

const PROVINCE_NAMES: Dictionary = {
	"shinseong": "신성", "sokgunseong": "속군성", "ansi": "안시성",
	"geonanseong": "건안성", "gungnae": "국내성", "chaekseong": "책성·동북 변경",
	"bireyeolhol": "비열홀", "pyongyang": "평양성", "daedonggang": "대동강 하류",
	"goksan": "곡산 내륙", "hwanghae": "황해 남부", "bukhansan": "북한산성",
	"danghangseong": "당항성", "samnyeonsanseong": "삼년산성", "gukwon": "국원",
	"haslla": "하슬라", "siljik": "실직", "imjonseong": "임존성",
	"ungjin": "웅진성", "sabi": "사비성", "geummajeo": "금마저",
	"gosa": "고사부리", "juryuseong": "주류성", "yeongsangang": "영산강 권역",
	"geumseong": "금성·월성", "sabeol": "사벌", "dalgubeol": "달구벌",
	"daegaya": "대가야", "geumgwan": "금관가야", "sogaya": "소가야",
	"tamna": "탐라", "ulleung": "울릉", "ganghwa": "강화·한강 하구",
	"jukryeong": "죽령 교통권", "chupungnyeong": "추풍령 교통권",
}

const PROVINCE_MAP_UV: Dictionary = {
	"shinseong": Vector2(0.455, 0.310), "sokgunseong": Vector2(0.415, 0.350),
	"ansi": Vector2(0.435, 0.365), "geonanseong": Vector2(0.430, 0.420),
	"gungnae": Vector2(0.530, 0.335), "chaekseong": Vector2(0.585, 0.315),
	"bireyeolhol": Vector2(0.570, 0.380), "pyongyang": Vector2(0.500, 0.450),
	"daedonggang": Vector2(0.485, 0.475), "goksan": Vector2(0.545, 0.455),
	"hwanghae": Vector2(0.470, 0.490), "bukhansan": Vector2(0.505, 0.500),
	"danghangseong": Vector2(0.475, 0.525), "samnyeonsanseong": Vector2(0.545, 0.515),
	"gukwon": Vector2(0.550, 0.540), "haslla": Vector2(0.590, 0.480),
	"siljik": Vector2(0.600, 0.530), "imjonseong": Vector2(0.490, 0.540),
	"ungjin": Vector2(0.515, 0.555), "sabi": Vector2(0.520, 0.585),
	"geummajeo": Vector2(0.490, 0.590), "gosa": Vector2(0.515, 0.615),
	"juryuseong": Vector2(0.470, 0.625), "yeongsangang": Vector2(0.480, 0.665),
	"geumseong": Vector2(0.595, 0.610), "sabeol": Vector2(0.560, 0.580),
	"dalgubeol": Vector2(0.560, 0.630), "daegaya": Vector2(0.530, 0.660),
	"geumgwan": Vector2(0.570, 0.690), "sogaya": Vector2(0.540, 0.690),
	"tamna": Vector2(0.490, 0.790), "ulleung": Vector2(0.620, 0.550),
	"ganghwa": Vector2(0.455, 0.485), "jukryeong": Vector2(0.575, 0.555),
	"chupungnyeong": Vector2(0.540, 0.600),
}

const DEFAULT_FACTIONS: Dictionary = {
	"shinseong": "고구려", "sokgunseong": "고구려", "ansi": "고구려",
	"geonanseong": "고구려", "gungnae": "고구려", "chaekseong": "고구려",
	"bireyeolhol": "고구려", "pyongyang": "고구려", "daedonggang": "고구려",
	"goksan": "고구려", "hwanghae": "고구려", "bukhansan": "신라",
	"danghangseong": "신라", "samnyeonsanseong": "신라", "gukwon": "신라",
	"haslla": "신라", "siljik": "신라", "imjonseong": "백제", "ungjin": "백제",
	"sabi": "백제", "geummajeo": "백제", "gosa": "백제", "juryuseong": "백제",
	"yeongsangang": "백제", "geumseong": "신라", "sabeol": "신라",
	"dalgubeol": "신라", "daegaya": "가야", "geumgwan": "가야",
	"sogaya": "가야", "tamna": "탐라", "ulleung": "신라",
	"ganghwa": "신라", "jukryeong": "신라", "chupungnyeong": "신라",
}

const SCENARIO_YEARS: Array[int] = [632, 642, 660, 663, 670]

# 연도별 소속 변경표.
# 기준선은 DEFAULT_FACTIONS(660년 봄, 백제 멸망 직전)이고, 아래에 적힌 지역만
# 덮어씁니다. 적히지 않은 지역은 기준선을 그대로 따릅니다.
#
# ※ 이 표는 초안입니다. 아래 주석의 근거를 확인하고 직접 조정하세요.
const YEAR_FACTION_OVERRIDES: Dictionary = {
	# 632년 · 선덕여왕 즉위.
	# 아직 대야성 함락(642) 전이라 낙동강 서안이 신라 세력권입니다.
	632: {
		"daegaya": "신라",
		"sogaya": "신라",
	},

	# 642년 · 의자왕이 신라 서부 40여 성과 대야성(합천)을 함락.
	# 낙동강 서안이 백제로 넘어가며 신라가 당에 원군을 청하는 계기가 됩니다.
	642: {
		"daegaya": "백제",
		"sogaya": "백제",
	},

	# 660년 · 백제 멸망 전야. 642년 구도가 유지된 상태에서 시작합니다.
	660: {
		"daegaya": "백제",
		"sogaya": "백제",
	},

	# 663년 · 백강 전투.
	# 사비·웅진에 당의 웅진도독부가 들어서고, 부흥군이 주류성과 임존성을
	# 중심으로 서부를 장악한 상태입니다. 백제가 되찾았던 낙동강 서안은
	# 660년 이후 신라가 회복했습니다.
	663: {
		"sabi": "당",
		"ungjin": "당",
		"yeongsangang": "당",
		"juryuseong": "백제부흥군",
		"imjonseong": "백제부흥군",
		"geummajeo": "백제부흥군",
		"gosa": "백제부흥군",
		"daegaya": "신라",
		"sogaya": "신라",
	},

	# 670년 · 나당전쟁 개전.
	# 고구려 멸망(668) 후 옛 고구려 땅에 안동도호부가 설치된 상태입니다.
	# 검모잠이 한성(황해 남부)에서 봉기하고, 안승은 신라가 금마저에
	# 안치해 보덕국을 세웁니다. 옛 백제 땅은 웅진도독부(사비·웅진)를
	# 제외하면 신라가 장악해 가는 중입니다.
	670: {
		"shinseong": "당",
		"sokgunseong": "당",
		"ansi": "당",
		"geonanseong": "당",
		"gungnae": "당",
		"chaekseong": "당",
		"bireyeolhol": "당",
		"pyongyang": "당",
		"daedonggang": "당",
		"goksan": "당",
		"hwanghae": "고구려부흥군",
		"geummajeo": "고구려부흥군",
		"sabi": "당",
		"ungjin": "당",
		"imjonseong": "신라",
		"gosa": "신라",
		"juryuseong": "신라",
		"yeongsangang": "신라",
		"daegaya": "신라",
		"sogaya": "신라",
		"geumgwan": "신라",
	},
}


static func get_factions_for_year(year: int) -> Dictionary:
	var result: Dictionary = DEFAULT_FACTIONS.duplicate(true)

	# 정확히 일치하는 시나리오가 없으면 그 이하의 가장 가까운 연도를 씁니다.
	var applied_year: int = SCENARIO_YEARS[0]
	for candidate_year: int in SCENARIO_YEARS:
		if year >= candidate_year:
			applied_year = candidate_year

	var overrides: Dictionary = YEAR_FACTION_OVERRIDES.get(applied_year, {})
	for province_key: Variant in overrides.keys():
		result[str(province_key)] = str(overrides[province_key])

	return result


static func get_province_templates_for_year(year: int) -> Dictionary:
	var result: Dictionary = get_province_templates()
	var factions: Dictionary = get_factions_for_year(year)
	for province_id: String in PROVINCE_IDS:
		if result.has(province_id):
			result[province_id]["faction"] = str(factions[province_id])
	return result


const DEFAULT_GENERAL_NAMES: Dictionary = {
	"ansi": "양만춘", "gungnae": "고연무", "pyongyang": "연개소문",
	"ungjin": "흑치상지", "sabi": "의자왕", "gosa": "부여태",
	"gukwon": "김법민", "sabeol": "품일", "geumseong": "김춘추",
}

const LAND_ROADS: Array = [
	["shinseong", "sokgunseong"], ["shinseong", "ansi"], ["shinseong", "gungnae"],
	["ansi", "geonanseong"], ["geonanseong", "pyongyang"], ["gungnae", "chaekseong"],
	["gungnae", "bireyeolhol"], ["gungnae", "goksan"], ["bireyeolhol", "goksan"],
	["pyongyang", "daedonggang"], ["pyongyang", "goksan"], ["daedonggang", "hwanghae"],
	["goksan", "bukhansan"], ["goksan", "haslla"], ["hwanghae", "bukhansan"],
	["hwanghae", "danghangseong"], ["bukhansan", "samnyeonsanseong"],
	["danghangseong", "imjonseong"], ["samnyeonsanseong", "gukwon"],
	["samnyeonsanseong", "imjonseong"], ["gukwon", "ungjin"], ["gukwon", "sabeol"],
	["haslla", "siljik"], ["siljik", "geumseong"], ["imjonseong", "ungjin"],
	["ungjin", "sabi"], ["sabi", "geummajeo"], ["sabi", "gosa"],
	["geummajeo", "juryuseong"], ["juryuseong", "yeongsangang"],
	["yeongsangang", "sogaya"], ["geumseong", "dalgubeol"],
	["geumseong", "geumgwan"], ["sabeol", "dalgubeol"], ["dalgubeol", "daegaya"],
	["daegaya", "geumgwan"], ["daegaya", "sogaya"],
]

const MOUNTAIN_ROADS: Array = [
	["samnyeonsanseong", "jukryeong", "mountain"], ["gukwon", "jukryeong", "mountain"],
	["haslla", "jukryeong", "mountain"], ["siljik", "jukryeong", "mountain"],
	["gukwon", "chupungnyeong", "mountain"], ["gosa", "chupungnyeong", "mountain"],
	["sabeol", "chupungnyeong", "mountain"], ["dalgubeol", "chupungnyeong", "mountain"],
]

const SEA_ROADS: Array = [
	["danghangseong", "ganghwa", "sea"], ["ganghwa", "daedonggang", "sea"],
	["yeongsangang", "tamna", "sea"], ["sogaya", "tamna", "sea"],
	["haslla", "ulleung", "sea"], ["siljik", "ulleung", "sea"],
]

static func get_roads() -> Array:
	var result: Array = LAND_ROADS.duplicate(true)
	result.append_array(MOUNTAIN_ROADS.duplicate(true))
	result.append_array(SEA_ROADS.duplicate(true))
	return result

static func get_city_button_names() -> Dictionary:
	var result: Dictionary = {}
	for province_id: String in PROVINCE_IDS:
		result[province_id] = "%sButton" % province_id.to_pascal_case()
	return result

static func get_province_templates() -> Dictionary:
	var result: Dictionary = {}
	for index: int in range(PROVINCE_IDS.size()):
		var province_id: String = PROVINCE_IDS[index]
		var faction: String = str(DEFAULT_FACTIONS[province_id])
		var governor: String = str(DEFAULT_GENERAL_NAMES.get(province_id, "%s 수장" % PROVINCE_NAMES[province_id]))
		var base_population: int = 55000 + (index % 6) * 9000
		var base_troops: int = 7000 + (index % 5) * 1800
		result[province_id] = {
			"name": PROVINCE_NAMES[province_id], "faction": faction, "governor": governor,
			"population": base_population, "agriculture": 55 + (index % 5) * 4,
			"commerce": 48 + (index % 6) * 4, "public_order": 68 + (index % 4) * 4,
			"troops": base_troops, "fortress": 58 + (index % 6) * 5,
		}
	return result

static func get_connections() -> Dictionary:
	var result: Dictionary = {}
	for province_id: String in PROVINCE_IDS:
		result[province_id] = []
	for road_value: Variant in get_roads():
		var road: Array = road_value
		var from_id: String = str(road[0])
		var to_id: String = str(road[1])
		result[from_id].append(to_id)
		result[to_id].append(from_id)
	return result

static func _road_kind(road: Array) -> String:
	return str(road[2]) if road.size() > 2 else "land"


static func _bend_ratio(kind: String) -> float:
	match kind:
		"sea":
			return BEND_RATIO_SEA
		"mountain":
			return BEND_RATIO_MOUNTAIN
		_:
			return BEND_RATIO_LAND


static func get_road_waypoints() -> Dictionary:
	var result: Dictionary = {}

	# 휘는 방향을 배열 작성 순서가 아니라 지도 무게중심 기준으로 정합니다.
	# 덕분에 ["a","b"]로 쓰든 ["b","a"]로 쓰든 결과가 같고,
	# 모든 도로가 바깥쪽으로 벌어져 서로 파고들지 않습니다.
	var centroid: Vector2 = Vector2.ZERO
	for province_id: String in PROVINCE_IDS:
		centroid += Vector2(PROVINCE_MAP_UV[province_id]) * MAP_PIXEL_SIZE
	centroid /= float(PROVINCE_IDS.size())

	for road_value: Variant in get_roads():
		var road: Array = road_value
		if road.size() < 2:
			continue

		var from_id: String = str(road[0])
		var to_id: String = str(road[1])
		if not PROVINCE_MAP_UV.has(from_id) or not PROVINCE_MAP_UV.has(to_id):
			push_warning("도로 좌표 누락: %s_%s" % [from_id, to_id])
			continue

		# 픽셀 공간으로 변환해 계산해야 화면상에서도 수직이 나옵니다.
		var from_px: Vector2 = Vector2(PROVINCE_MAP_UV[from_id]) * MAP_PIXEL_SIZE
		var to_px: Vector2 = Vector2(PROVINCE_MAP_UV[to_id]) * MAP_PIXEL_SIZE
		var delta: Vector2 = to_px - from_px
		var length: float = delta.length()
		if length < 0.001:
			continue

		var mid_px: Vector2 = (from_px + to_px) * 0.5
		var normal: Vector2 = Vector2(-delta.y, delta.x) / length
		if normal.dot(mid_px - centroid) < 0.0:
			normal = -normal

		var offset: float = minf(
			length * _bend_ratio(_road_kind(road)),
			BEND_MAX_PIXELS
		)
		var control_px: Vector2 = mid_px + normal * offset

		result["%s_%s" % [from_id, to_id]] = [control_px / MAP_PIXEL_SIZE]

	return result

static func merge_world_dictionary(world_data: Dictionary, korea_data: Dictionary) -> Dictionary:
	var result: Dictionary = world_data.duplicate(true)
	for old_id: String in ["ansi", "gungnae", "pyongyang", "ungjin", "sabi", "gosa", "gukwon", "sabeol", "geumseong"]:
		result.erase(old_id)
	for key_value: Variant in korea_data.keys():
		result[str(key_value)] = korea_data[key_value]
	return result

static func get_world_roads(world_roads: Array) -> Array:
	var result: Array = []
	for road_value: Variant in world_roads:
		var road: Array = road_value
		if road.size() < 2:
			continue
		if PROVINCE_IDS.has(str(road[0])) or PROVINCE_IDS.has(str(road[1])):
			continue
		result.append(road.duplicate(true))
	result.append_array(get_roads())
	result.append(["shandong", "pyongyang", "sea"])
	result.append(["shandong", "sabi", "sea"])
	result.append(["tsukushi", "geumseong", "sea"])
	result.append(["tsukushi", "sogaya", "sea"])
	return result


# 한국 35개 지역의 국경선 폴리곤 데이터입니다. map_area.gd의
# _build_region_borders()가 Korea35Data.REGION_BORDERS를 정적으로
# 참조하기 때문에, 실제 좌표 데이터가 아직 없어도 컴파일이 되려면 이
# 상수 자체는 있어야 합니다. 지금은 빈 상태라 한국 쪽 경계선은 안
# 그려지고, 나중에 각 지역별 [PackedVector2Array, ...] 링 좌표를
# 채워 넣으면 그때부터 국경선이 표시됩니다.
# 형식: { "province_id": [PackedVector2Array(...), ...] }
const REGION_BORDERS: Dictionary = {}
