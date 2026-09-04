extends RefCounted

const WorldMapData = preload("res://world_map_data.gd")

# 새 게임 설정 화면과 실제 캠페인이 함께 읽는 단일 시나리오 데이터입니다.
# 사용자가 정리한 생몰년 입력표의 최종값을 게임용 대표 연도로 사용합니다.
# 사료로 확정되지 않은 값도 있으므로 화면에서는 나이를 항상 "약 n세"로 표시합니다.
# 새 주변 세력 인물처럼 출생 연도가 아직 없는 경우만 0으로 둡니다.

const DEFAULT_SCENARIO_ID: String = "baekje_fall_660"

# 세력 선택 화면은 이 정적 역사 데이터만 사용합니다.
# 캠페인 중 자동 생성되거나 가문에서 성장한 인물은 능력치와 관계없이 이 목록에 들어올 수 없습니다.
const SIGNATURE_UNIT_NAMES: Dictionary = {
	"silla": ["서당 정예군", "낭도 기병"],
	"baekje": ["백제 결사대", "백제 정예수군"],
	"goguryeo": ["개마무사", "산성 수비군"],
	"tang": ["현갑 정예기병", "당 원정수군"],
	"yamato": ["야마토 원정수군"],
	"xueyantuo": ["초원 정예기병"],
	"huihe": ["초원 정예기병"],
}

const OFFICERS: Dictionary = {
	"선덕여왕":
	{
		"name": "선덕여왕",
		"birth_year": 586,
		"death_year": 647,
		"leadership": 76,
		"war": 48,
		"intelligence": 91,
		"politics": 93,
		"authority": 94
	},
	"알천":
	{
		"name": "알천",
		"birth_year": 577,
		"death_year": 686,
		"leadership": 86,
		"war": 84,
		"intelligence": 76,
		"politics": 78,
		"authority": 85
	},
	"김춘추":
	{
		"name": "김춘추",
		"birth_year": 603,
		"death_year": 661,
		"leadership": 75,
		"war": 60,
		"intelligence": 95,
		"politics": 98,
		"authority": 95
	},
	"김유신":
	{
		"name": "김유신",
		"birth_year": 595,
		"death_year": 673,
		"leadership": 95,
		"war": 93,
		"intelligence": 84,
		"politics": 73,
		"authority": 91
	},
	"김법민":
	{
		"name": "김법민",
		"birth_year": 626,
		"death_year": 681,
		"leadership": 88,
		"war": 80,
		"intelligence": 90,
		"politics": 92,
		"authority": 95
	},
	"김흠순":
	{
		"name": "김흠순",
		"birth_year": 598,
		"death_year": 680,
		"leadership": 86,
		"war": 84,
		"intelligence": 78,
		"politics": 72,
		"authority": 83
	},
	"김인문":
	{
		"name": "김인문",
		"birth_year": 629,
		"death_year": 694,
		"leadership": 82,
		"war": 76,
		"intelligence": 88,
		"politics": 90,
		"authority": 85
	},
	"품일":
	{
		"name": "품일",
		"birth_year": 620,
		"death_year": 685,
		"leadership": 85,
		"war": 88,
		"intelligence": 75,
		"politics": 68,
		"authority": 80
	},
	"관창":
	{
		"name": "관창",
		"birth_year": 645,
		"death_year": 660,
		"leadership": 72,
		"war": 90,
		"intelligence": 55,
		"politics": 45,
		"authority": 74
	},
	"설오유":
	{
		"name": "설오유",
		"birth_year": 640,
		"death_year": 683,
		"leadership": 87,
		"war": 88,
		"intelligence": 73,
		"politics": 64,
		"authority": 81
	},
	"김원술":
	{
		"name": "김원술",
		"birth_year": 655,
		"death_year": 675,
		"leadership": 84,
		"war": 89,
		"intelligence": 69,
		"politics": 55,
		"authority": 78
	},
	"무왕":
	{
		"name": "무왕",
		"birth_year": 580,
		"death_year": 641,
		"leadership": 82,
		"war": 76,
		"intelligence": 88,
		"politics": 91,
		"authority": 94
	},
	"의자왕":
	{
		"name": "의자왕",
		"birth_year": 593,
		"death_year": 660,
		"leadership": 70,
		"war": 65,
		"intelligence": 75,
		"politics": 80,
		"authority": 90
	},
	"윤충":
	{
		"name": "윤충",
		"birth_year": 618,
		"death_year": 660,
		"leadership": 90,
		"war": 89,
		"intelligence": 80,
		"politics": 68,
		"authority": 84
	},
	"성충":
	{
		"name": "성충",
		"birth_year": 615,
		"death_year": 660,
		"leadership": 74,
		"war": 58,
		"intelligence": 94,
		"politics": 92,
		"authority": 86
	},
	"흥수":
	{
		"name": "흥수",
		"birth_year": 590,
		"death_year": 660,
		"leadership": 78,
		"war": 65,
		"intelligence": 93,
		"politics": 90,
		"authority": 82
	},
	"계백":
	{
		"name": "계백",
		"birth_year": 595,
		"death_year": 660,
		"leadership": 94,
		"war": 95,
		"intelligence": 76,
		"politics": 62,
		"authority": 88
	},
	"부여태":
	{
		"name": "부여태",
		"birth_year": 615,
		"death_year": 660,
		"leadership": 75,
		"war": 78,
		"intelligence": 60,
		"politics": 55,
		"authority": 70
	},
	"부여풍":
	{
		"name": "부여풍",
		"birth_year": 623,
		"death_year": 669,
		"leadership": 73,
		"war": 66,
		"intelligence": 79,
		"politics": 82,
		"authority": 91
	},
	"복신":
	{
		"name": "복신",
		"birth_year": 592,
		"death_year": 663,
		"leadership": 91,
		"war": 88,
		"intelligence": 84,
		"politics": 71,
		"authority": 89
	},
	"흑치상지":
	{
		"name": "흑치상지",
		"birth_year": 630,
		"death_year": 689,
		"leadership": 92,
		"war": 90,
		"intelligence": 81,
		"politics": 65,
		"authority": 85
	},
	"지수신":
	{
		"name": "지수신",
		"birth_year": 630,
		"death_year": 690,
		"leadership": 88,
		"war": 87,
		"intelligence": 78,
		"politics": 61,
		"authority": 82
	},
	"영류왕":
	{
		"name": "영류왕",
		"birth_year": 586,
		"death_year": 642,
		"leadership": 78,
		"war": 68,
		"intelligence": 86,
		"politics": 90,
		"authority": 92
	},
	"보장왕":
	{
		"name": "보장왕",
		"birth_year": 623,
		"death_year": 682,
		"leadership": 65,
		"war": 52,
		"intelligence": 76,
		"politics": 78,
		"authority": 84
	},
	"연개소문":
	{
		"name": "연개소문",
		"birth_year": 603,
		"death_year": 665,
		"leadership": 96,
		"war": 95,
		"intelligence": 88,
		"politics": 82,
		"authority": 98
	},
	"양만춘":
	{
		"name": "양만춘",
		"birth_year": 605,
		"death_year": 667,
		"leadership": 94,
		"war": 89,
		"intelligence": 85,
		"politics": 70,
		"authority": 88
	},
	"고연무":
	{
		"name": "고연무",
		"birth_year": 634,
		"death_year": 683,
		"leadership": 86,
		"war": 87,
		"intelligence": 75,
		"politics": 65,
		"authority": 82
	},
	"연남생":
	{
		"name": "연남생",
		"birth_year": 634,
		"death_year": 679,
		"leadership": 86,
		"war": 84,
		"intelligence": 76,
		"politics": 68,
		"authority": 82
	},
	"안승":
	{
		"name": "안승",
		"birth_year": 653,
		"death_year": 699,
		"leadership": 76,
		"war": 70,
		"intelligence": 82,
		"politics": 84,
		"authority": 91
	},
	"검모잠":
	{
		"name": "검모잠",
		"birth_year": 623,
		"death_year": 670,
		"leadership": 90,
		"war": 91,
		"intelligence": 78,
		"politics": 62,
		"authority": 86
	},
	"당 고종":
	{
		"name": "당 고종",
		"birth_year": 628,
		"death_year": 683,
		"leadership": 73,
		"war": 55,
		"intelligence": 85,
		"politics": 91,
		"authority": 98
	},
	"고간":
	{
		"name": "고간",
		"birth_year": 617,
		"death_year": 680,
		"leadership": 88,
		"war": 86,
		"intelligence": 80,
		"politics": 72,
		"authority": 84
	},
	"이근행":
	{
		"name": "이근행",
		"birth_year": 625,
		"death_year": 682,
		"leadership": 90,
		"war": 89,
		"intelligence": 76,
		"politics": 61,
		"authority": 83
	},
	"설인귀":
	{
		"name": "설인귀",
		"birth_year": 614,
		"death_year": 683,
		"leadership": 94,
		"war": 95,
		"intelligence": 80,
		"politics": 63,
		"authority": 90
	},
	"유인원":
	{
		"name": "유인원",
		"birth_year": 619,
		"death_year": 670,
		"leadership": 86,
		"war": 82,
		"intelligence": 82,
		"politics": 76,
		"authority": 84
	},
	"유인궤":
	{
		"name": "유인궤",
		"birth_year": 602,
		"death_year": 685,
		"leadership": 92,
		"war": 84,
		"intelligence": 91,
		"politics": 88,
		"authority": 90
	},
	"예군":
	{
		"name": "예군",
		"birth_year": 613,
		"death_year": 678,
		"leadership": 72,
		"war": 68,
		"intelligence": 86,
		"politics": 88,
		"authority": 78
	},
	"당 태종":
	{
		# 한반도 밖 주변 세력의 군주·지휘관. 미상 연도는 0으로 유지합니다.
		"name": "당 태종",
		"birth_year": 598,
		"death_year": 649,
		"leadership": 92,
		"war": 88,
		"intelligence": 94,
		"politics": 96,
		"authority": 99
	},
	"이세적":
	{
		"name": "이세적",
		"birth_year": 594,
		"death_year": 669,
		"leadership": 94,
		"war": 90,
		"intelligence": 88,
		"politics": 78,
		"authority": 91
	},
	"소정방":
	{
		"name": "소정방",
		"birth_year": 591,
		"death_year": 667,
		"leadership": 94,
		"war": 91,
		"intelligence": 84,
		"politics": 68,
		"authority": 90
	},
	"조메이 천황":
	{
		"name": "조메이 천황",
		"birth_year": 593,
		"death_year": 641,
		"leadership": 65,
		"war": 45,
		"intelligence": 78,
		"politics": 82,
		"authority": 94
	},
	"고교쿠 천황":
	{
		"name": "고교쿠 천황",
		"birth_year": 594,
		"death_year": 661,
		"leadership": 72,
		"war": 48,
		"intelligence": 86,
		"politics": 90,
		"authority": 96
	},
	"사이메이 천황":
	{
		"name": "사이메이 천황",
		"birth_year": 594,
		"death_year": 661,
		"leadership": 78,
		"war": 52,
		"intelligence": 88,
		"politics": 91,
		"authority": 97
	},
	"나카노오에 황자":
	{
		"name": "나카노오에 황자",
		"birth_year": 626,
		"death_year": 672,
		"leadership": 86,
		"war": 75,
		"intelligence": 92,
		"politics": 94,
		"authority": 95
	},
	"덴지 천황":
	{
		"name": "덴지 천황",
		"birth_year": 626,
		"death_year": 672,
		"leadership": 86,
		"war": 74,
		"intelligence": 92,
		"politics": 95,
		"authority": 97
	},
	"소가노 에미시":
	{
		"name": "소가노 에미시",
		"birth_year": 587,
		"death_year": 645,
		"leadership": 72,
		"war": 62,
		"intelligence": 88,
		"politics": 92,
		"authority": 87
	},
	"소가노 이루카":
	{
		"name": "소가노 이루카",
		"birth_year": 0,
		"death_year": 645,
		"leadership": 78,
		"war": 70,
		"intelligence": 86,
		"politics": 84,
		"authority": 85
	},
	"아베노 히라후":
	{
		"name": "아베노 히라후",
		"birth_year": 0,
		"death_year": 664,
		"leadership": 88,
		"war": 84,
		"intelligence": 77,
		"politics": 65,
		"authority": 82
	},
	"오토모노 후케이":
	{
		"name": "오토모노 후케이",
		"birth_year": 0,
		"death_year": 672,
		"leadership": 87,
		"war": 85,
		"intelligence": 76,
		"politics": 63,
		"authority": 82
	},
	"이남":
	{
		"name": "이남",
		"birth_year": 0,
		"death_year": 645,
		"leadership": 91,
		"war": 88,
		"intelligence": 84,
		"politics": 80,
		"authority": 94
	},
	"발작":
	{
		"name": "발작",
		"birth_year": 0,
		"death_year": 646,
		"leadership": 84,
		"war": 88,
		"intelligence": 68,
		"politics": 58,
		"authority": 83
	},
	"포룬 일테베르":
	{
		"name": "포룬 일테베르",
		"birth_year": 0,
		"death_year": 0,
		"leadership": 86,
		"war": 84,
		"intelligence": 76,
		"politics": 74,
		"authority": 88
	},
	"비속독 일테베르":
	{
		"name": "비속독 일테베르",
		"birth_year": 0,
		"death_year": 0,
		"leadership": 84,
		"war": 82,
		"intelligence": 72,
		"politics": 70,
		"authority": 86
	},
	"독해지 일테베르":
	{
		"name": "독해지 일테베르",
		"birth_year": 0,
		"death_year": 0,
		"leadership": 83,
		"war": 80,
		"intelligence": 78,
		"politics": 82,
		"authority": 87
	},
	"사결 수장":
	{
		"name": "사결 수장",
		"birth_year": 0,
		"death_year": 0,
		"leadership": 80,
		"war": 84,
		"intelligence": 68,
		"politics": 60,
		"authority": 78
	},
	"다람갈 수장":
	{
		"name": "다람갈 수장",
		"birth_year": 0,
		"death_year": 0,
		"leadership": 81,
		"war": 83,
		"intelligence": 70,
		"politics": 62,
		"authority": 79
	},
	"복골 수장":
	{
		"name": "복골 수장",
		"birth_year": 0,
		"death_year": 0,
		"leadership": 82,
		"war": 86,
		"intelligence": 66,
		"politics": 58,
		"authority": 80
	},
	"발야고 수장":
	{
		"name": "발야고 수장",
		"birth_year": 0,
		"death_year": 0,
		"leadership": 83,
		"war": 87,
		"intelligence": 65,
		"politics": 57,
		"authority": 81
	},
	"아질 수장":
	{
		"name": "아질 수장",
		"birth_year": 0,
		"death_year": 0,
		"leadership": 78,
		"war": 82,
		"intelligence": 67,
		"politics": 59,
		"authority": 76
	},
	"계필 수장":
	{
		"name": "계필 수장",
		"birth_year": 0,
		"death_year": 0,
		"leadership": 84,
		"war": 88,
		"intelligence": 72,
		"politics": 66,
		"authority": 82
	},
	"동라 수장":
	{
		"name": "동라 수장",
		"birth_year": 0,
		"death_year": 0,
		"leadership": 82,
		"war": 85,
		"intelligence": 70,
		"politics": 61,
		"authority": 79
	},
	"혼 수장":
	{
		"name": "혼 수장",
		"birth_year": 0,
		"death_year": 0,
		"leadership": 79,
		"war": 83,
		"intelligence": 69,
		"politics": 60,
		"authority": 77
	},
	"나카토미노 가마타리":
	{
		"name": "나카토미노 가마타리",
		"birth_year": 614,
		"death_year": 669,
		"leadership": 68,
		"war": 55,
		"intelligence": 94,
		"politics": 96,
		"authority": 91
	},
	"아즈미노 히라후":
	{
		"name": "아즈미노 히라후",
		"birth_year": 0,
		"death_year": 663,
		"leadership": 87,
		"war": 84,
		"intelligence": 78,
		"politics": 67,
		"authority": 82
	},
	"에치노 다쿠쓰":
	{
		"name": "에치노 다쿠쓰",
		"birth_year": 0,
		"death_year": 0,
		"leadership": 86,
		"war": 84,
		"intelligence": 75,
		"politics": 62,
		"authority": 80
	},
	"온가":
	{
		"name": "온가",
		"birth_year": 0,
		"death_year": 0,
		"leadership": 82,
		"war": 84,
		"intelligence": 76,
		"politics": 73,
		"authority": 85
	},
	"에미시 수장 미상":
	{
		"name": "에미시 수장 미상",
		"birth_year": 0,
		"death_year": 0,
		"leadership": 80,
		"war": 82,
		"intelligence": 72,
		"politics": 68,
		"authority": 81
	},
	"고시 수장 미상":
	{
		"name": "고시 수장 미상",
		"birth_year": 0,
		"death_year": 0,
		"leadership": 79,
		"war": 76,
		"intelligence": 75,
		"politics": 73,
		"authority": 80
	},
	"쓰쿠시 수장 미상":
	{
		"name": "쓰쿠시 수장 미상",
		"birth_year": 0,
		"death_year": 0,
		"leadership": 79,
		"war": 74,
		"intelligence": 83,
		"politics": 86,
		"authority": 84
	},
	"기비 수장 미상":
	{
		"name": "기비 수장 미상",
		"birth_year": 0,
		"death_year": 0,
		"leadership": 80,
		"war": 72,
		"intelligence": 82,
		"politics": 84,
		"authority": 83
	},
	"하야토 수장 미상":
	{
		"name": "하야토 수장 미상",
		"birth_year": 0,
		"death_year": 0,
		"leadership": 82,
		"war": 88,
		"intelligence": 67,
		"politics": 56,
		"authority": 80
	},
}

