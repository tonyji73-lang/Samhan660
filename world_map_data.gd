extends RefCounted

# 새 동아시아 지도에서 설정 화면과 실제 캠페인이 함께 쓰는 좌표·영지·도로 데이터입니다.
# 도시와 도로는 배경 그림에 포함하지 않고 코드로 그려 확대/이동 때도 같은 위치를 유지합니다.

const MAP_TEXTURE_PATH: String = "res://assets/maps/samhan660_east_asia_korea_center_6144x4096.png"
const MAP_TEXTURE_SIZE: Vector2 = Vector2(6144.0, 4096.0)
const TERRITORY_ID_MAP_PATH: String = "res://assets/maps/samhan660_territory_id_map_35.png"
const TERRITORY_PALETTE_SIZE: int = 64

# A 채널은 1~28 지역 번호, G 채널은 육지 경계입니다. 바다는 A=0입니다.
# 팔레트의 첫 줄은 면 색, 둘째 줄은 경계색으로 사용합니다.
const TERRITORY_SHADER_CODE: String = """
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D territory_palette : source_color, filter_nearest, repeat_disable;

void fragment() {
	ivec2 mask_size = textureSize(TEXTURE, 0);
	ivec2 mask_pixel = ivec2(
		clamp(UV, vec2(0.0), vec2(0.999999)) * vec2(mask_size)
	);
	vec4 territory_data = texelFetch(TEXTURE, mask_pixel, 0);
	if (territory_data.a < 0.001) {
		COLOR = vec4(0.0);
	} else {
		float region_index = floor(territory_data.a * 255.0 + 0.5);
		float palette_u = (region_index + 0.5) / 64.0;
		vec4 fill_color = texture(territory_palette, vec2(palette_u, 0.25));
		vec4 border_color = texture(territory_palette, vec2(palette_u, 0.75));
		float border_mask = step(0.5, territory_data.g);
		COLOR = mix(fill_color, border_color, border_mask);
	}
}
"""

const CORE_PROVINCE_IDS: Array[String] = [
	"ansi",
	"gungnae",
	"pyongyang",
	"ungjin",
	"sabi",
	"gosa",
	"gukwon",
	"sabeol",
	"geumseong",
]

const STEPPE_PROVINCE_IDS: Array[String] = [
	"steppe_sijie",
	"steppe_duolange",
	"steppe_huihe",
	"steppe_pugu",
	"steppe_bayegu",
	"steppe_adie",
	"steppe_qibi",
	"steppe_tongluo",
	"steppe_hun",
]

const PROVINCE_IDS: Array[String] = [
	"steppe_sijie",
	"steppe_duolange",
	"steppe_huihe",
	"steppe_pugu",
	"steppe_bayegu",
	"steppe_adie",
	"steppe_qibi",
	"steppe_tongluo",
	"steppe_hun",
	"changan",
	"luoyang",
	"shandong",
	"ansi",
	"gungnae",
	"pyongyang",
	"ungjin",
	"sabi",
	"gosa",
	"gukwon",
	"sabeol",
	"geumseong",
	"emishi_aguta",
	"koshi",
	"kibi",
	"naniwa",
	"asuka",
	"tsukushi",
	"hayato",
]

# Positions on samhan660_east_asia_korea_center_6144x4096.png.
const PROVINCE_MAP_UV: Dictionary = {
	"steppe_sijie": Vector2(0.095, 0.125),
	"steppe_duolange": Vector2(0.225, 0.105),
	"steppe_huihe": Vector2(0.350, 0.085),
	"steppe_pugu": Vector2(0.465, 0.110),
	"steppe_bayegu": Vector2(0.565, 0.145),
	"steppe_adie": Vector2(0.175, 0.245),
	"steppe_qibi": Vector2(0.300, 0.255),
	"steppe_tongluo": Vector2(0.420, 0.215),
	"steppe_hun": Vector2(0.120, 0.365),
	"changan": Vector2(0.080, 0.680),
	"luoyang": Vector2(0.185, 0.585),
	"shandong": Vector2(0.325, 0.495),
	"ansi": Vector2(0.480, 0.300),
	"gungnae": Vector2(0.535, 0.315),
	"pyongyang": Vector2(0.505, 0.430),
	"ungjin": Vector2(0.515, 0.585),
	# 백제 표식은 서해/제주 쪽으로 밀리지 않도록 실제 육지 안쪽에 둡니다.
	"sabi": Vector2(0.523, 0.626),
	"gosa": Vector2(0.510, 0.668),
	"gukwon": Vector2(0.555, 0.560),
	"sabeol": Vector2(0.565, 0.620),
	"geumseong": Vector2(0.585, 0.680),
	"emishi_aguta": Vector2(0.945, 0.350),
	"koshi": Vector2(0.845, 0.560),
	"kibi": Vector2(0.785, 0.650),
	"naniwa": Vector2(0.840, 0.660),
	"asuka": Vector2(0.845, 0.700),
	"tsukushi": Vector2(0.645, 0.750),
	"hayato": Vector2(0.680, 0.880),
}