# 세력 선택 화면에서 사용하는 군주·지역 수장 초상화입니다.
# 고교쿠/사이메이와 나카노오에/덴지는 동일 인물이므로 같은 파일을 공유합니다.
const RULER_PORTRAIT_PATHS: Dictionary = {
	"당 태종": "res://assets/portraits/tang_taizong.png",
	"조메이 천황": "res://assets/portraits/jomei_tenno.png",
	"고교쿠 천황": "res://assets/portraits/kogyoku_saimei.png",
	"사이메이 천황": "res://assets/portraits/kogyoku_saimei.png",
	"나카노오에 황자": "res://assets/portraits/naka_no_oe_tenji.png",
	"덴지 천황": "res://assets/portraits/naka_no_oe_tenji.png",
	"이남": "res://assets/portraits/inam_khagan.png",
	"포룬 일테베르": "res://assets/portraits/porun_ilteber.png",
	"비속독 일테베르": "res://assets/portraits/bisudu_ilteber.png",
	"독해지 일테베르": "res://assets/portraits/dujiezhi_ilteber.png",
	"복골 수장": "res://assets/portraits/pugu_chief.png",
	"동라 수장": "res://assets/portraits/tongluo_chief.png",
	"발야고 수장": "res://assets/portraits/bayegu_chief.png",
	"사결 수장": "res://assets/portraits/sijie_chief.png",
	"계필 수장": "res://assets/portraits/qibi_chief.png",
	"혼 수장": "res://assets/portraits/hun_chief.png",
	"다람갈 수장": "res://assets/portraits/duolange_chief.png",
	"아질 수장": "res://assets/portraits/adie_chief.png",
	"쓰쿠시 수장 미상": "res://assets/portraits/tsukushi_chief.png",
	"기비 수장 미상": "res://assets/portraits/kibi_chief.png",
	"아베노 히라후": "res://assets/portraits/abe_no_hirafu.png",
	"고시 수장 미상": "res://assets/portraits/koshi_chief.png",
	"온가": "res://assets/portraits/onga_emishi.png",
	"에미시 수장 미상": "res://assets/portraits/emishi_chief.png",
	"하야토 수장 미상": "res://assets/portraits/hayato_chief.png",
}