# 지도 원본을 0.0~1.0 좌표로 나눈 게임용 영토 경계입니다.
# 실제 행정 경계를 정밀 복원한 GIS 자료가 아니라, 도시·산맥·해안선을 따라
# 플레이어가 세력권을 한눈에 구분할 수 있도록 만든 캠페인 폴리곤입니다.
const PROVINCE_POLYGONS: Dictionary = {
	"steppe_sijie":
	[
		Vector2(0.010, 0.035),
		Vector2(0.155, 0.025),
		Vector2(0.165, 0.145),
		Vector2(0.105, 0.195),
		Vector2(0.020, 0.175),
	],
	"steppe_duolange":
	[
		Vector2(0.155, 0.025),
		Vector2(0.285, 0.025),
		Vector2(0.295, 0.150),
		Vector2(0.235, 0.190),
		Vector2(0.165, 0.145),
	],
	"steppe_huihe":
	[
		Vector2(0.285, 0.025),
		Vector2(0.405, 0.020),
		Vector2(0.420, 0.145),
		Vector2(0.355, 0.175),
		Vector2(0.295, 0.150),
	],
	"steppe_pugu":
	[
		Vector2(0.405, 0.020),
		Vector2(0.515, 0.035),
		Vector2(0.530, 0.170),
		Vector2(0.470, 0.190),
		Vector2(0.420, 0.145),
	],
	"steppe_bayegu":
	[
		Vector2(0.515, 0.035),
		Vector2(0.625, 0.055),
		Vector2(0.635, 0.210),
		Vector2(0.560, 0.225),
		Vector2(0.530, 0.170),
	],
	"steppe_adie":
	[
		Vector2(0.020, 0.175),
		Vector2(0.105, 0.195),
		Vector2(0.165, 0.145),
		Vector2(0.235, 0.190),
		Vector2(0.245, 0.290),
		Vector2(0.175, 0.335),
		Vector2(0.055, 0.305),
	],
	"steppe_qibi":
	[
		Vector2(0.235, 0.190),
		Vector2(0.295, 0.150),
		Vector2(0.355, 0.175),
		Vector2(0.365, 0.295),
		Vector2(0.300, 0.340),
		Vector2(0.245, 0.290),
	],
	"steppe_tongluo":
	[
		Vector2(0.355, 0.175),
		Vector2(0.420, 0.145),
		Vector2(0.470, 0.190),
		Vector2(0.485, 0.275),
		Vector2(0.420, 0.330),
		Vector2(0.365, 0.295),
	],
	"steppe_hun":
	[
		Vector2(0.055, 0.305),
		Vector2(0.175, 0.335),
		Vector2(0.205, 0.445),
		Vector2(0.145, 0.525),
		Vector2(0.025, 0.505),
	],
	"changan":
	[
		Vector2(0.010, 0.505),
		Vector2(0.145, 0.525),
		Vector2(0.155, 0.640),
		Vector2(0.135, 0.785),
		Vector2(0.015, 0.830),
	],
	"luoyang":
	[
		Vector2(0.145, 0.525),
		Vector2(0.205, 0.445),
		Vector2(0.285, 0.455),
		Vector2(0.300, 0.570),
		Vector2(0.245, 0.665),
		Vector2(0.155, 0.640),
	],
	"shandong":
	[
		Vector2(0.260, 0.425),
		Vector2(0.355, 0.390),
		Vector2(0.430, 0.405),
		Vector2(0.450, 0.455),
		Vector2(0.415, 0.490),
		Vector2(0.350, 0.495),
		Vector2(0.300, 0.545),
		Vector2(0.260, 0.500),
	],
	"ansi":
	[
		Vector2(0.420, 0.225),
		Vector2(0.495, 0.220),
		Vector2(0.510, 0.320),
		Vector2(0.480, 0.375),
		Vector2(0.435, 0.350),
	],
	"gungnae":
	[
		Vector2(0.495, 0.220),
		Vector2(0.575, 0.245),
		Vector2(0.575, 0.355),
		Vector2(0.525, 0.395),
		Vector2(0.510, 0.320),
	],
	"pyongyang":
	[
		Vector2(0.480, 0.375),
		Vector2(0.525, 0.395),
		Vector2(0.550, 0.475),
		Vector2(0.530, 0.525),
		Vector2(0.485, 0.505),
		Vector2(0.455, 0.430),
	],
	"ungjin":
	[
		Vector2(0.485, 0.505),
		Vector2(0.530, 0.525),
		Vector2(0.540, 0.585),
		Vector2(0.520, 0.610),
		Vector2(0.485, 0.590),
		Vector2(0.465, 0.545),
	],
	"gukwon":
	[
		Vector2(0.530, 0.525),
		Vector2(0.585, 0.505),
		Vector2(0.600, 0.565),
		Vector2(0.575, 0.620),
		Vector2(0.540, 0.585),
	],
	"sabi":
	[
		Vector2(0.485, 0.590),
		Vector2(0.520, 0.610),
		Vector2(0.525, 0.655),
		Vector2(0.495, 0.675),
		Vector2(0.460, 0.635),
	],
	"gosa":
	[
		Vector2(0.460, 0.635),
		Vector2(0.495, 0.675),
		Vector2(0.525, 0.710),
		Vector2(0.495, 0.755),
		Vector2(0.445, 0.725),
		Vector2(0.435, 0.675),
	],
	"sabeol":
	[
		Vector2(0.520, 0.610),
		Vector2(0.575, 0.620),
		Vector2(0.600, 0.675),
		Vector2(0.565, 0.715),
		Vector2(0.525, 0.655),
	],
	"geumseong":
	[
		Vector2(0.525, 0.655),
		Vector2(0.575, 0.650),
		Vector2(0.600, 0.675),
		Vector2(0.625, 0.715),
		Vector2(0.605, 0.770),
		Vector2(0.545, 0.775),
		Vector2(0.495, 0.755),
		Vector2(0.525, 0.710),
	],
	"emishi_aguta":
	[
		Vector2(0.895, 0.195),
		Vector2(0.980, 0.220),
		Vector2(0.995, 0.400),
		Vector2(0.950, 0.475),
		Vector2(0.900, 0.410),
	],
	"koshi":
	[
		Vector2(0.870, 0.420),
		Vector2(0.920, 0.430),
		Vector2(0.950, 0.480),
		Vector2(0.920, 0.550),
		Vector2(0.880, 0.610),
		Vector2(0.840, 0.635),
		Vector2(0.820, 0.580),
		Vector2(0.850, 0.520),
	],
	"kibi":
	[
		Vector2(0.730, 0.600),
		Vector2(0.780, 0.590),
		Vector2(0.820, 0.620),
		Vector2(0.810, 0.670),
		Vector2(0.770, 0.705),
		Vector2(0.720, 0.680),
	],
	"naniwa":
	[
		Vector2(0.810, 0.620),
		Vector2(0.850, 0.620),
		Vector2(0.870, 0.660),
		Vector2(0.860, 0.700),
		Vector2(0.830, 0.720),
		Vector2(0.810, 0.670),
	],
	"asuka":
	[
		Vector2(0.810, 0.670),
		Vector2(0.845, 0.665),
		Vector2(0.870, 0.690),
		Vector2(0.880, 0.750),
		Vector2(0.850, 0.790),
		Vector2(0.810, 0.760),
		Vector2(0.790, 0.720),
	],
	"tsukushi":
	[
		Vector2(0.660, 0.680),
		Vector2(0.710, 0.690),
		Vector2(0.750, 0.730),
		Vector2(0.740, 0.790),
		Vector2(0.700, 0.840),
		Vector2(0.660, 0.810),
		Vector2(0.640, 0.750),
	],
	"hayato":
	[
		Vector2(0.660, 0.810),
		Vector2(0.700, 0.840),
		Vector2(0.740, 0.790),
		Vector2(0.760, 0.880),
		Vector2(0.730, 0.940),
		Vector2(0.680, 0.950),
		Vector2(0.640, 0.890),
	],
}