const TRIBAL_FACTIONS_660: Array[Dictionary] = [
	{
		"id": "huihe",
		"name": "회흘(위구르)",
		"ruler": "포룬 일테베르",
		"commander": "포룬 일테베르",
		"capital": "셀렝게",
		"territories": "셀렝게 유역",
		"troops": 18000,
		"faction_difficulty": "어려움",
		"strength": "초원 기병과 셀렝게 거점",
		"risk": "당의 기미지배와 부족 경쟁",
		"description": "당의 명목상 지배 아래 독자 세력을 유지하는 회흘 부족입니다.",
		"notable": ["포룬 일테베르"],
		"color": "#7a6a43",
		"marker_symbol": "회",
		"marker_label": "셀렝게",
		"start_province": "steppe_huihe",
		"playable": true,
		"faction_type": "철륵 부족"
	},
	{
		"id": "pugu",
		"name": "복골",
		"ruler": "복골 수장",
		"commander": "복골 수장",
		"capital": "오논",
		"territories": "오논 유역",
		"troops": 15000,
		"faction_difficulty": "어려움",
		"strength": "강한 기마 전사",
		"risk": "당과 주변 부족의 압박",
		"description": "660년 철륵 반란에 참여한 것으로 기록되는 복골 부족입니다.",
		"notable": ["복골 수장"],
		"color": "#826447",
		"marker_symbol": "복",
		"marker_label": "오논",
		"start_province": "steppe_pugu",
		"playable": true,
		"faction_type": "철륵 부족"
	},
	{
		"id": "tongluo",
		"name": "동라",
		"ruler": "동라 수장",
		"commander": "동라 수장",
		"capital": "툴강 북안",
		"territories": "툴강 북안",
		"troops": 15500,
		"faction_difficulty": "어려움",
		"strength": "기동력과 교역로",
		"risk": "복골·회흘과의 경쟁",
		"description": "660년 반란의 선두에 섰던 것으로 전하는 동라 부족입니다.",
		"notable": ["동라 수장"],
		"color": "#5f7555",
		"marker_symbol": "동",
		"marker_label": "툴강 북안",
		"start_province": "steppe_tongluo",
		"playable": true,
		"faction_type": "철륵 부족"
	},
	{
		"id": "bayegu",
		"name": "발야고",
		"ruler": "발야고 수장",
		"commander": "발야고 수장",
		"capital": "케룰렌",
		"territories": "케룰렌 유역",
		"troops": 14500,
		"faction_difficulty": "매우 어려움",
		"strength": "동부 초원의 기마력",
		"risk": "고립된 동부 거점",
		"description": "케룰렌 일대에서 660년 반란에 참여한 발야고 부족입니다.",
		"notable": ["발야고 수장"],
		"color": "#6a7350",
		"marker_symbol": "발",
		"marker_label": "케룰렌",
		"start_province": "steppe_bayegu",
		"playable": true,
		"faction_type": "철륵 부족"
	},
	{
		"id": "sijie",
		"name": "사결",
		"ruler": "사결 수장",
		"commander": "사결 수장",
		"capital": "알타이 동록",
		"territories": "알타이 동록",
		"troops": 13000,
		"faction_difficulty": "매우 어려움",
		"strength": "산록 방어와 기병",
		"risk": "서쪽 변방의 보급",
		"description": "660년 철륵 반란에 가담한 사결 부족입니다.",
		"notable": ["사결 수장"],
		"color": "#75614f",
		"marker_symbol": "사",
		"marker_label": "알타이 동록",
		"start_province": "steppe_sijie",
		"playable": true,
		"faction_type": "철륵 부족"
	},
	{
		"id": "qibi",
		"name": "계필",
		"ruler": "계필 수장",
		"commander": "계필 수장",
		"capital": "툴강 남안",
		"territories": "툴강 남안",
		"troops": 14000,
		"faction_difficulty": "어려움",
		"strength": "당과의 교섭 경험",
		"risk": "초원 내부의 분열",
		"description": "당과 복잡한 종속·동맹 관계를 맺었던 계필 부족입니다.",
		"notable": ["계필 수장"],
		"color": "#8a744d",
		"marker_symbol": "계",
		"marker_label": "툴강 남안",
		"start_province": "steppe_qibi",
		"playable": true,
		"faction_type": "철륵 부족"
	},
	{
		"id": "hun",
		"name": "혼",
		"ruler": "혼 수장",
		"commander": "혼 수장",
		"capital": "고비 남록",
		"territories": "고비 남록",
		"troops": 12500,
		"faction_difficulty": "매우 어려움",
		"strength": "당 변경과의 교역",
		"risk": "부족 규모와 수자원 부족",
		"description": "고비 남쪽 교통로에 자리한 철륵계 혼 부족입니다.",
		"notable": ["혼 수장"],
		"color": "#665b53",
		"marker_symbol": "혼",
		"marker_label": "고비 남록",
		"start_province": "steppe_hun",
		"playable": true,
		"faction_type": "철륵 부족"
	},
	{
		"id": "duolange",
		"name": "다람갈",
		"ruler": "다람갈 수장",
		"commander": "다람갈 수장",
		"capital": "항가이",
		"territories": "항가이 산록",
		"troops": 15000,
		"faction_difficulty": "어려움",
		"strength": "항가이의 중심 위치",
		"risk": "여러 부족 사이의 충돌",
		"description": "항가이 일대에 자리하고 660년대 전쟁에 등장하는 다람갈 부족입니다.",
		"notable": ["다람갈 수장"],
		"color": "#7c684c",
		"marker_symbol": "다",
		"marker_label": "항가이",
		"start_province": "steppe_duolange",
		"playable": true,
		"faction_type": "철륵 부족"
	},
	{
		"id": "adie",
		"name": "아질",
		"ruler": "아질 수장",
		"commander": "아질 수장",
		"capital": "고비 북연",
		"territories": "고비 북연",
		"troops": 12000,
		"faction_difficulty": "매우 어려움",
		"strength": "사막 교통로 통제",
		"risk": "작은 인구와 거친 환경",
		"description": "당대 철륵 부족군에 포함된 아질 부족입니다.",
		"notable": ["아질 수장"],
		"color": "#6f694a",
		"marker_symbol": "아",
		"marker_label": "고비 북연",
		"start_province": "steppe_adie",
		"playable": true,
		"faction_type": "철륵 부족"
	},
]

const STEPPE_REBEL_FACTION_IDS: Array[String] = [
	"sijie",
	"bayegu",
	"pugu",
	"tongluo",
]

const FACTION_AVAILABILITY: Dictionary = {
	"silla": {"playable_by_default": true, "unlockable": false, "ai_enabled": true},
	"baekje": {"playable_by_default": true, "unlockable": false, "ai_enabled": true},
	"goguryeo": {"playable_by_default": true, "unlockable": false, "ai_enabled": true},
	"tang": {"playable_by_default": false, "unlockable": true, "unlock_id": "faction.tang", "ai_enabled": true},
	"yamato": {"playable_by_default": false, "unlockable": true, "unlock_id": "faction.yamato", "ai_enabled": true},
	"xueyantuo": {"playable_by_default": false, "unlockable": true, "unlock_id": "faction.xueyantuo", "ai_enabled": true},
	"baekje_revival": {"playable_by_default": false, "unlockable": true, "unlock_id": "faction.baekje_revival", "ai_enabled": true},
	"goguryeo_revival": {"playable_by_default": false, "unlockable": true, "unlock_id": "faction.goguryeo_revival", "ai_enabled": true},
	"huihe": {"playable_by_default": false, "unlockable": true, "unlock_id": "faction.huihe", "ai_enabled": true},
	"pugu": {"playable_by_default": false, "unlockable": true, "unlock_id": "faction.pugu", "ai_enabled": true},
	"tongluo": {"playable_by_default": false, "unlockable": true, "unlock_id": "faction.tongluo", "ai_enabled": true},
	"bayegu": {"playable_by_default": false, "unlockable": true, "unlock_id": "faction.bayegu", "ai_enabled": true},
	"sijie": {"playable_by_default": false, "unlockable": true, "unlock_id": "faction.sijie", "ai_enabled": true},
	"qibi": {"playable_by_default": false, "unlockable": true, "unlock_id": "faction.qibi", "ai_enabled": true},
	"hun": {"playable_by_default": false, "unlockable": true, "unlock_id": "faction.hun", "ai_enabled": true},
	"duolange": {"playable_by_default": false, "unlockable": true, "unlock_id": "faction.duolange", "ai_enabled": true},
	"adie": {"playable_by_default": false, "unlockable": true, "unlock_id": "faction.adie", "ai_enabled": true},
	"tsukushi": {"playable_by_default": false, "unlockable": true, "unlock_id": "faction.tsukushi", "ai_enabled": true},
	"kibi": {"playable_by_default": false, "unlockable": true, "unlock_id": "faction.kibi", "ai_enabled": true},
	"koshi_abe": {"playable_by_default": false, "unlockable": true, "unlock_id": "faction.koshi_abe", "ai_enabled": true},
	"emishi": {"playable_by_default": false, "unlockable": true, "unlock_id": "faction.emishi", "ai_enabled": true},
	"hayato": {"playable_by_default": false, "unlockable": true, "unlock_id": "faction.hayato", "ai_enabled": true},
}