const PROVINCE_NAMES: Dictionary = {
	"steppe_sijie": "알타이 동록",
	"steppe_duolange": "항가이",
	"steppe_huihe": "셀렝게",
	"steppe_pugu": "오논",
	"steppe_bayegu": "케룰렌",
	"steppe_adie": "고비 북연",
	"steppe_qibi": "툴강 남안",
	"steppe_tongluo": "툴강 북안",
	"steppe_hun": "고비 남록",
	"changan": "장안",
	"luoyang": "낙양",
	"shandong": "산동항",
	"ansi": "안시성",
	"gungnae": "국내성",
	"pyongyang": "평양성",
	"ungjin": "웅진성",
	"sabi": "사비성",
	"gosa": "고사성",
	"gukwon": "국원소경",
	"sabeol": "사벌주",
	"geumseong": "금성",
	"emishi_aguta": "아기타",
	"koshi": "고시",
	"kibi": "기비",
	"naniwa": "나니와",
	"asuka": "아스카",
	"tsukushi": "쓰쿠시",
	"hayato": "하야토령",
}

const CITY_BUTTON_NAMES: Dictionary = {
	"steppe_sijie": "SteppeSijieButton",
	"steppe_duolange": "SteppeDuolangeButton",
	"steppe_huihe": "SteppeHuiheButton",
	"steppe_pugu": "SteppePuguButton",
	"steppe_bayegu": "SteppeBayeguButton",
	"steppe_adie": "SteppeAdieButton",
	"steppe_qibi": "SteppeQibiButton",
	"steppe_tongluo": "SteppeTongluoButton",
	"steppe_hun": "SteppeHunButton",
	"changan": "ChanganButton",
	"luoyang": "LuoyangButton",
	"shandong": "ShandongButton",
	"ansi": "AnsiButton",
	"gungnae": "GungnaeButton",
	"pyongyang": "PyongyangButton",
	"ungjin": "UngjinButton",
	"sabi": "SabiButton",
	"gosa": "GosaButton",
	"gukwon": "GukwonButton",
	"sabeol": "SabeolButton",
	"geumseong": "GeumseongButton",
	"emishi_aguta": "EmishiAgutaButton",
	"koshi": "KoshiButton",
	"kibi": "KibiButton",
	"naniwa": "NaniwaButton",
	"asuka": "AsukaButton",
	"tsukushi": "TsukushiButton",
	"hayato": "HayatoButton",
}

const FACTION_COLORS: Dictionary = {
	"고구려": Color("#3d5f86"),
	"백제": Color("#a64035"),
	"신라": Color("#d2a43b"),
	"가야": Color("#416b4a"),
	"탐라": Color("#654a78"),
	"백제부흥군": Color("#8f342f"),
	"고구려부흥군": Color("#516f91"),
	"당": Color("#556b45"),
	"설연타": Color("#6d6246"),
	"회흘(위구르)": Color("#7a6a43"),
	"복골": Color("#826447"),
	"동라": Color("#5f7555"),
	"발야고": Color("#6a7350"),
	"사결": Color("#75614f"),
	"계필": Color("#8a744d"),
	"혼": Color("#665b53"),
	"다람갈": Color("#7c684c"),
	"아질": Color("#6f694a"),
	"왜(야마토 조정)": Color("#7b4f84"),
	"왜(야마토)": Color("#7b4f84"),
	"쓰쿠시 해상세력": Color("#326c78"),
	"기비 호족연합": Color("#8b6038"),
	"고시 아베 수군": Color("#4c6b86"),
	"고시 호족권": Color("#4c6b86"),
	"에미시 연맹": Color("#6b5143"),
	"하야토 부족연맹": Color("#77543b"),
}

const DEFAULT_GENERAL_NAMES: Dictionary = {
	"steppe_sijie": "사결 수장",
	"steppe_duolange": "다람갈 수장",
	"steppe_huihe": "포룬 일테베르",
	"steppe_pugu": "복골 수장",
	"steppe_bayegu": "발야고 수장",
	"steppe_adie": "아질 수장",
	"steppe_qibi": "계필 수장",
	"steppe_tongluo": "동라 수장",
	"steppe_hun": "혼 수장",
	"changan": "당 고종",
	"luoyang": "소정방",
	"shandong": "유인궤",
	"ansi": "양만춘",
	"gungnae": "고연무",
	"pyongyang": "연개소문",
	"ungjin": "흑치상지",
	"sabi": "의자왕",
	"gosa": "부여태",
	"gukwon": "김법민",
	"sabeol": "품일",
	"geumseong": "김춘추",
	"emishi_aguta": "온가",
	"koshi": "아베노 히라후",
	"kibi": "기비 수장 미상",
	"naniwa": "나카노오에 황자",
	"asuka": "사이메이 천황",
	"tsukushi": "아즈미노 히라후",
	"hayato": "하야토 수장 미상",
}

const MAP_ROADS: Array = [
	["steppe_sijie", "steppe_duolange"],
	["steppe_duolange", "steppe_huihe"],
	["steppe_huihe", "steppe_pugu"],
	["steppe_pugu", "steppe_bayegu"],
	["steppe_duolange", "steppe_adie"],
	["steppe_duolange", "steppe_qibi"],
	["steppe_huihe", "steppe_qibi"],
	["steppe_huihe", "steppe_tongluo"],
	["steppe_duolange", "steppe_tongluo"],
	["steppe_tongluo", "steppe_pugu"],
	["steppe_sijie", "steppe_adie"],
	["steppe_adie", "steppe_qibi"],
	["steppe_qibi", "steppe_tongluo"],
	["steppe_adie", "steppe_hun"],
	["changan", "luoyang"],
	["luoyang", "shandong"],
	["shandong", "pyongyang", "sea"],
	["shandong", "sabi", "sea"],
	["ansi", "gungnae"],
	["gungnae", "pyongyang"],
	["pyongyang", "ungjin"],
	["pyongyang", "gukwon"],
	["ungjin", "sabi"],
	["ungjin", "gukwon"],
	["sabi", "gosa"],
	["sabi", "geumseong"],
	["gosa", "geumseong"],
	["gukwon", "sabeol"],
	["sabeol", "geumseong"],
	["emishi_aguta", "koshi"],
	["koshi", "kibi"],
	["kibi", "naniwa"],
	["naniwa", "asuka"],
	["kibi", "tsukushi"],
	["tsukushi", "hayato"],
	["tsukushi", "geumseong", "sea"],
	["tsukushi", "gosa", "sea"],
]

# 지도상 즉시 인접 전투로 취급하지 않는 장거리 원정로입니다.
# 몽골 고원에서 당 본토나 고구려로 한 턴에 순간이동하는 현상을 막기 위해
# 일반 MAP_ROADS에서 분리했습니다. 향후 원정군 시스템은 이 자료의 이동비용을
# 여러 턴에 걸쳐 소모한 뒤 목적지에 도착하도록 사용합니다.
const STRATEGIC_ROUTES: Array = [
	["steppe_hun", "changan", "frontier"],
]

# 모든 노선에 중간점을 두어 직선 대신 지형을 따라 휘는 길로 보이게 합니다.
const ROAD_WAYPOINTS: Dictionary = {
	"steppe_sijie_steppe_duolange": [Vector2(0.145, 0.105), Vector2(0.185, 0.135)],
	"steppe_duolange_steppe_huihe": [Vector2(0.265, 0.080), Vector2(0.315, 0.105)],
	"steppe_huihe_steppe_pugu": [Vector2(0.385, 0.120), Vector2(0.425, 0.090)],
	"steppe_pugu_steppe_bayegu": [Vector2(0.500, 0.145), Vector2(0.535, 0.120)],
	"steppe_duolange_steppe_adie": [Vector2(0.205, 0.155), Vector2(0.190, 0.210)],
	"steppe_duolange_steppe_qibi": [Vector2(0.250, 0.165), Vector2(0.275, 0.215)],
	"steppe_huihe_steppe_qibi": [Vector2(0.325, 0.145), Vector2(0.315, 0.205)],
	"steppe_huihe_steppe_tongluo": [Vector2(0.375, 0.150), Vector2(0.395, 0.190)],
	"steppe_duolange_steppe_tongluo": [Vector2(0.285, 0.155), Vector2(0.355, 0.180)],
	"steppe_tongluo_steppe_pugu": [Vector2(0.445, 0.170), Vector2(0.470, 0.155)],
	"steppe_sijie_steppe_adie": [Vector2(0.105, 0.180), Vector2(0.150, 0.205)],
	"steppe_adie_steppe_qibi": [Vector2(0.215, 0.275), Vector2(0.255, 0.230)],
	"steppe_qibi_steppe_tongluo": [Vector2(0.335, 0.215), Vector2(0.375, 0.245)],
	"steppe_adie_steppe_hun": [Vector2(0.145, 0.285), Vector2(0.155, 0.325)],
	"steppe_hun_changan": [Vector2(0.090, 0.435), Vector2(0.105, 0.500), Vector2(0.115, 0.560)],
	"changan_luoyang": [Vector2(0.110, 0.635), Vector2(0.150, 0.600)],
	"luoyang_shandong": [Vector2(0.225, 0.550), Vector2(0.275, 0.520)],
	"shandong_pyongyang": [Vector2(0.365, 0.500), Vector2(0.420, 0.470), Vector2(0.470, 0.450)],
	"shandong_sabi": [Vector2(0.367, 0.484), Vector2(0.409, 0.497), Vector2(0.451, 0.549)],
	"ansi_gungnae": [Vector2(0.495, 0.285), Vector2(0.515, 0.325)],
	"gungnae_pyongyang": [Vector2(0.520, 0.355), Vector2(0.510, 0.395)],
	"pyongyang_ungjin": [Vector2(0.490, 0.480), Vector2(0.520, 0.535)],
	"pyongyang_gukwon": [Vector2(0.530, 0.475), Vector2(0.545, 0.520)],
	"ungjin_sabi": [Vector2(0.500, 0.605), Vector2(0.515, 0.615)],
	"ungjin_gukwon": [Vector2(0.535, 0.570), Vector2(0.550, 0.580)],
	"sabi_gosa": [Vector2(0.490, 0.650), Vector2(0.500, 0.675)],
	"sabi_geumseong": [Vector2(0.525, 0.650), Vector2(0.555, 0.670)],
	"gosa_geumseong": [Vector2(0.510, 0.710), Vector2(0.550, 0.690)],
	"gukwon_sabeol": [Vector2(0.550, 0.590), Vector2(0.570, 0.600)],
	"sabeol_geumseong": [Vector2(0.580, 0.640), Vector2(0.570, 0.670)],
	"emishi_aguta_koshi": [Vector2(0.925, 0.420), Vector2(0.880, 0.500)],
	"koshi_kibi": [Vector2(0.830, 0.585), Vector2(0.805, 0.620)],
	"kibi_naniwa": [Vector2(0.800, 0.665), Vector2(0.825, 0.645)],
	"naniwa_asuka": [Vector2(0.850, 0.675), Vector2(0.835, 0.690)],
	"kibi_tsukushi": [Vector2(0.745, 0.680), Vector2(0.690, 0.720)],
	"tsukushi_hayato": [Vector2(0.640, 0.805), Vector2(0.680, 0.850)],
	"tsukushi_geumseong": [Vector2(0.625, 0.735), Vector2(0.605, 0.705)],
	"tsukushi_gosa": [Vector2(0.610, 0.730), Vector2(0.550, 0.705)],
}