const JAPAN_LOCAL_FACTIONS_660: Array[Dictionary] = [
	{
		"id": "tsukushi",
		"name": "쓰쿠시 해상세력",
		"ruler": "쓰쿠시 수장 미상",
		"commander": "아즈미노 히라후",
		"capital": "쓰쿠시",
		"territories": "북부 규슈 · 해협 항구",
		"troops": 23000,
		"faction_difficulty": "보통",
		"strength": "한반도와 가까운 수군·항구",
		"risk": "야마토 조정의 동원 요구",
		"description": "야마토 조정과 연합하면서도 독자적인 해상 기반을 가진 북부 규슈 호족 세력입니다.",
		"notable": ["아즈미노 히라후", "에치노 다쿠쓰"],
		"color": "#326c78",
		"marker_symbol": "쓰",
		"marker_label": "쓰쿠시",
		"start_province": "tsukushi",
		"playable": true,
		"faction_type": "야마토 연합 지방세력"
	},
	{
		"id": "kibi",
		"name": "기비 호족연합",
		"ruler": "기비 수장 미상",
		"commander": "기비 수장 미상",
		"capital": "기비",
		"territories": "기비 · 세토내해 서부",
		"troops": 21000,
		"faction_difficulty": "보통",
		"strength": "철 생산과 세토내해 항로",
		"risk": "중앙집권화 압력",
		"description": "철 생산과 해상 교통을 바탕으로 야마토 조정과 협력한 강력한 지방 호족권입니다.",
		"notable": ["기비 수장 미상"],
		"color": "#8b6038",
		"marker_symbol": "기",
		"marker_label": "기비",
		"start_province": "kibi",
		"playable": true,
		"faction_type": "야마토 연합 지방세력"
	},
	{
		"id": "koshi_abe",
		"name": "고시 아베 수군",
		"ruler": "아베노 히라후",
		"commander": "아베노 히라후",
		"capital": "고시",
		"territories": "고시 · 동해 북부 항로",
		"troops": 18000,
		"faction_difficulty": "어려움",
		"strength": "대규모 수군과 북방 원정 경험",
		"risk": "긴 해안선과 에미시 관계",
		"description": "658~660년 북방 원정을 지휘한 아베노 히라후의 지역 수군 기반을 별도 세력으로 표현했습니다.",
		"notable": ["아베노 히라후"],
		"color": "#4c6b86",
		"marker_symbol": "아",
		"marker_label": "고시",
		"start_province": "koshi",
		"playable": true,
		"faction_type": "야마토 연합 군사세력"
	},
	{
		"id": "emishi",
		"name": "에미시 연맹",
		"ruler": "온가",
		"commander": "온가",
		"capital": "아기타",
		"territories": "아기타 · 쓰가루",
		"troops": 13500,
		"faction_difficulty": "매우 어려움",
		"strength": "북방 지형과 궁술",
		"risk": "야마토 수군의 북상",
		"description": "아기타의 수장 온가를 중심으로 북동 혼슈의 여러 에미시 집단을 게임용 연맹으로 표현했습니다.",
		"notable": ["온가"],
		"color": "#6b5143",
		"marker_symbol": "에",
		"marker_label": "아기타",
		"start_province": "emishi_aguta",
		"playable": true,
		"faction_type": "변방 부족연맹"
	},
	{
		"id": "hayato",
		"name": "하야토 부족연맹",
		"ruler": "하야토 수장 미상",
		"commander": "하야토 수장 미상",
		"capital": "남부 규슈",
		"territories": "사쓰마 · 오스미 일대",
		"troops": 16000,
		"faction_difficulty": "매우 어려움",
		"strength": "산악·해안 전투",
		"risk": "야마토의 남부 통합",
		"description": "남부 규슈에서 독자성을 유지한 하야토 집단입니다. 660년의 구체적인 수장명은 기록 미상으로 둡니다.",
		"notable": ["하야토 수장 미상"],
		"color": "#77543b",
		"marker_symbol": "하",
		"marker_label": "남부 규슈",
		"start_province": "hayato",
		"playable": true,
		"faction_type": "변방 부족연맹"
	},
]