# 이동비용은 '지역 하나 = 무조건 한 턴'이 아니라 지형과 거리의 차이를
# 표현하기 위한 값입니다. 현재 캠페인은 MAP_ROADS만 즉시 인접지로 사용하고,
# 다음 원정군 단계에서 movement_cost를 장수 이동력과 비교해 ETA를 계산합니다.
const ROUTE_RULES: Dictionary = {
	"steppe_sijie_steppe_duolange":
	{"terrain": "altai_pass", "movement_cost": 95, "label": "알타이 산록로"},
	"steppe_duolange_steppe_huihe":
	{"terrain": "river_grassland", "movement_cost": 55, "label": "오르혼·셀렝게 초원로"},
	"steppe_huihe_steppe_pugu":
	{"terrain": "forest_steppe", "movement_cost": 70, "label": "셀렝게·오논 회랑"},
	"steppe_pugu_steppe_bayegu":
	{"terrain": "river_grassland", "movement_cost": 60, "label": "오논·케룰렌 초원로"},
	"steppe_duolange_steppe_adie":
	{"terrain": "khangai_pass", "movement_cost": 90, "label": "항가이 남부 고개"},
	"steppe_duolange_steppe_qibi":
	{"terrain": "river_grassland", "movement_cost": 60, "label": "항가이·툴강 회랑"},
	"steppe_huihe_steppe_qibi":
	{"terrain": "river_grassland", "movement_cost": 55, "label": "셀렝게·툴강 회랑"},
	"steppe_huihe_steppe_tongluo":
	{"terrain": "river_grassland", "movement_cost": 55, "label": "셀렝게·툴강 북로"},
	"steppe_duolange_steppe_tongluo":
	{"terrain": "open_steppe", "movement_cost": 65, "label": "항가이 동부 초원로"},
	"steppe_tongluo_steppe_pugu":
	{"terrain": "open_steppe", "movement_cost": 60, "label": "툴강·오논 초원로"},
	"steppe_sijie_steppe_adie":
	{"terrain": "dry_steppe", "movement_cost": 85, "label": "알타이·고비 북서로"},
	"steppe_adie_steppe_qibi": {"terrain": "gobi_edge", "movement_cost": 100, "label": "고비 북연로"},
	"steppe_qibi_steppe_tongluo":
	{"terrain": "river_grassland", "movement_cost": 50, "label": "툴강 도하로"},
	"steppe_adie_steppe_hun": {"terrain": "gobi", "movement_cost": 130, "label": "고비 종단로"},
	"steppe_hun_changan":
	{
		"terrain": "long_frontier",
		"movement_cost": 320,
		"label": "고비 남로·당 변경 원정로",
		"strategic_only": true
	},
}

const STEPPE_TERRAIN_RULES: Dictionary = {
	"steppe_sijie": {"terrain": "altai", "winter_modifier": 1.45, "pasture": 62},
	"steppe_duolange": {"terrain": "khangai", "winter_modifier": 1.35, "pasture": 78},
	"steppe_huihe": {"terrain": "selenge_valley", "winter_modifier": 1.25, "pasture": 90},
	"steppe_pugu": {"terrain": "onon_forest_steppe", "winter_modifier": 1.30, "pasture": 82},
	"steppe_bayegu": {"terrain": "kherlen_grassland", "winter_modifier": 1.25, "pasture": 84},
	"steppe_adie":
	{"terrain": "north_gobi", "winter_modifier": 1.30, "summer_modifier": 1.20, "pasture": 42},
	"steppe_qibi": {"terrain": "tuul_south", "winter_modifier": 1.25, "pasture": 74},
	"steppe_tongluo": {"terrain": "tuul_north", "winter_modifier": 1.25, "pasture": 80},
	"steppe_hun":
	{"terrain": "south_gobi", "winter_modifier": 1.25, "summer_modifier": 1.35, "pasture": 34},
}

const PROVINCE_TEMPLATES: Dictionary = {
	"steppe_sijie":
	{
		"name": "알타이 동록",
		"faction": "사결",
		"governor": "사결 수장",
		"population": 36000,
		"agriculture": 30,
		"commerce": 36,
		"public_order": 72,
		"troops": 13000,
		"fortress": 42,
		"terrain": "altai",
		"pasture": 62,
		"overlord": "당",
		"submission": 58
	},
	"steppe_duolange":
	{
		"name": "항가이",
		"faction": "다람갈",
		"governor": "다람갈 수장",
		"population": 42000,
		"agriculture": 32,
		"commerce": 38,
		"public_order": 70,
		"troops": 15000,
		"fortress": 44,
		"terrain": "khangai",
		"pasture": 78,
		"overlord": "당",
		"submission": 54
	},
	"steppe_huihe":
	{
		"name": "셀렝게",
		"faction": "회흘(위구르)",
		"governor": "포룬 일테베르",
		"population": 52000,
		"agriculture": 35,
		"commerce": 44,
		"public_order": 78,
		"troops": 18000,
		"fortress": 48,
		"terrain": "selenge_valley",
		"pasture": 90,
		"overlord": "당",
		"submission": 76
	},
	"steppe_pugu":
	{
		"name": "오논",
		"faction": "복골",
		"governor": "복골 수장",
		"population": 40000,
		"agriculture": 31,
		"commerce": 36,
		"public_order": 71,
		"troops": 15000,
		"fortress": 43,
		"terrain": "onon_forest_steppe",
		"pasture": 82,
		"overlord": "당",
		"submission": 48
	},
	"steppe_bayegu":
	{
		"name": "케룰렌",
		"faction": "발야고",
		"governor": "발야고 수장",
		"population": 39000,
		"agriculture": 30,
		"commerce": 35,
		"public_order": 73,
		"troops": 14500,
		"fortress": 42,
		"terrain": "kherlen_grassland",
		"pasture": 84,
		"overlord": "당",
		"submission": 46
	},
	"steppe_adie":
	{
		"name": "고비 북연",
		"faction": "아질",
		"governor": "아질 수장",
		"population": 32000,
		"agriculture": 25,
		"commerce": 34,
		"public_order": 68,
		"troops": 12000,
		"fortress": 38,
		"terrain": "north_gobi",
		"pasture": 42,
		"overlord": "당",
		"submission": 62
	},
	"steppe_qibi":
	{
		"name": "툴강 남안",
		"faction": "계필",
		"governor": "계필 수장",
		"population": 37000,
		"agriculture": 28,
		"commerce": 39,
		"public_order": 74,
		"troops": 14000,
		"fortress": 40,
		"terrain": "tuul_south",
		"pasture": 74,
		"overlord": "당",
		"submission": 82
	},
	"steppe_tongluo":
	{
		"name": "툴강 북안",
		"faction": "동라",
		"governor": "동라 수장",
		"population": 41000,
		"agriculture": 32,
		"commerce": 40,
		"public_order": 70,
		"troops": 15500,
		"fortress": 42,
		"terrain": "tuul_north",
		"pasture": 80,
		"overlord": "당",
		"submission": 44
	},
	"steppe_hun":
	{
		"name": "고비 남록",
		"faction": "혼",
		"governor": "혼 수장",
		"population": 35000,
		"agriculture": 27,
		"commerce": 42,
		"public_order": 69,
		"troops": 12500,
		"fortress": 38,
		"terrain": "south_gobi",
		"pasture": 34,
		"overlord": "당",
		"submission": 70
	},
	"changan":
	{
		"name": "장안",
		"faction": "당",
		"governor": "당 고종",
		"population": 620000,
		"agriculture": 88,
		"commerce": 96,
		"public_order": 88,
		"troops": 52000,
		"fortress": 92
	},
	"luoyang":
	{
		"name": "낙양",
		"faction": "당",
		"governor": "소정방",
		"population": 510000,
		"agriculture": 86,
		"commerce": 94,
		"public_order": 84,
		"troops": 44000,
		"fortress": 88
	},
	"shandong":
	{
		"name": "산동항",
		"faction": "당",
		"governor": "유인궤",
		"population": 270000,
		"agriculture": 78,
		"commerce": 90,
		"public_order": 82,
		"troops": 39000,
		"fortress": 75
	},
	"ansi":
	{
		"name": "안시성",
		"faction": "고구려",
		"governor": "양만춘",
		"population": 150000,
		"agriculture": 60,
		"commerce": 55,
		"public_order": 85,
		"troops": 40000,
		"fortress": 95
	},
	"gungnae":
	{
		"name": "국내성",
		"faction": "고구려",
		"governor": "고연무",
		"population": 130000,
		"agriculture": 65,
		"commerce": 60,
		"public_order": 80,
		"troops": 25000,
		"fortress": 85
	},
	"pyongyang":
	{
		"name": "평양성",
		"faction": "고구려",
		"governor": "연개소문",
		"population": 180000,
		"agriculture": 72,
		"commerce": 65,
		"public_order": 70,
		"troops": 35000,
		"fortress": 85
	},
	"ungjin":
	{
		"name": "웅진성",
		"faction": "백제",
		"governor": "흑치상지",
		"population": 110000,
		"agriculture": 68,
		"commerce": 62,
		"public_order": 65,
		"troops": 20000,
		"fortress": 80
	},
	"sabi":
	{
		"name": "사비성",
		"faction": "백제",
		"governor": "의자왕",
		"population": 140000,
		"agriculture": 68,
		"commerce": 75,
		"public_order": 48,
		"troops": 22000,
		"fortress": 72
	},
	"gosa":
	{
		"name": "고사성",
		"faction": "백제",
		"governor": "부여태",
		"population": 90000,
		"agriculture": 55,
		"commerce": 50,
		"public_order": 60,
		"troops": 15000,
		"fortress": 65
	},
	"gukwon":
	{
		"name": "국원소경",
		"faction": "신라",
		"governor": "김법민",
		"population": 100000,
		"agriculture": 65,
		"commerce": 70,
		"public_order": 80,
		"troops": 18000,
		"fortress": 70
	},
	"sabeol":
	{
		"name": "사벌주",
		"faction": "신라",
		"governor": "품일",
		"population": 115000,
		"agriculture": 70,
		"commerce": 60,
		"public_order": 75,
		"troops": 20000,
		"fortress": 68
	},
	"geumseong":
	{
		"name": "금성",
		"faction": "신라",
		"governor": "김춘추",
		"population": 120000,
		"agriculture": 74,
		"commerce": 61,
		"public_order": 78,
		"troops": 28000,
		"fortress": 76
	},
	"emishi_aguta":
	{
		"name": "아기타",
		"faction": "에미시 연맹",
		"governor": "온가",
		"population": 42000,
		"agriculture": 42,
		"commerce": 46,
		"public_order": 74,
		"troops": 13500,
		"fortress": 45
	},
	"koshi":
	{
		"name": "고시",
		"faction": "고시 아베 수군",
		"governor": "아베노 히라후",
		"population": 96000,
		"agriculture": 61,
		"commerce": 73,
		"public_order": 78,
		"troops": 18000,
		"fortress": 61
	},
	"kibi":
	{
		"name": "기비",
		"faction": "기비 호족연합",
		"governor": "기비 수장 미상",
		"population": 155000,
		"agriculture": 72,
		"commerce": 78,
		"public_order": 76,
		"troops": 21000,
		"fortress": 66
	},
	"naniwa":
	{
		"name": "나니와",
		"faction": "왜(야마토 조정)",
		"governor": "나카노오에 황자",
		"population": 190000,
		"agriculture": 74,
		"commerce": 88,
		"public_order": 80,
		"troops": 22000,
		"fortress": 70
	},
	"asuka":
	{
		"name": "아스카",
		"faction": "왜(야마토 조정)",
		"governor": "사이메이 천황",
		"population": 210000,
		"agriculture": 78,
		"commerce": 82,
		"public_order": 82,
		"troops": 26000,
		"fortress": 74
	},
	"tsukushi":
	{
		"name": "쓰쿠시",
		"faction": "쓰쿠시 해상세력",
		"governor": "아즈미노 히라후",
		"population": 130000,
		"agriculture": 68,
		"commerce": 84,
		"public_order": 75,
		"troops": 23000,
		"fortress": 64
	},
	"hayato":
	{
		"name": "하야토령",
		"faction": "하야토 부족연맹",
		"governor": "하야토 수장 미상",
		"population": 70000,
		"agriculture": 54,
		"commerce": 52,
		"public_order": 70,
		"troops": 16000,
		"fortress": 52
	},
}