const SCENARIOS: Array[Dictionary] = [
	{
		"id": "silla_equilibrium_632",
		"name": "632년, 선덕여왕 즉위",
		"description": "신라 선덕여왕, 백제 무왕, 고구려 영류왕이 다스리는 삼국 균형기입니다.",
		"year": 632,
		"season": "spring",
		"factions":
		[
			{
				"id": "silla",
				"name": "신라",
				"ruler": "선덕여왕",
				"commander": "김유신",
				"capital": "금성",
				"territories": "금성 · 사벌주 · 국원",
				"troops": 57000,
				"faction_difficulty": "어려움",
				"strength": "인재와 방어 결속",
				"risk": "백제·고구려의 협공",
				"description": "첫 여왕의 통치 아래 생존과 외교를 함께 풀어야 합니다.",
				"notable": ["선덕여왕", "김유신", "김춘추", "알천"],
				"color": "#d2a62f",
				"portrait_paths": ["res://assets/portraits/seondeok_queen.png"],
				"marker_uv": Vector2(0.650, 0.720),
				"marker_label": "금성",
				"start_province": "geumseong"
			},
			{
				"id": "baekje",
				"name": "백제",
				"ruler": "무왕",
				"commander": "윤충",
				"capital": "사비성",
				"territories": "사비성 · 웅진성 · 고사성",
				"troops": 62000,
				"faction_difficulty": "보통",
				"strength": "회복된 국력과 공세",
				"risk": "왕위 계승과 장기전",
				"description": "무왕 말기의 국력을 바탕으로 신라 서부를 압박할 수 있습니다.",
				"notable": ["무왕", "의자왕", "윤충", "복신"],
				"color": "#a64035",
				"portrait_paths": ["res://assets/portraits/mu_wang.png"],
				"marker_uv": Vector2(0.490, 0.650),
				"marker_label": "사비성",
				"start_province": "sabi"
			},
			{
				"id": "goguryeo",
				"name": "고구려",
				"ruler": "영류왕",
				"commander": "연개소문",
				"capital": "평양성",
				"territories": "평양성 · 국내성 · 안시성",
				"troops": 100000,
				"faction_difficulty": "보통",
				"strength": "넓은 영토와 산성",
				"risk": "왕권과 군부의 긴장",
				"description": "영류왕과 연개소문 사이의 긴장을 안고 북방의 강국을 운영합니다.",
				"notable": ["영류왕", "연개소문", "양만춘"],
				"color": "#3d5f86",
				"portrait_paths": ["res://assets/portraits/yeongnyu_wang.png"],
				"marker_uv": Vector2(0.470, 0.360),
				"marker_label": "평양성",
				"start_province": "pyongyang"
			},
			{
				"id": "tang",
				"name": "당",
				"ruler": "당 태종",
				"commander": "이세적",
				"capital": "장안",
				"territories": "장안 · 낙양 · 산동",
				"troops": 115000,
				"faction_difficulty": "보통",
				"strength": "대륙의 인력과 기병",
				"risk": "고구려 원정의 긴 보급선",
				"description": "동돌궐을 격파한 당 태종이 동북방으로 영향력을 넓히는 시기입니다.",
				"notable": ["당 태종", "이세적"],
				"color": "#556b45",
				"portrait_paths": [],
				"marker_symbol": "唐",
				"marker_uv": Vector2(0.075, 0.330),
				"marker_label": "당 본토",
				"start_province": "",
				"playable": false,
				"availability_note": "중국 본토 영지가 추가되는 세계지도 확장 후 플레이할 수 있습니다."
			},
			{
				"id": "yamato",
				"name": "왜(야마토)",
				"ruler": "조메이 천황",
				"commander": "소가노 에미시",
				"capital": "아스카",
				"territories": "아스카 · 나니와 · 규슈",
				"troops": 39000,
				"faction_difficulty": "어려움",
				"strength": "해상 교통과 한반도 외교",
				"risk": "호족 연합의 내부 갈등",
				"description": "조메이 천황과 소가씨가 야마토 정권을 운영하는 아스카 시대입니다.",
				"notable": ["조메이 천황", "소가노 에미시"],
				"color": "#7b4f84",
				"portrait_paths": [],
				"marker_symbol": "倭",
				"marker_uv": Vector2(0.945, 0.790),
				"marker_label": "야마토",
				"start_province": "",
				"playable": false,
				"availability_note": "일본 열도 영지가 추가되는 세계지도 확장 후 플레이할 수 있습니다."
			},
			{
				"id": "xueyantuo",
				"name": "설연타",
				"ruler": "이남",
				"ruler_title": "진주가한",
				"commander": "발작",
				"capital": "외튀켄",
				"territories": "오르혼 · 외튀켄 · 셀렝게",
				"troops": 78000,
				"faction_difficulty": "보통",
				"strength": "몽골 고원의 기동 기병",
				"risk": "당과의 불안정한 동맹",
				"description": "진주가한 이남이 몽골 고원의 여러 철륵 부족을 이끄는 시기입니다.",
				"notable": ["이남", "발작"],
				"color": "#6d6246",
				"portrait_paths": [],
				"marker_symbol": "薛",
				"marker_uv": Vector2(0.165, 0.055),
				"marker_label": "몽골 고원",
				"start_province": "",
				"playable": false,
				"availability_note": "몽골 고원 영지가 추가되는 세계지도 확장 후 플레이할 수 있습니다."
			},
		],
		"province_overrides":
		{
			"ansi": {"faction": "고구려", "governor": "양만춘", "troops": 36000},
			"gungnae": {"faction": "고구려", "governor": "연개소문", "troops": 28000},
			"pyongyang": {"faction": "고구려", "governor": "영류왕", "troops": 36000, "public_order": 78},
			"ungjin": {"faction": "백제", "governor": "흥수", "troops": 19000},
			"sabi": {"faction": "백제", "governor": "무왕", "troops": 25000, "public_order": 76},
			"gosa": {"faction": "백제", "governor": "윤충", "troops": 18000},
			"gukwon": {"faction": "신라", "governor": "알천", "troops": 17000},
			"sabeol": {"faction": "신라", "governor": "김유신", "troops": 17000},
			"geumseong": {"faction": "신라", "governor": "선덕여왕", "troops": 23000, "public_order": 82},
		},
		"officers_by_province":
		{
			"ansi": ["양만춘"],
			"gungnae": ["연개소문"],
			"pyongyang": ["영류왕"],
			"ungjin": ["흥수"],
			"sabi": ["무왕", "의자왕"],
			"gosa": ["윤충", "복신"],
			"gukwon": ["알천"],
			"sabeol": ["김유신"],
			"geumseong": ["선덕여왕", "김춘추"],
		},
	},
	{
		"id": "goguryeo_coup_642",
		"name": "642년, 연개소문의 정변",
		"description": "선덕여왕과 의자왕이 대립하고, 연개소문이 보장왕을 세운 격변기입니다.",
		"year": 642,
		"season": "autumn",
		"factions":
		[
			{
				"id": "silla",
				"name": "신라",
				"ruler": "선덕여왕",
				"commander": "김유신",
				"capital": "금성",
				"territories": "금성 · 사벌주 · 국원",
				"troops": 52000,
				"faction_difficulty": "매우 어려움",
				"strength": "김유신과 김춘추",
				"risk": "대야성 상실과 양면전",
				"description": "대야성 패배 뒤 생존 외교와 반격을 동시에 준비해야 합니다.",
				"notable": ["선덕여왕", "김유신", "김춘추", "알천"],
				"color": "#d2a62f",
				"portrait_paths": ["res://assets/portraits/seondeok_queen.png"],
				"marker_uv": Vector2(0.650, 0.720),
				"marker_label": "금성",
				"start_province": "geumseong"
			},
			{
				"id": "baekje",
				"name": "백제",
				"ruler": "의자왕",
				"commander": "윤충",
				"capital": "사비성",
				"territories": "사비성 · 웅진성 · 고사성",
				"troops": 72000,
				"faction_difficulty": "쉬움",
				"strength": "대야성 승리의 기세",
				"risk": "신라의 외교 반격",
				"description": "의자왕과 윤충의 공세로 신라 서부를 장악해 가는 시점입니다.",
				"notable": ["의자왕", "윤충", "성충", "흥수"],
				"color": "#a64035",
				"portrait_paths": ["res://assets/portraits/uija_wang.png"],
				"marker_uv": Vector2(0.490, 0.650),
				"marker_label": "사비성",
				"start_province": "sabi"
			},
			{
				"id": "goguryeo",
				"name": "고구려",
				"ruler": "보장왕",
				"commander": "연개소문",
				"capital": "평양성",
				"territories": "평양성 · 국내성 · 안시성",
				"troops": 105000,
				"faction_difficulty": "보통",
				"strength": "대막리지의 군권",
				"risk": "정변 직후의 불안",
				"description": "보장왕을 옹립한 연개소문이 군사와 정치를 장악한 직후입니다.",
				"notable": ["보장왕", "연개소문", "양만춘"],
				"color": "#3d5f86",
				"portrait_paths":
				[
					"res://assets/portraits/bojang_wang.png",
					"res://assets/portraits/yeon_gaesomun.png"
				],
				"marker_uv": Vector2(0.470, 0.360),
				"marker_label": "평양성",
				"start_province": "pyongyang"
			},
			{
				"id": "tang",
				"name": "당",
				"ruler": "당 태종",
				"commander": "이세적",
				"capital": "장안",
				"territories": "장안 · 낙양 · 산동",
				"troops": 120000,
				"faction_difficulty": "보통",
				"strength": "대륙의 인력과 원정군",
				"risk": "고구려 산성망과 보급",
				"description": "당 태종이 고구려 원정을 준비하며 요동과 해상로를 주시하는 시기입니다.",
				"notable": ["당 태종", "이세적"],
				"color": "#556b45",
				"portrait_paths": [],
				"marker_symbol": "唐",
				"marker_uv": Vector2(0.075, 0.330),
				"marker_label": "당 본토",
				"start_province": "",
				"playable": false,
				"availability_note": "중국 본토 영지가 추가되는 세계지도 확장 후 플레이할 수 있습니다."
			},
			{
				"id": "yamato",
				"name": "왜(야마토)",
				"ruler": "고교쿠 천황",
				"commander": "소가노 이루카",
				"capital": "아스카",
				"territories": "아스카 · 나니와 · 규슈",
				"troops": 41000,
				"faction_difficulty": "어려움",
				"strength": "백제와의 외교·해상 교통",
				"risk": "소가씨와 왕실의 권력투쟁",
				"description": "고교쿠 천황 즉위와 소가씨의 권세가 겹친 야마토 정권의 격변기입니다.",
				"notable": ["고교쿠 천황", "소가노 이루카"],
				"color": "#7b4f84",
				"portrait_paths": [],
				"marker_symbol": "倭",
				"marker_uv": Vector2(0.945, 0.790),
				"marker_label": "야마토",
				"start_province": "",
				"playable": false,
				"availability_note": "일본 열도 영지가 추가되는 세계지도 확장 후 플레이할 수 있습니다."
			},
			{
				"id": "xueyantuo",
				"name": "설연타",
				"ruler": "이남",
				"ruler_title": "진주가한",
				"commander": "발작",
				"capital": "외튀켄",
				"territories": "오르혼 · 외튀켄 · 셀렝게",
				"troops": 84000,
				"faction_difficulty": "보통",
				"strength": "초원 기병과 넓은 세력권",
				"risk": "당과의 주도권 경쟁",
				"description": "설연타가 몽골 고원의 중심 세력으로 성장해 당과 긴장하는 시기입니다.",
				"notable": ["이남", "발작"],
				"color": "#6d6246",
				"portrait_paths": [],
				"marker_symbol": "薛",
				"marker_uv": Vector2(0.165, 0.055),
				"marker_label": "몽골 고원",
				"start_province": "",
				"playable": false,
				"availability_note": "몽골 고원 영지가 추가되는 세계지도 확장 후 플레이할 수 있습니다."
			},
		],
		"province_overrides":
		{
			"ansi": {"faction": "고구려", "governor": "양만춘", "troops": 40000},
			"gungnae": {"faction": "고구려", "governor": "연개소문", "troops": 28000},
			"pyongyang": {"faction": "고구려", "governor": "보장왕", "troops": 37000, "public_order": 62},
			"ungjin": {"faction": "백제", "governor": "흥수", "troops": 22000},
			"sabi": {"faction": "백제", "governor": "의자왕", "troops": 27000, "public_order": 82},
			"gosa": {"faction": "백제", "governor": "윤충", "troops": 23000},
			"gukwon": {"faction": "신라", "governor": "알천", "troops": 16000},
			"sabeol": {"faction": "신라", "governor": "김유신", "troops": 15000, "public_order": 65},
			"geumseong": {"faction": "신라", "governor": "선덕여왕", "troops": 21000, "public_order": 70},
		},
		"officers_by_province":
		{
			"ansi": ["양만춘"],
			"gungnae": ["연개소문"],
			"pyongyang": ["보장왕"],
			"ungjin": ["흥수", "성충"],
			"sabi": ["의자왕"],
			"gosa": ["윤충", "계백"],
			"gukwon": ["알천"],
			"sabeol": ["김유신"],
			"geumseong": ["선덕여왕", "김춘추"],
		},
	},
	{
		"id": "baekje_fall_660",
		"name": "660년, 백제 멸망 전야",
		"description": "무열왕의 신라와 당 연합군이 의자왕의 백제를 압박하고, 고구려는 보장왕과 연개소문 체제입니다.",
		"year": 660,
		"season": "spring",
		"factions":
		[
			{
				"id": "silla",
				"name": "신라",
				"ruler": "김춘추",
				"ruler_title": "태종무열왕",
				"commander": "김유신",
				"capital": "금성",
				"territories": "금성 · 사벌주 · 국원소경",
				"troops": 66000,
				"faction_difficulty": "보통",
				"strength": "외교와 인재 운용",
				"risk": "당 의존과 다면전",
				"description": "나당연합을 완성하고 백제 정벌을 준비한 신라입니다.",
				"notable": ["김춘추", "김유신", "김법민", "김인문"],
				"featured_officers": ["김유신", "김인문", "김흠순"],
				"color": "#d2a62f",
				"portrait_paths":
				["res://assets/portraits/kim_chunchu.png", "res://assets/portraits/kim_yushin.png"],
				"marker_uv": Vector2(0.650, 0.720),
				"marker_label": "금성",
				"start_province": "geumseong"
			},
			{
				"id": "baekje",
				"name": "백제",
				"ruler": "의자왕",
				"commander": "계백",
				"capital": "사비성",
				"territories": "사비성 · 웅진성 · 고사성",
				"troops": 57000,
				"faction_difficulty": "어려움",
				"strength": "요새 방어와 결사 항전",
				"risk": "나당연합군의 침공",
				"description": "멸망의 위기 앞에서 계백과 지방군을 결집해야 합니다.",
				"notable": ["의자왕", "계백", "흑치상지", "흥수"],
				"featured_officers": ["계백", "흑치상지", "흥수"],
				"color": "#a64035",
				"portrait_paths":
				["res://assets/portraits/uija_wang.png", "res://assets/portraits/gyebaek.png"],
				"marker_uv": Vector2(0.490, 0.650),
				"marker_label": "사비성",
				"start_province": "sabi"
			},
			{
				"id": "goguryeo",
				"name": "고구려",
				"ruler": "보장왕",
				"commander": "연개소문",
				"capital": "평양성",
				"territories": "평양성 · 국내성 · 안시성",
				"troops": 100000,
				"faction_difficulty": "보통",
				"strength": "강한 군사력과 산성",
				"risk": "후계 갈등과 당의 압박",
				"description": "연개소문의 지휘 아래 당의 침공에 맞서는 북방 강국입니다.",
				"notable": ["보장왕", "연개소문", "양만춘", "연남생"],
				"featured_officers": ["연개소문", "양만춘", "연남생"],
				"color": "#3d5f86",
				"portrait_paths":
				[
					"res://assets/portraits/bojang_wang.png",
					"res://assets/portraits/yeon_gaesomun.png"
				],
				"marker_uv": Vector2(0.470, 0.360),
				"marker_label": "평양성",
				"start_province": "pyongyang"
			},
			{
				"id": "tang",
				"name": "당",
				"ruler": "당 고종",
				"commander": "소정방",
				"capital": "장안",
				"territories": "장안 · 낙양 · 산동 원정기지",
				"troops": 135000,
				"faction_difficulty": "쉬움",
				"strength": "대규모 수군과 원정군",
				"risk": "상륙전과 긴 보급선",
				"description": "소정방의 원정군이 산동에서 출항하여 백제 정벌에 나선 시기입니다.",
				"notable": ["당 고종", "소정방", "유인궤"],
				"color": "#556b45",
				"portrait_paths": ["res://assets/portraits/tang_gaozong.png"],
				"marker_symbol": "唐",
				"marker_uv": Vector2(0.075, 0.480),
				"marker_label": "당 원정군",
				"start_province": "",
				"playable": false,
				"availability_note": "상륙 전 당 본토·원정기지가 추가되는 세계지도 확장 후 플레이할 수 있습니다."
			},
			{
				"id": "yamato",
				"name": "왜(야마토)",
				"ruler": "사이메이 천황",
				"commander": "아베노 히라후",
				"capital": "아스카",
				"territories": "아스카 · 나니와 · 규슈",
				"troops": 46000,
				"faction_difficulty": "보통",
				"strength": "백제와의 오랜 동맹",
				"risk": "원거리 해상 원정",
				"description": "사이메이 천황 아래 백제 구원을 준비할 수 있는 야마토 정권입니다.",
				"notable": ["사이메이 천황", "나카노오에 황자", "아베노 히라후"],
				"color": "#7b4f84",
				"portrait_paths": [],
				"marker_symbol": "倭",
				"marker_uv": Vector2(0.945, 0.790),
				"marker_label": "규슈",
				"start_province": "",
				"playable": false,
				"availability_note": "일본 열도와 해상 원정 시스템이 추가된 뒤 플레이할 수 있습니다."
			},
			{
				"id": "huihe",
				"name": "회흘(위구르 제부)",
				"ruler": "포룬 일테베르",
				"commander": "포룬 일테베르",
				"capital": "셀렝게 유역",
				"territories": "셀렝게 · 오르혼 북방",
				"troops": 47000,
				"faction_difficulty": "어려움",
				"strength": "초원 기병과 부족 연맹",
				"risk": "당의 기미지배와 부족 분산",
				"description": "설연타 멸망 뒤 몽골 고원 북부에서 회흘 부족이 성장하는 시기입니다.",
				"notable": ["포룬 일테베르"],
				"color": "#7a6a43",
				"portrait_paths": [],
				"marker_symbol": "回",
				"marker_uv": Vector2(0.165, 0.055),
				"marker_label": "셀렝게",
				"start_province": "",
				"playable": false,
				"availability_note": "몽골 고원 영지가 추가되는 세계지도 확장 후 플레이할 수 있습니다."
			},
		],
		"province_overrides":
		{
			"ansi": {"faction": "고구려", "governor": "양만춘", "troops": 40000},
			"gungnae": {"faction": "고구려", "governor": "고연무", "troops": 25000},
			"pyongyang": {"faction": "고구려", "governor": "연개소문", "troops": 35000},
			"ungjin": {"faction": "백제", "governor": "흑치상지", "troops": 20000},
			"sabi": {"faction": "백제", "governor": "의자왕", "troops": 22000, "public_order": 48},
			"gosa": {"faction": "백제", "governor": "부여태", "troops": 15000},
			"gukwon": {"faction": "신라", "governor": "김법민", "troops": 18000},
			"sabeol": {"faction": "신라", "governor": "품일", "troops": 20000},
			"geumseong": {"faction": "신라", "governor": "김춘추", "troops": 28000},
		},
		"officers_by_province":
		{
			"ansi": ["양만춘"],
			"gungnae": ["고연무"],
			"pyongyang": ["연개소문", "연남생", "보장왕"],
			"ungjin": ["흑치상지", "흥수"],
			"sabi": ["의자왕"],
			"gosa": ["부여태", "계백"],
			"gukwon": ["김법민", "김흠순"],
			"sabeol": ["품일", "관창"],
			"geumseong": ["김춘추", "김유신", "김인문"],
		},
	},
	{
		"id": "baekgang_663",
		"name": "663년, 백강 전투 전야",
		"description": "문무왕의 신라, 부여풍의 백제부흥군, 보장왕의 고구려가 맞서며 당군이 백제 고지에 주둔합니다.",
		"year": 663,
		"season": "autumn",
		"factions":
		[
			{
				"id": "silla",
				"name": "신라",
				"ruler": "김법민",
				"ruler_title": "문무왕",
				"commander": "김유신",
				"capital": "금성",
				"territories": "금성 · 사벌주 · 국원소경",
				"troops": 76000,
				"faction_difficulty": "보통",
				"strength": "나당연합과 노련한 지휘",
				"risk": "부흥군의 장기 저항",
				"description": "문무왕이 백제부흥군 진압과 고구려 전선을 함께 관리합니다.",
				"notable": ["김법민", "김유신", "김인문", "김흠순"],
				"color": "#d2a62f",
				"portrait_paths":
				["res://assets/portraits/kim_beopmin.png", "res://assets/portraits/kim_yushin.png"],
				"marker_uv": Vector2(0.650, 0.720),
				"marker_label": "금성",
				"start_province": "geumseong"
			},
			{
				"id": "baekje_revival",
				"name": "백제부흥군",
				"ruler": "부여풍",
				"ruler_title": "풍왕",
				"commander": "흑치상지",
				"capital": "주류성",
				"territories": "주류성 · 임존성 일대",
				"troops": 34000,
				"faction_difficulty": "매우 어려움",
				"strength": "산성망과 유민의 결집",
				"risk": "내분과 보급 부족",
				"description": "왜의 지원이 도착하기 전 주류성과 임존성의 저항을 결집해야 합니다.",
				"notable": ["부여풍", "흑치상지", "지수신"],
				"color": "#8f342f",
				"portrait_paths":
				[
					"res://assets/portraits/buyeo_pung.png",
					"res://assets/portraits/heukchi_sangji.png"
				],
				"marker_uv": Vector2(0.455, 0.705),
				"marker_label": "주류성",
				"start_province": "gosa"
			},
			{
				"id": "goguryeo",
				"name": "고구려",
				"ruler": "보장왕",
				"commander": "연개소문",
				"capital": "평양성",
				"territories": "평양성 · 국내성 · 안시성",
				"troops": 92000,
				"faction_difficulty": "보통",
				"strength": "북방 산성과 군사력",
				"risk": "연개소문 후계 문제",
				"description": "백제 멸망 뒤 당의 다음 목표가 된 고구려입니다.",
				"notable": ["보장왕", "연개소문", "양만춘", "연남생"],
				"color": "#3d5f86",
				"portrait_paths":
				[
					"res://assets/portraits/bojang_wang.png",
					"res://assets/portraits/yeon_gaesomun.png"
				],
				"marker_uv": Vector2(0.470, 0.360),
				"marker_label": "평양성",
				"start_province": "pyongyang"
			},
			{
				"id": "tang",
				"name": "당",
				"ruler": "당 고종",
				"commander": "유인궤",
				"capital": "장안",
				"territories": "웅진도독부 · 사비성 · 당 본토",
				"troops": 108000,
				"faction_difficulty": "쉬움",
				"strength": "백제 고지의 주둔군과 수군",
				"risk": "백제부흥군과 왜 수군",
				"description": "유인궤가 웅진도독부와 당 수군을 지휘하여 백제부흥군을 압박합니다.",
				"notable": ["당 고종", "유인궤", "유인원", "예군"],
				"color": "#556b45",
				"portrait_paths": ["res://assets/portraits/tang_gaozong.png"],
				"marker_uv": Vector2(0.500, 0.625),
				"marker_label": "웅진도독부",
				"start_province": "ungjin"
			},
			{
				"id": "yamato",
				"name": "왜(야마토)",
				"ruler": "나카노오에 황자",
				"commander": "아베노 히라후",
				"capital": "아스카",
				"territories": "아스카 · 나니와 · 규슈 원군항",
				"troops": 52000,
				"faction_difficulty": "어려움",
				"strength": "대규모 수군과 백제 연대",
				"risk": "먼 해상 보급과 당 수군",
				"description": "나카노오에 황자가 백제부흥군을 돕기 위해 규슈에서 원군을 파견합니다.",
				"notable": ["나카노오에 황자", "아베노 히라후"],
				"color": "#7b4f84",
				"portrait_paths": [],
				"marker_symbol": "倭",
				"marker_uv": Vector2(0.945, 0.790),
				"marker_label": "규슈 원군항",
				"start_province": "",
				"playable": false,
				"availability_note": "일본 열도와 해상전 시스템이 추가된 뒤 플레이할 수 있습니다."
			},
			{
				"id": "huihe",
				"name": "회흘(위구르 제부)",
				"ruler": "비속독 일테베르",
				"commander": "비속독 일테베르",
				"capital": "셀렝게 유역",
				"territories": "셀렝게 · 오르혼 북방",
				"troops": 50000,
				"faction_difficulty": "어려움",
				"strength": "초원 기병과 부족 연맹",
				"risk": "당의 기미지배와 내부 경쟁",
				"description": "비속독의 패주 뒤 회흘 세력이 당의 기미권 안에서 재편되는 시기입니다.",
				"notable": ["비속독 일테베르"],
				"color": "#7a6a43",
				"portrait_paths": [],
				"marker_symbol": "回",
				"marker_uv": Vector2(0.165, 0.055),
				"marker_label": "셀렝게",
				"start_province": "",
				"playable": false,
				"availability_note": "몽골 고원 영지가 추가되는 세계지도 확장 후 플레이할 수 있습니다."
			},
		],
		"province_overrides":
		{
			"ansi": {"faction": "고구려", "governor": "양만춘", "troops": 37000},
			"gungnae": {"faction": "고구려", "governor": "연남생", "troops": 24000},
			"pyongyang": {"faction": "고구려", "governor": "보장왕", "troops": 31000},
			"ungjin": {"faction": "당", "governor": "유인원", "troops": 26000, "public_order": 52},
			"sabi": {"faction": "당", "governor": "유인궤", "troops": 23000, "public_order": 42},
			"gosa":
			{
				"name": "주류성",
				"faction": "백제부흥군",
				"governor": "부여풍",
				"troops": 34000,
				"fortress": 82,
				"public_order": 71
			},
			"gukwon": {"faction": "신라", "governor": "김흠순", "troops": 21000},
			"sabeol": {"faction": "신라", "governor": "품일", "troops": 24000},
			"geumseong": {"faction": "신라", "governor": "김법민", "troops": 31000},
		},
		"officers_by_province":
		{
			"ansi": ["양만춘"],
			"gungnae": ["연남생"],
			"pyongyang": ["보장왕", "연개소문"],
			"ungjin": ["유인원", "예군"],
			"sabi": ["유인궤"],
			"gosa": ["부여풍", "흑치상지", "지수신"],
			"gukwon": ["김흠순"],
			"sabeol": ["품일"],
			"geumseong": ["김법민", "김유신", "김인문"],
		},
	},
	{
		"id": "silla_tang_war_670",
		"name": "670년, 나당전쟁 발발",
		"description": "문무왕의 신라, 당 고종의 점령군, 안승의 고구려부흥군이 한반도 지배권을 놓고 충돌합니다.",
		"year": 670,
		"season": "spring",
		"factions":
		[
			{
				"id": "silla",
				"name": "신라",
				"ruler": "김법민",
				"ruler_title": "문무왕",
				"commander": "김유신",
				"capital": "금성",
				"territories": "금성 · 사벌주 · 국원소경",
				"troops": 82000,
				"faction_difficulty": "어려움",
				"strength": "통합된 남부와 부흥군 연대",
				"risk": "당의 대규모 증원",
				"description": "옛 동맹 당을 상대로 백제 고지와 고구려 유민을 포섭해야 합니다.",
				"notable": ["김법민", "김유신", "김인문", "설오유", "김원술"],
				"color": "#d2a62f",
				"portrait_paths":
				["res://assets/portraits/kim_beopmin.png", "res://assets/portraits/kim_yushin.png"],
				"marker_uv": Vector2(0.650, 0.720),
				"marker_label": "금성",
				"start_province": "geumseong"
			},
			{
				"id": "tang",
				"name": "당",
				"ruler": "당 고종",
				"commander": "고간",
				"capital": "장안",
				"territories": "안동도호부 · 웅진도독부",
				"troops": 125000,
				"faction_difficulty": "보통",
				"strength": "막대한 인력과 원정군",
				"risk": "긴 보급선과 유민 저항",
				"description": "평양과 백제 고지의 도호부를 유지하며 신라의 이탈을 진압합니다.",
				"notable": ["당 고종", "고간", "이근행", "설인귀", "예군"],
				"color": "#556b45",
				"portrait_paths":
				[
					"res://assets/portraits/tang_gaozong.png",
					"res://assets/portraits/xue_rengui.png"
				],
				"marker_uv": Vector2(0.470, 0.360),
				"marker_label": "안동도호부",
				"start_province": "pyongyang"
			},
			{
				"id": "goguryeo_revival",
				"name": "고구려부흥군",
				"ruler": "안승",
				"ruler_title": "고구려왕",
				"commander": "고연무",
				"capital": "금마저",
				"territories": "금마저 · 요동 저항성",
				"troops": 31000,
				"faction_difficulty": "매우 어려움",
				"strength": "유민 결집과 신라 지원",
				"risk": "분산된 거점과 내분",
				"description": "안승과 고연무가 신라와 연대하여 고구려 재건을 시도합니다.",
				"notable": ["안승", "고연무", "검모잠"],
				"color": "#516f91",
				"portrait_paths":
				["res://assets/portraits/anseung.png", "res://assets/portraits/go_yeonmu.png"],
				"marker_uv": Vector2(0.485, 0.670),
				"marker_label": "금마저",
				"start_province": "gosa"
			},
			{
				"id": "yamato",
				"name": "왜(야마토)",
				"ruler": "덴지 천황",
				"commander": "오토모노 후케이",
				"capital": "오미 오쓰",
				"territories": "오미 · 아스카 · 규슈",
				"troops": 48000,
				"faction_difficulty": "보통",
				"strength": "율령 정비와 해상 교통",
				"risk": "백강 패전 뒤의 국방 부담",
				"description": "덴지 천황이 오미 오쓰에서 국가 개혁과 서부 방어를 추진하는 시기입니다.",
				"notable": ["덴지 천황", "오토모노 후케이"],
				"color": "#7b4f84",
				"portrait_paths": [],
				"marker_symbol": "倭",
				"marker_uv": Vector2(0.945, 0.790),
				"marker_label": "오미·규슈",
				"start_province": "",
				"playable": false,
				"availability_note": "일본 열도 영지가 추가되는 세계지도 확장 후 플레이할 수 있습니다."
			},
			{
				"id": "huihe",
				"name": "회흘(위구르 제부)",
				"ruler": "비속독 일테베르",
				"commander": "비속독 일테베르",
				"capital": "셀렝게 유역",
				"territories": "셀렝게 · 오르혼 북방",
				"troops": 52000,
				"faction_difficulty": "어려움",
				"strength": "초원 기병과 부족 연맹",
				"risk": "당의 기미지배와 내부 경쟁",
				"description": "몽골 고원 북부의 회흘 부족이 당의 영향 아래 독자 세력을 유지합니다.",
				"notable": ["비속독 일테베르"],
				"color": "#7a6a43",
				"portrait_paths": [],
				"marker_symbol": "回",
				"marker_uv": Vector2(0.165, 0.055),
				"marker_label": "셀렝게",
				"start_province": "",
				"playable": false,
				"availability_note": "몽골 고원 영지가 추가되는 세계지도 확장 후 플레이할 수 있습니다."
			},
		],
		"province_overrides":
		{
			"ansi": {"faction": "고구려부흥군", "governor": "고연무", "troops": 17000, "public_order": 64},
			"gungnae": {"faction": "당", "governor": "이근행", "troops": 28000, "public_order": 53},
			"pyongyang": {"faction": "당", "governor": "고간", "troops": 34000, "public_order": 45},
			"ungjin": {"faction": "당", "governor": "예군", "troops": 22000, "public_order": 48},
			"sabi": {"faction": "당", "governor": "유인궤", "troops": 19000, "public_order": 44},
			"gosa":
			{
				"name": "금마저",
				"faction": "고구려부흥군",
				"governor": "안승",
				"troops": 14000,
				"public_order": 72
			},
			"gukwon": {"faction": "신라", "governor": "김흠순", "troops": 24000},
			"sabeol": {"faction": "신라", "governor": "설오유", "troops": 26000},
			"geumseong": {"faction": "신라", "governor": "김법민", "troops": 32000},
		},
		"officers_by_province":
		{
			"ansi": ["고연무"],
			"gungnae": ["이근행"],
			"pyongyang": ["고간", "설인귀", "당 고종"],
			"ungjin": ["예군"],
			"sabi": ["유인궤", "유인원"],
			"gosa": ["안승", "검모잠"],
			"gukwon": ["김흠순"],
			"sabeol": ["설오유", "김원술"],
			"geumseong": ["김법민", "김유신", "김인문"],
		},
	},
]