static func get_province_templates() -> Dictionary:
	return PROVINCE_TEMPLATES.duplicate(true)


static func get_scenario_provinces(year: int, scenario_overrides: Dictionary = {}) -> Dictionary:
	var result: Dictionary = get_province_templates()
	_apply_province_overrides(result, get_world_overrides(year))
	_apply_province_overrides(result, scenario_overrides)
	return result


static func _apply_province_overrides(province_data: Dictionary, overrides: Dictionary) -> void:
	for province_id_value: Variant in overrides.keys():
		var province_id: String = str(province_id_value)
		if not province_data.has(province_id):
			continue
		var updated_province: Dictionary = province_data[province_id].duplicate(true)
		var province_override: Dictionary = overrides[province_id]
		for key_value: Variant in province_override.keys():
			updated_province[key_value] = province_override[key_value]
		province_data[province_id] = updated_province


static func get_route_key(from_id: String, to_id: String) -> String:
	var direct_key: String = "%s_%s" % [from_id, to_id]
	if ROUTE_RULES.has(direct_key):
		return direct_key
	var reverse_key: String = "%s_%s" % [to_id, from_id]
	if ROUTE_RULES.has(reverse_key):
		return reverse_key
	return direct_key


static func get_route_rule(from_id: String, to_id: String) -> Dictionary:
	var route_key: String = get_route_key(from_id, to_id)
	if ROUTE_RULES.has(route_key):
		return ROUTE_RULES[route_key].duplicate(true)
	return {
		"terrain": "road",
		"movement_cost": 70,
		"label": "일반 도로",
	}


# campaign_main.gd의 출정 군량 계산에서 사용하는 노선별 배율입니다.
# 별도 food_rate가 있으면 우선 사용하고, 없으면 이동 난이도와 해로 여부로 계산합니다.
static func get_route_food_rate(from_id: String, to_id: String) -> float:
	var rule: Dictionary = get_route_rule(from_id, to_id)
	if rule.has("food_rate"):
		return maxf(0.50, float(rule["food_rate"]))

	var movement_cost: float = float(rule.get("movement_cost", 70))
	var food_rate: float = clampf(movement_cost / 70.0, 0.75, 4.50)

	for road_value: Variant in MAP_ROADS:
		var road: Array = road_value
		if road.size() < 3 or str(road[2]) != "sea":
			continue
		var road_from: String = str(road[0])
		var road_to: String = str(road[1])
		if (
			(road_from == from_id and road_to == to_id)
			or (road_from == to_id and road_to == from_id)
		):
			food_rate = maxf(food_rate, 1.35)
			break

	return food_rate


static func get_route_travel_turns(
	from_id: String,
	to_id: String,
	leadership: int = 70,
	intelligence: int = 70,
	is_nomad_cavalry: bool = false,
	season: int = 0
) -> int:
	var rule: Dictionary = get_route_rule(from_id, to_id)
	var movement_cost: float = float(rule.get("movement_cost", 70))
	var terrain: String = str(rule.get("terrain", "road"))
	var movement_points: float = 58.0 + float(leadership) * 0.32
	movement_points += float(intelligence) * 0.12
	if (
		is_nomad_cavalry
		and (
			terrain.contains("steppe") or terrain.contains("grassland") or terrain.contains("river")
		)
	):
		movement_points *= 1.30
	if terrain in ["gobi", "gobi_edge", "long_frontier"]:
		movement_points *= 0.82
	if (
		season == 3
		and (
			terrain.contains("steppe")
			or terrain.contains("grassland")
			or terrain.contains("river")
			or terrain.contains("pass")
		)
	):
		movement_cost *= 1.35
	if season == 1 and terrain in ["gobi", "gobi_edge", "long_frontier"]:
		movement_cost *= 1.25
	return maxi(1, int(ceil(movement_cost / movement_points)))