static func get_steppe_factions(year: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var diplomacy: Dictionary = WorldMapData.get_steppe_diplomacy(year)
	for tribe_value: Dictionary in TRIBAL_FACTIONS_660:
		var tribe: Dictionary = tribe_value.duplicate(true)
		var faction_id: String = str(tribe.get("id", ""))
		var start_province: String = str(tribe.get("start_province", ""))
		var province_diplomacy: Dictionary = diplomacy.get(start_province, {})
		tribe["overlord"] = str(province_diplomacy.get("overlord", "당"))
		tribe["submission"] = int(province_diplomacy.get("submission", 60))
		tribe["diplomatic_status"] = str(province_diplomacy.get("status", "당 기미부주"))
		tribe["faction_type"] = "철륵계 부족권 · 당 기미부주"

		if faction_id == "huihe":
			if year <= 660:
				tribe["ruler"] = "포룬 일테베르"
				tribe["commander"] = "포룬 일테베르"
				tribe["notable"] = ["포룬 일테베르"]
				tribe["description"] = (
					"설연타 멸망 뒤 당의 기미부주 체제에 들어갔지만 " + "셀렝게 유역에서 자체 수장과 군대를 유지한 회흘 부족입니다."
				)
			elif year < 680:
				tribe["ruler"] = "비속독 일테베르"
				tribe["commander"] = "비속독 일테베르"
				tribe["notable"] = ["비속독 일테베르"]
				if year <= 662:
					tribe["description"] = ("비속독이 복골·동라 등과 함께 당에 반기를 든 " + "철륵 반란기의 회흘 세력입니다.")
				else:
					tribe["description"] = "비속독의 패주 뒤 회흘 세력이 당의 기미권 안에서 재편되는 시기입니다."
			else:
				tribe["ruler"] = "독해지 일테베르"
				tribe["commander"] = "독해지 일테베르"
				tribe["notable"] = ["독해지 일테베르"]
				tribe["description"] = (
					"661~662년 반란 진압 뒤 독해지가 회흘을 이끌고, " + "663년 한해도호부가 초원 북부로 옮겨온 시기의 세력입니다."
				)

		if year >= 661 and year <= 662 and STEPPE_REBEL_FACTION_IDS.has(faction_id):
			tribe["diplomatic_status"] = "철륵 반란군"
			tribe["overlord"] = ""
			tribe["risk"] = "당 토벌군과 부족 연합의 불안정"
			tribe["description"] = (
				"660년 무렵 당의 기미지배에 반발하여 봉기한 "
				+ "%s 부족입니다. 주변 반란 부족과 연합해야 합니다." % str(tribe.get("name", "철륵"))
			)

		if faction_id == "qibi":
			tribe["description"] = (
				"계필의 주력 일부는 이미 당에 들어가 복무했으므로, " + "이 세력은 툴강 남쪽에 남은 계필계 목지와 부족민을 표현합니다."
			)
			tribe["strength"] = "당군 경험과 빠른 초원 기병"
			tribe["risk"] = "당 복속파와 잔류 부족의 분열"

		result.append(tribe)
	return result


static func _apply_ruler_portrait(faction: Dictionary) -> void:
	var ruler_name: String = str(faction.get("ruler", ""))
	if RULER_PORTRAIT_PATHS.has(ruler_name):
		faction["portrait_paths"] = [RULER_PORTRAIT_PATHS[ruler_name]]


static func _apply_faction_availability(faction: Dictionary) -> void:
	var faction_id: String = str(faction.get("id", ""))
	var metadata: Dictionary = FACTION_AVAILABILITY.get(faction_id, {})
	faction["playable_by_default"] = bool(metadata.get("playable_by_default", false))
	faction["unlockable"] = bool(metadata.get("unlockable", false))
	faction["ai_enabled"] = bool(metadata.get("ai_enabled", true))
	if metadata.has("unlock_id"):
		faction["unlock_id"] = str(metadata["unlock_id"])
	else:
		faction.erase("unlock_id")
	# Keep the legacy field as a derived compatibility value for existing UI callers.
	faction["playable"] = bool(faction["playable_by_default"])


static func _prepare_scenario(base_scenario: Dictionary) -> Dictionary:
	var scenario: Dictionary = base_scenario.duplicate(true)
	var year: int = int(scenario.get("year", 660))
	var prepared_factions: Array = []
	var source_factions: Array = scenario.get("factions", [])

	for faction_value: Variant in source_factions:
		if typeof(faction_value) != TYPE_DICTIONARY:
			continue
		var faction: Dictionary = faction_value.duplicate(true)
		var faction_id: String = str(faction.get("id", ""))

		# 660년 이후 회흘은 아래의 철륵 9부족 목록에서 다시 추가합니다.
		if year >= 660 and faction_id == "huihe":
			continue

		_apply_faction_availability(faction)

		match faction_id:
			"tang":
				faction["start_province"] = "changan"
				faction["marker_label"] = "장안"
			"yamato":
				faction["start_province"] = "asuka"
				faction["marker_label"] = "아스카"
				faction["territories"] = "아스카 · 나니와"
				faction["faction_type"] = "중앙 왕권"
				if year >= 660:
					faction["name"] = "왜(야마토 조정)"
			"xueyantuo":
				faction["start_province"] = "steppe_duolange"
				faction["marker_label"] = "외튀켄"

		_apply_ruler_portrait(faction)
		var start_province: String = str(faction.get("start_province", ""))
		if WorldMapData.PROVINCE_MAP_UV.has(start_province):
			faction["marker_uv"] = WorldMapData.PROVINCE_MAP_UV[start_province]
		prepared_factions.append(faction)

	if year >= 660:
		for tribe: Dictionary in get_steppe_factions(year):
			var prepared_tribe: Dictionary = tribe.duplicate(true)
			_apply_faction_availability(prepared_tribe)
			_apply_ruler_portrait(prepared_tribe)
			var tribe_start: String = str(prepared_tribe["start_province"])
			prepared_tribe["marker_uv"] = WorldMapData.PROVINCE_MAP_UV[tribe_start]
			prepared_factions.append(prepared_tribe)

	for local_faction: Dictionary in JAPAN_LOCAL_FACTIONS_660:
		var prepared_local: Dictionary = local_faction.duplicate(true)
		_apply_faction_availability(prepared_local)
		var local_id: String = str(prepared_local.get("id", ""))
		if (year < 658 or year > 664) and local_id == "koshi_abe":
			prepared_local["name"] = "고시 호족권"
			prepared_local["ruler"] = "고시 수장 미상"
			prepared_local["commander"] = "고시 수장 미상"
			prepared_local["notable"] = ["고시 수장 미상"]
			prepared_local["description"] = (
				"고시 일대의 해상·지역 기반을 가진 호족권입니다. " + "아베노 히라후의 활동 시기 밖에서는 수장명을 미상으로 둡니다."
			)
		if year < 658 and local_id == "emishi":
			prepared_local["ruler"] = "에미시 수장 미상"
			prepared_local["commander"] = "에미시 수장 미상"
			prepared_local["notable"] = ["에미시 수장 미상"]
		if year < 660 or year > 663:
			if local_id == "tsukushi":
				prepared_local["commander"] = "쓰쿠시 수장 미상"
				prepared_local["notable"] = ["쓰쿠시 수장 미상"]
		_apply_ruler_portrait(prepared_local)
		var local_start: String = str(prepared_local["start_province"])
		prepared_local["marker_uv"] = WorldMapData.PROVINCE_MAP_UV[local_start]
		prepared_factions.append(prepared_local)

	scenario["factions"] = prepared_factions
	return scenario


static func get_scenario(scenario_id: String) -> Dictionary:
	for scenario: Dictionary in SCENARIOS:
		if str(scenario.get("id", "")) == scenario_id:
			return _prepare_scenario(scenario)
	return _prepare_scenario(SCENARIOS[2])


static func get_scenario_by_index(index: int) -> Dictionary:
	if index < 0 or index >= SCENARIOS.size():
		return get_scenario(DEFAULT_SCENARIO_ID)
	return _prepare_scenario(SCENARIOS[index])


static func get_faction(scenario_id: String, faction_id: String) -> Dictionary:
	var scenario: Dictionary = get_scenario(scenario_id)
	var faction_values: Array = scenario.get("factions", [])
	for faction_value: Variant in faction_values:
		if typeof(faction_value) != TYPE_DICTIONARY:
			continue
		var faction: Dictionary = faction_value
		if str(faction.get("id", "")) == faction_id:
			return faction
	return {}


static func get_active_faction_ids(scenario_id: String) -> Array[String]:
	var result: Array[String] = []
	for faction_value: Variant in get_scenario(scenario_id).get("factions", []):
		if typeof(faction_value) != TYPE_DICTIONARY:
			continue
		var faction_id: String = str((faction_value as Dictionary).get("id", ""))
		if faction_id != "" and not result.has(faction_id):
			result.append(faction_id)
	return result


static func is_faction_playable_by_default(scenario_id: String, faction_id: String) -> bool:
	var faction: Dictionary = get_faction(scenario_id, faction_id)
	return not faction.is_empty() and bool(faction.get("playable_by_default", false))


static func is_faction_ai_enabled(scenario_id: String, faction_id: String) -> bool:
	var faction: Dictionary = get_faction(scenario_id, faction_id)
	return not faction.is_empty() and bool(faction.get("ai_enabled", false))


static func get_officer_database() -> Dictionary:
	var result: Dictionary = OFFICERS.duplicate(true)
	for officer_name_value: Variant in result.keys():
		var officer_name: String = str(officer_name_value)
		var officer: Dictionary = result[officer_name]
		officer["origin"] = "historical"
		officer["is_historical"] = true
		officer["featured_eligible"] = true
		officer["faction_screen_eligible"] = true
		result[officer_name] = officer
	return result


static func get_featured_officers(
	scenario_id: String, faction_id: String, limit: int = 3
) -> Array[String]:
	var faction: Dictionary = get_faction(scenario_id, faction_id)
	if faction.is_empty():
		return []
	var ruler_name: String = str(faction.get("ruler", ""))
	var candidates: Array = faction.get("featured_officers", [])
	if candidates.is_empty():
		candidates = faction.get("notable", [])
	var result: Array[String] = []
	for officer_name_value: Variant in candidates:
		var officer_name: String = str(officer_name_value)
		if officer_name == ruler_name or not OFFICERS.has(officer_name):
			continue
		# OFFICERS는 시나리오에 고정된 역사 인물 DB입니다.
		# 런타임 생성 인물은 이 DB를 수정하지 않으므로 능력치가 높아도 표시되지 않습니다.
		result.append(officer_name)
		if result.size() >= maxi(1, limit):
			break
	return result


static func get_featured_officer_text(
	scenario_id: String, faction_id: String, scenario_year: int, limit: int = 3
) -> String:
	return get_notable_text(
		get_featured_officers(scenario_id, faction_id, limit),
		scenario_year
	)


static func get_signature_unit_text(faction_id: String) -> String:
	var units: Array = SIGNATURE_UNIT_NAMES.get(faction_id, ["정예 향병"])
	return " · ".join(PackedStringArray(units))


static func get_age_text(person_name: String, scenario_year: int) -> String:
	if not OFFICERS.has(person_name):
		return "나이 미상"
	var data: Dictionary = OFFICERS[person_name]
	var birth_year: int = int(data.get("birth_year", 0))
	if birth_year <= 0:
		return "나이 미상"
	if scenario_year < birth_year:
		return "미등장"
	var death_year: int = int(data.get("death_year", 0))
	if death_year > 0 and scenario_year > death_year:
		return "사망"
	return "약 %d세" % (scenario_year - birth_year)


static func get_notable_text(names_value: Variant, scenario_year: int) -> String:
	if typeof(names_value) != TYPE_ARRAY:
		return ""
	var parts: PackedStringArray = []
	var names: Array = names_value
	for name_value: Variant in names:
		var person_name: String = str(name_value)
		parts.append("%s(%s)" % [person_name, get_age_text(person_name, scenario_year)])
	return " · ".join(parts)


static func get_faction_name(scenario_id: String, faction_id: String) -> String:
	var faction: Dictionary = get_faction(scenario_id, faction_id)
	return str(faction.get("name", "신라"))


static func get_faction_id_by_name(scenario_id: String, faction_name: String) -> String:
	var scenario: Dictionary = get_scenario(scenario_id)
	var faction_values: Array = scenario.get("factions", [])
	for faction_value: Variant in faction_values:
		if typeof(faction_value) != TYPE_DICTIONARY:
			continue
		var faction: Dictionary = faction_value
		if str(faction.get("name", "")) == faction_name:
			return str(faction.get("id", "silla"))
	return "silla"


static func get_starting_province(scenario_id: String, faction_id: String) -> String:
	var faction: Dictionary = get_faction(scenario_id, faction_id)
	return str(faction.get("start_province", "geumseong"))


static func is_known_faction_name(faction_name: String) -> bool:
	for base_scenario: Dictionary in SCENARIOS:
		var scenario: Dictionary = _prepare_scenario(base_scenario)
		var faction_values: Array = scenario.get("factions", [])
		for faction_value: Variant in faction_values:
			if typeof(faction_value) != TYPE_DICTIONARY:
				continue
			var faction: Dictionary = faction_value
			if str(faction.get("name", "")) == faction_name:
				return true
	# 시나리오 점령군처럼 선택 목록 밖에서 캠페인에 존재할 수도 있습니다.
	return faction_name == "당"