static func get_steppe_diplomacy(year: int) -> Dictionary:
	var result: Dictionary = {}
	for province_id: String in STEPPE_PROVINCE_IDS:
		result[province_id] = {
			"overlord": "당" if year >= 647 else "",
			"submission":
			0 if year < 647 else int(PROVINCE_TEMPLATES[province_id].get("submission", 60)),
			"status": "설연타 연맹권" if year < 647 else "당 기미부주",
		}
	if year >= 661 and year <= 662:
		for rebel_id: String in [
			"steppe_sijie",
			"steppe_bayegu",
			"steppe_pugu",
			"steppe_tongluo",
		]:
			result[rebel_id]["status"] = "철륵 반란군"
			result[rebel_id]["submission"] = 18
	if year >= 663:
		result["steppe_huihe"]["status"] = "반란 진압 뒤 재편"
		result["steppe_huihe"]["submission"] = 58
	return result


static func get_connections() -> Dictionary:
	var result: Dictionary = {}
	for province_id: String in PROVINCE_IDS:
		result[province_id] = []
	for road_value: Variant in MAP_ROADS:
		var road: Array = road_value
		if road.size() < 2:
			continue
		var from_id: String = str(road[0])
		var to_id: String = str(road[1])
		if result.has(from_id) and not result[from_id].has(to_id):
			result[from_id].append(to_id)
		if result.has(to_id) and not result[to_id].has(from_id):
			result[to_id].append(from_id)
	return result


static func get_world_overrides(year: int) -> Dictionary:
	var tang_ruler: String = "당 태종" if year < 650 else "당 고종"
	var tang_commander: String = "이세적" if year < 650 else "소정방"
	if year >= 663:
		tang_commander = "유인궤" if year < 670 else "고간"

	var yamato_ruler: String = "조메이 천황"
	var yamato_commander: String = "소가노 에미시"
	if year >= 642:
		yamato_ruler = "고교쿠 천황"
		yamato_commander = "소가노 이루카"
	if year >= 655:
		yamato_ruler = "사이메이 천황"
		yamato_commander = "나카노오에 황자"
	if year >= 663:
		yamato_ruler = "나카노오에 황자"
		yamato_commander = "아베노 히라후"
	if year >= 668:
		yamato_ruler = "덴지 천황"
		yamato_commander = "오토모노 후케이"

	var result: Dictionary = {
		"changan": {"faction": "당", "governor": tang_ruler},
		"luoyang": {"faction": "당", "governor": tang_commander},
		"shandong": {"faction": "당", "governor": "유인궤" if year >= 660 else "이세적"},
		"asuka": {"faction": "왜(야마토 조정)" if year >= 660 else "왜(야마토)", "governor": yamato_ruler},
		"naniwa":
		{"faction": "왜(야마토 조정)" if year >= 660 else "왜(야마토)", "governor": yamato_commander},
	}

	var emishi_governor: String = "온가" if year >= 658 else "에미시 수장 미상"
	var abe_active: bool = year >= 658 and year <= 664
	var koshi_faction: String = "고시 아베 수군" if abe_active else "고시 호족권"
	var koshi_governor: String = "아베노 히라후" if abe_active else "고시 수장 미상"
	var tsukushi_governor: String = "아즈미노 히라후" if year >= 660 and year <= 663 else "쓰쿠시 수장 미상"
	result["emishi_aguta"] = {
		"faction": "에미시 연맹",
		"governor": emishi_governor,
	}
	result["koshi"] = {
		"faction": koshi_faction,
		"governor": koshi_governor,
	}
	result["kibi"] = {
		"faction": "기비 호족연합",
		"governor": "기비 수장 미상",
	}
	result["tsukushi"] = {
		"faction": "쓰쿠시 해상세력",
		"governor": tsukushi_governor,
	}
	result["hayato"] = {
		"faction": "하야토 부족연맹",
		"governor": "하야토 수장 미상",
	}

	var huihe_governor: String = "포룬 일테베르"
	if year >= 661 and year < 680:
		huihe_governor = "비속독 일테베르"
	elif year >= 680:
		huihe_governor = "독해지 일테베르"

	var steppe_factions: Dictionary = {
		"steppe_sijie": ["사결", "사결 수장"],
		"steppe_duolange": ["다람갈", "다람갈 수장"],
		"steppe_huihe": ["회흘(위구르)", huihe_governor],
		"steppe_pugu": ["복골", "복골 수장"],
		"steppe_bayegu": ["발야고", "발야고 수장"],
		"steppe_adie": ["아질", "아질 수장"],
		"steppe_qibi": ["계필", "계필 수장"],
		"steppe_tongluo": ["동라", "동라 수장"],
		"steppe_hun": ["혼", "혼 수장"],
	}
	var steppe_diplomacy: Dictionary = get_steppe_diplomacy(year)
	if year < 647:
		for province_id: String in steppe_factions.keys():
			result[province_id] = {
				"faction": "설연타",
				"governor": steppe_factions[province_id][1],
				"overlord": "",
				"submission": 0,
				"diplomatic_status": "설연타 연맹권",
			}
		result["steppe_duolange"]["name"] = "외튀켄"
		result["steppe_duolange"]["governor"] = "이남"
	else:
		for province_id: String in steppe_factions.keys():
			result[province_id] = {
				"faction": steppe_factions[province_id][0],
				"governor": steppe_factions[province_id][1],
				"overlord": steppe_diplomacy[province_id]["overlord"],
				"submission": steppe_diplomacy[province_id]["submission"],
				"diplomatic_status": steppe_diplomacy[province_id]["status"],
			}
	return result


static func get_world_officer_assignments(year: int) -> Dictionary:
	var overrides: Dictionary = get_world_overrides(year)
	var result: Dictionary = {}
	for province_id_value: Variant in overrides.keys():
		var province_id: String = str(province_id_value)
		var governor: String = str(overrides[province_id].get("governor", ""))
		result[province_id] = [] if governor == "" else [governor]
	return result
