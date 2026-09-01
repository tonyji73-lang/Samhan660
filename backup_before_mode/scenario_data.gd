extends RefCounted

# 새 게임 설정 화면과 실제 캠페인이 함께 읽는 단일 시나리오 데이터입니다.
# 출생 연도가 문헌으로 확인되는 인물만 birth_year를 기록합니다.
# 출생 연도가 불명인 인물은 0으로 두며 화면에는 "나이 미상"으로 표시됩니다.

const DEFAULT_SCENARIO_ID: String = "baekje_fall_660"

const OFFICERS: Dictionary = {
	"선덕여왕": {"name": "선덕여왕", "birth_year": 0, "death_year": 647, "leadership": 76, "war": 48, "intelligence": 91, "politics": 93, "authority": 94},
	"알천": {"name": "알천", "birth_year": 0, "death_year": 0, "leadership": 86, "war": 84, "intelligence": 76, "politics": 78, "authority": 85},
	"김춘추": {"name": "김춘추", "birth_year": 603, "death_year": 661, "leadership": 75, "war": 60, "intelligence": 95, "politics": 98, "authority": 95},
	"김유신": {"name": "김유신", "birth_year": 595, "death_year": 673, "leadership": 95, "war": 93, "intelligence": 84, "politics": 73, "authority": 91},
	"김법민": {"name": "김법민", "birth_year": 0, "death_year": 681, "leadership": 88, "war": 80, "intelligence": 90, "politics": 92, "authority": 95},
	"김흠순": {"name": "김흠순", "birth_year": 0, "death_year": 0, "leadership": 86, "war": 84, "intelligence": 78, "politics": 72, "authority": 83},
	"김인문": {"name": "김인문", "birth_year": 629, "death_year": 694, "leadership": 82, "war": 76, "intelligence": 88, "politics": 90, "authority": 85},
	"품일": {"name": "품일", "birth_year": 0, "death_year": 0, "leadership": 85, "war": 88, "intelligence": 75, "politics": 68, "authority": 80},
	"관창": {"name": "관창", "birth_year": 0, "death_year": 660, "leadership": 72, "war": 90, "intelligence": 55, "politics": 45, "authority": 74},
	"설오유": {"name": "설오유", "birth_year": 0, "death_year": 0, "leadership": 87, "war": 88, "intelligence": 73, "politics": 64, "authority": 81},
	"김원술": {"name": "김원술", "birth_year": 0, "death_year": 0, "leadership": 84, "war": 89, "intelligence": 69, "politics": 55, "authority": 78},

	"무왕": {"name": "무왕", "birth_year": 0, "death_year": 641, "leadership": 82, "war": 76, "intelligence": 88, "politics": 91, "authority": 94},
	"의자왕": {"name": "의자왕", "birth_year": 0, "death_year": 660, "leadership": 70, "war": 65, "intelligence": 75, "politics": 80, "authority": 90},
	"윤충": {"name": "윤충", "birth_year": 0, "death_year": 0, "leadership": 90, "war": 89, "intelligence": 80, "politics": 68, "authority": 84},
	"성충": {"name": "성충", "birth_year": 0, "death_year": 0, "leadership": 74, "war": 58, "intelligence": 94, "politics": 92, "authority": 86},
	"흥수": {"name": "흥수", "birth_year": 0, "death_year": 0, "leadership": 78, "war": 65, "intelligence": 93, "politics": 90, "authority": 82},
	"계백": {"name": "계백", "birth_year": 0, "death_year": 660, "leadership": 94, "war": 95, "intelligence": 76, "politics": 62, "authority": 88},
	"부여태": {"name": "부여태", "birth_year": 0, "death_year": 0, "leadership": 75, "war": 78, "intelligence": 60, "politics": 55, "authority": 70},
	"부여풍": {"name": "부여풍", "birth_year": 0, "death_year": 0, "leadership": 73, "war": 66, "intelligence": 79, "politics": 82, "authority": 91},
	"복신": {"name": "복신", "birth_year": 0, "death_year": 663, "leadership": 91, "war": 88, "intelligence": 84, "politics": 71, "authority": 89},
	"흑치상지": {"name": "흑치상지", "birth_year": 630, "death_year": 689, "leadership": 92, "war": 90, "intelligence": 81, "politics": 65, "authority": 85},
	"지수신": {"name": "지수신", "birth_year": 0, "death_year": 0, "leadership": 88, "war": 87, "intelligence": 78, "politics": 61, "authority": 82},

	"영류왕": {"name": "영류왕", "birth_year": 0, "death_year": 642, "leadership": 78, "war": 68, "intelligence": 86, "politics": 90, "authority": 92},
	"보장왕": {"name": "보장왕", "birth_year": 0, "death_year": 682, "leadership": 65, "war": 52, "intelligence": 76, "politics": 78, "authority": 84},
	"연개소문": {"name": "연개소문", "birth_year": 0, "death_year": 665, "leadership": 96, "war": 95, "intelligence": 88, "politics": 82, "authority": 98},
	"양만춘": {"name": "양만춘", "birth_year": 0, "death_year": 0, "leadership": 94, "war": 89, "intelligence": 85, "politics": 70, "authority": 88},
	"고연무": {"name": "고연무", "birth_year": 0, "death_year": 0, "leadership": 86, "war": 87, "intelligence": 75, "politics": 65, "authority": 82},
	"연남생": {"name": "연남생", "birth_year": 634, "death_year": 679, "leadership": 86, "war": 84, "intelligence": 76, "politics": 68, "authority": 82},
	"안승": {"name": "안승", "birth_year": 0, "death_year": 0, "leadership": 76, "war": 70, "intelligence": 82, "politics": 84, "authority": 91},
	"검모잠": {"name": "검모잠", "birth_year": 0, "death_year": 670, "leadership": 90, "war": 91, "intelligence": 78, "politics": 62, "authority": 86},

	"당 고종": {"name": "당 고종", "birth_year": 628, "death_year": 683, "leadership": 73, "war": 55, "intelligence": 85, "politics": 91, "authority": 98},
	"고간": {"name": "고간", "birth_year": 0, "death_year": 0, "leadership": 88, "war": 86, "intelligence": 80, "politics": 72, "authority": 84},
	"이근행": {"name": "이근행", "birth_year": 0, "death_year": 0, "leadership": 90, "war": 89, "intelligence": 76, "politics": 61, "authority": 83},
	"설인귀": {"name": "설인귀", "birth_year": 614, "death_year": 683, "leadership": 94, "war": 95, "intelligence": 80, "politics": 63, "authority": 90},
	"유인원": {"name": "유인원", "birth_year": 0, "death_year": 0, "leadership": 86, "war": 82, "intelligence": 82, "politics": 76, "authority": 84},
	"유인궤": {"name": "유인궤", "birth_year": 602, "death_year": 685, "leadership": 92, "war": 84, "intelligence": 91, "politics": 88, "authority": 90},
	"예군": {"name": "예군", "birth_year": 613, "death_year": 678, "leadership": 72, "war": 68, "intelligence": 86, "politics": 88, "authority": 78},
}

const SCENARIOS: Array[Dictionary] = [
	{
		"id": "silla_equilibrium_632",
		"name": "632년, 선덕여왕 즉위",
		"description": "신라 선덕여왕, 백제 무왕, 고구려 영류왕이 다스리는 삼국 균형기입니다.",
		"year": 632,
		"season": "spring",
		"factions": [
			{"id": "silla", "name": "신라", "ruler": "선덕여왕", "commander": "김유신", "capital": "금성", "territories": "금성 · 사벌주 · 국원", "troops": 57000, "faction_difficulty": "어려움", "strength": "인재와 방어 결속", "risk": "백제·고구려의 협공", "description": "첫 여왕의 통치 아래 생존과 외교를 함께 풀어야 합니다.", "notable": ["선덕여왕", "김유신", "김춘추", "알천"], "color": "#d2a62f", "portrait_paths": ["res://assets/portraits/kim_yushin.png"], "marker_uv": Vector2(0.612, 0.586), "marker_label": "금성", "start_province": "geumseong"},
			{"id": "baekje", "name": "백제", "ruler": "무왕", "commander": "윤충", "capital": "사비성", "territories": "사비성 · 웅진성 · 고사성", "troops": 62000, "faction_difficulty": "보통", "strength": "회복된 국력과 공세", "risk": "왕위 계승과 장기전", "description": "무왕 말기의 국력을 바탕으로 신라 서부를 압박할 수 있습니다.", "notable": ["무왕", "의자왕", "윤충", "복신"], "color": "#a64035", "portrait_paths": ["res://assets/portraits/uija_wang.png"], "marker_uv": Vector2(0.537, 0.547), "marker_label": "사비성", "start_province": "sabi"},
			{"id": "goguryeo", "name": "고구려", "ruler": "영류왕", "commander": "연개소문", "capital": "평양성", "territories": "평양성 · 국내성 · 안시성", "troops": 100000, "faction_difficulty": "보통", "strength": "넓은 영토와 산성", "risk": "왕권과 군부의 긴장", "description": "영류왕과 연개소문 사이의 긴장을 안고 북방의 강국을 운영합니다.", "notable": ["영류왕", "연개소문", "양만춘"], "color": "#3d5f86", "portrait_paths": ["res://assets/portraits/yeon_gaesomun.png"], "marker_uv": Vector2(0.534, 0.332), "marker_label": "평양성", "start_province": "pyongyang"},
		],
		"province_overrides": {
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
		"officers_by_province": {
			"ansi": ["양만춘"], "gungnae": ["연개소문"], "pyongyang": ["영류왕"],
			"ungjin": ["흥수"], "sabi": ["무왕", "의자왕"], "gosa": ["윤충", "복신"],
			"gukwon": ["알천"], "sabeol": ["김유신"], "geumseong": ["선덕여왕", "김춘추"],
		},
	},
	{
		"id": "goguryeo_coup_642",
		"name": "642년, 연개소문의 정변",
		"description": "선덕여왕과 의자왕이 대립하고, 연개소문이 보장왕을 세운 격변기입니다.",
		"year": 642,
		"season": "autumn",
		"factions": [
			{"id": "silla", "name": "신라", "ruler": "선덕여왕", "commander": "김유신", "capital": "금성", "territories": "금성 · 사벌주 · 국원", "troops": 52000, "faction_difficulty": "매우 어려움", "strength": "김유신과 김춘추", "risk": "대야성 상실과 양면전", "description": "대야성 패배 뒤 생존 외교와 반격을 동시에 준비해야 합니다.", "notable": ["선덕여왕", "김유신", "김춘추", "알천"], "color": "#d2a62f", "portrait_paths": ["res://assets/portraits/kim_yushin.png"], "marker_uv": Vector2(0.612, 0.586), "marker_label": "금성", "start_province": "geumseong"},
			{"id": "baekje", "name": "백제", "ruler": "의자왕", "commander": "윤충", "capital": "사비성", "territories": "사비성 · 웅진성 · 고사성", "troops": 72000, "faction_difficulty": "쉬움", "strength": "대야성 승리의 기세", "risk": "신라의 외교 반격", "description": "의자왕과 윤충의 공세로 신라 서부를 장악해 가는 시점입니다.", "notable": ["의자왕", "윤충", "성충", "흥수"], "color": "#a64035", "portrait_paths": ["res://assets/portraits/uija_wang.png"], "marker_uv": Vector2(0.537, 0.547), "marker_label": "사비성", "start_province": "sabi"},
			{"id": "goguryeo", "name": "고구려", "ruler": "보장왕", "commander": "연개소문", "capital": "평양성", "territories": "평양성 · 국내성 · 안시성", "troops": 105000, "faction_difficulty": "보통", "strength": "대막리지의 군권", "risk": "정변 직후의 불안", "description": "보장왕을 옹립한 연개소문이 군사와 정치를 장악한 직후입니다.", "notable": ["보장왕", "연개소문", "양만춘"], "color": "#3d5f86", "portrait_paths": ["res://assets/portraits/yeon_gaesomun.png"], "marker_uv": Vector2(0.534, 0.332), "marker_label": "평양성", "start_province": "pyongyang"},
		],
		"province_overrides": {
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
		"officers_by_province": {
			"ansi": ["양만춘"], "gungnae": ["연개소문"], "pyongyang": ["보장왕"],
			"ungjin": ["흥수", "성충"], "sabi": ["의자왕"], "gosa": ["윤충", "계백"],
			"gukwon": ["알천"], "sabeol": ["김유신"], "geumseong": ["선덕여왕", "김춘추"],
		},
	},
	{
		"id": "baekje_fall_660",
		"name": "660년, 백제 멸망 전야",
		"description": "무열왕의 신라와 당 연합군이 의자왕의 백제를 압박하고, 고구려는 보장왕과 연개소문 체제입니다.",
		"year": 660,
		"season": "spring",
		"factions": [
			{"id": "silla", "name": "신라", "ruler": "김춘추", "ruler_title": "태종무열왕", "commander": "김유신", "capital": "금성", "territories": "금성 · 사벌주 · 국원소경", "troops": 66000, "faction_difficulty": "보통", "strength": "외교와 인재 운용", "risk": "당 의존과 다면전", "description": "나당연합을 완성하고 백제 정벌을 준비한 신라입니다.", "notable": ["김춘추", "김유신", "김법민", "김인문"], "color": "#d2a62f", "portrait_paths": ["res://assets/portraits/kim_yushin.png", "res://assets/portraits/kim_chunchu.png"], "marker_uv": Vector2(0.612, 0.586), "marker_label": "금성", "start_province": "geumseong"},
			{"id": "baekje", "name": "백제", "ruler": "의자왕", "commander": "계백", "capital": "사비성", "territories": "사비성 · 웅진성 · 고사성", "troops": 57000, "faction_difficulty": "어려움", "strength": "요새 방어와 결사 항전", "risk": "나당연합군의 침공", "description": "멸망의 위기 앞에서 계백과 지방군을 결집해야 합니다.", "notable": ["의자왕", "계백", "흑치상지", "흥수"], "color": "#a64035", "portrait_paths": ["res://assets/portraits/gyebaek.png", "res://assets/portraits/uija_wang.png"], "marker_uv": Vector2(0.537, 0.547), "marker_label": "사비성", "start_province": "sabi"},
			{"id": "goguryeo", "name": "고구려", "ruler": "보장왕", "commander": "연개소문", "capital": "평양성", "territories": "평양성 · 국내성 · 안시성", "troops": 100000, "faction_difficulty": "보통", "strength": "강한 군사력과 산성", "risk": "후계 갈등과 당의 압박", "description": "연개소문의 지휘 아래 당의 침공에 맞서는 북방 강국입니다.", "notable": ["보장왕", "연개소문", "양만춘", "연남생"], "color": "#3d5f86", "portrait_paths": ["res://assets/portraits/yeon_gaesomun.png", "res://assets/portraits/bojang_wang.png"], "marker_uv": Vector2(0.534, 0.332), "marker_label": "평양성", "start_province": "pyongyang"},
		],
		"province_overrides": {
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
		"officers_by_province": {
			"ansi": ["양만춘"], "gungnae": ["고연무"], "pyongyang": ["연개소문", "연남생", "보장왕"],
			"ungjin": ["흑치상지", "흥수"], "sabi": ["의자왕"], "gosa": ["부여태", "계백"],
			"gukwon": ["김법민", "김흠순"], "sabeol": ["품일", "관창"], "geumseong": ["김춘추", "김유신", "김인문"],
		},
	},
	{
		"id": "baekgang_663",
		"name": "663년, 백강 전투 전야",
		"description": "문무왕의 신라, 부여풍의 백제부흥군, 보장왕의 고구려가 맞서며 당군이 백제 고지에 주둔합니다.",
		"year": 663,
		"season": "autumn",
		"factions": [
			{"id": "silla", "name": "신라", "ruler": "김법민", "ruler_title": "문무왕", "commander": "김유신", "capital": "금성", "territories": "금성 · 사벌주 · 국원소경", "troops": 76000, "faction_difficulty": "보통", "strength": "나당연합과 노련한 지휘", "risk": "부흥군의 장기 저항", "description": "문무왕이 백제부흥군 진압과 고구려 전선을 함께 관리합니다.", "notable": ["김법민", "김유신", "김인문", "김흠순"], "color": "#d2a62f", "portrait_paths": ["res://assets/portraits/kim_yushin.png"], "marker_uv": Vector2(0.612, 0.586), "marker_label": "금성", "start_province": "geumseong"},
			{"id": "baekje_revival", "name": "백제부흥군", "ruler": "부여풍", "ruler_title": "풍왕", "commander": "흑치상지", "capital": "주류성", "territories": "주류성 · 임존성 일대", "troops": 34000, "faction_difficulty": "매우 어려움", "strength": "산성망과 유민의 결집", "risk": "내분과 보급 부족", "description": "왜의 지원이 도착하기 전 주류성과 임존성의 저항을 결집해야 합니다.", "notable": ["부여풍", "흑치상지", "지수신"], "color": "#8f342f", "portrait_paths": ["res://assets/portraits/heukchi_sangji.png"], "marker_uv": Vector2(0.523, 0.548), "marker_label": "주류성", "start_province": "gosa"},
			{"id": "goguryeo", "name": "고구려", "ruler": "보장왕", "commander": "연개소문", "capital": "평양성", "territories": "평양성 · 국내성 · 안시성", "troops": 92000, "faction_difficulty": "보통", "strength": "북방 산성과 군사력", "risk": "연개소문 후계 문제", "description": "백제 멸망 뒤 당의 다음 목표가 된 고구려입니다.", "notable": ["보장왕", "연개소문", "양만춘", "연남생"], "color": "#3d5f86", "portrait_paths": ["res://assets/portraits/yeon_gaesomun.png"], "marker_uv": Vector2(0.534, 0.332), "marker_label": "평양성", "start_province": "pyongyang"},
		],
		"province_overrides": {
			"ansi": {"faction": "고구려", "governor": "양만춘", "troops": 37000},
			"gungnae": {"faction": "고구려", "governor": "연남생", "troops": 24000},
			"pyongyang": {"faction": "고구려", "governor": "보장왕", "troops": 31000},
			"ungjin": {"faction": "당", "governor": "유인원", "troops": 26000, "public_order": 52},
			"sabi": {"faction": "당", "governor": "유인궤", "troops": 23000, "public_order": 42},
			"gosa": {"name": "주류성", "faction": "백제부흥군", "governor": "부여풍", "troops": 34000, "fortress": 82, "public_order": 71},
			"gukwon": {"faction": "신라", "governor": "김흠순", "troops": 21000},
			"sabeol": {"faction": "신라", "governor": "품일", "troops": 24000},
			"geumseong": {"faction": "신라", "governor": "김법민", "troops": 31000},
		},
		"officers_by_province": {
			"ansi": ["양만춘"], "gungnae": ["연남생"], "pyongyang": ["보장왕", "연개소문"],
			"ungjin": ["유인원", "예군"], "sabi": ["유인궤"], "gosa": ["부여풍", "흑치상지", "지수신"],
			"gukwon": ["김흠순"], "sabeol": ["품일"], "geumseong": ["김법민", "김유신", "김인문"],
		},
	},
	{
		"id": "silla_tang_war_670",
		"name": "670년, 나당전쟁 발발",
		"description": "문무왕의 신라, 당 고종의 점령군, 안승의 고구려부흥군이 한반도 지배권을 놓고 충돌합니다.",
		"year": 670,
		"season": "spring",
		"factions": [
			{"id": "silla", "name": "신라", "ruler": "김법민", "ruler_title": "문무왕", "commander": "김유신", "capital": "금성", "territories": "금성 · 사벌주 · 국원소경", "troops": 82000, "faction_difficulty": "어려움", "strength": "통합된 남부와 부흥군 연대", "risk": "당의 대규모 증원", "description": "옛 동맹 당을 상대로 백제 고지와 고구려 유민을 포섭해야 합니다.", "notable": ["김법민", "김유신", "김인문", "설오유", "김원술"], "color": "#d2a62f", "portrait_paths": ["res://assets/portraits/kim_yushin.png"], "marker_uv": Vector2(0.612, 0.586), "marker_label": "금성", "start_province": "geumseong"},
			{"id": "tang", "name": "당", "ruler": "당 고종", "commander": "고간", "capital": "장안", "territories": "안동도호부 · 웅진도독부", "troops": 125000, "faction_difficulty": "보통", "strength": "막대한 인력과 원정군", "risk": "긴 보급선과 유민 저항", "description": "평양과 백제 고지의 도호부를 유지하며 신라의 이탈을 진압합니다.", "notable": ["당 고종", "고간", "이근행", "설인귀", "예군"], "color": "#556b45", "portrait_paths": ["res://assets/portraits/xue_rengui.png"], "marker_uv": Vector2(0.534, 0.332), "marker_label": "안동도호부", "start_province": "pyongyang"},
			{"id": "goguryeo_revival", "name": "고구려부흥군", "ruler": "안승", "ruler_title": "고구려왕", "commander": "고연무", "capital": "금마저", "territories": "금마저 · 요동 저항성", "troops": 31000, "faction_difficulty": "매우 어려움", "strength": "유민 결집과 신라 지원", "risk": "분산된 거점과 내분", "description": "안승과 고연무가 신라와 연대하여 고구려 재건을 시도합니다.", "notable": ["안승", "고연무", "검모잠"], "color": "#516f91", "portrait_paths": ["res://assets/portraits/go_yeonmu.png"], "marker_uv": Vector2(0.535, 0.552), "marker_label": "금마저", "start_province": "gosa"},
		],
		"province_overrides": {
			"ansi": {"faction": "고구려부흥군", "governor": "고연무", "troops": 17000, "public_order": 64},
			"gungnae": {"faction": "당", "governor": "이근행", "troops": 28000, "public_order": 53},
			"pyongyang": {"faction": "당", "governor": "고간", "troops": 34000, "public_order": 45},
			"ungjin": {"faction": "당", "governor": "예군", "troops": 22000, "public_order": 48},
			"sabi": {"faction": "당", "governor": "유인궤", "troops": 19000, "public_order": 44},
			"gosa": {"name": "금마저", "faction": "고구려부흥군", "governor": "안승", "troops": 14000, "public_order": 72},
			"gukwon": {"faction": "신라", "governor": "김흠순", "troops": 24000},
			"sabeol": {"faction": "신라", "governor": "설오유", "troops": 26000},
			"geumseong": {"faction": "신라", "governor": "김법민", "troops": 32000},
		},
		"officers_by_province": {
			"ansi": ["고연무"], "gungnae": ["이근행"], "pyongyang": ["고간", "설인귀", "당 고종"],
			"ungjin": ["예군"], "sabi": ["유인궤", "유인원"], "gosa": ["안승", "검모잠"],
			"gukwon": ["김흠순"], "sabeol": ["설오유", "김원술"], "geumseong": ["김법민", "김유신", "김인문"],
		},
	},
]


static func get_scenario(scenario_id: String) -> Dictionary:
	for scenario: Dictionary in SCENARIOS:
		if str(scenario.get("id", "")) == scenario_id:
			return scenario
	return SCENARIOS[2]


static func get_scenario_by_index(index: int) -> Dictionary:
	if index < 0 or index >= SCENARIOS.size():
		return get_scenario(DEFAULT_SCENARIO_ID)
	return SCENARIOS[index]


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


static func get_officer_database() -> Dictionary:
	return OFFICERS.duplicate(true)


static func get_age_text(person_name: String, scenario_year: int) -> String:
	if not OFFICERS.has(person_name):
		return "나이 미상"
	var data: Dictionary = OFFICERS[person_name]
	var birth_year: int = int(data.get("birth_year", 0))
	if birth_year <= 0:
		return "나이 미상"
	if scenario_year < birth_year:
		return "미등장"
	return "약 %d세" % (scenario_year - birth_year)


static func get_notable_text(names_value: Variant, scenario_year: int) -> String:
	if typeof(names_value) != TYPE_ARRAY:
		return ""
	var parts: PackedStringArray = []
	var names: Array = names_value
	for name_value: Variant in names:
		var person_name: String = str(name_value)
		parts.append(
			"%s(%s)" % [person_name, get_age_text(person_name, scenario_year)]
		)
	return " · ".join(parts)


static func get_faction_name(scenario_id: String, faction_id: String) -> String:
	var faction: Dictionary = get_faction(scenario_id, faction_id)
	return str(faction.get("name", "신라"))


static func get_faction_id_by_name(
	scenario_id: String,
	faction_name: String
) -> String:
	var scenario: Dictionary = get_scenario(scenario_id)
	var faction_values: Array = scenario.get("factions", [])
	for faction_value: Variant in faction_values:
		if typeof(faction_value) != TYPE_DICTIONARY:
			continue
		var faction: Dictionary = faction_value
		if str(faction.get("name", "")) == faction_name:
			return str(faction.get("id", "silla"))
	return "silla"


static func get_starting_province(
	scenario_id: String,
	faction_id: String
) -> String:
	var faction: Dictionary = get_faction(scenario_id, faction_id)
	return str(faction.get("start_province", "geumseong"))


static func is_known_faction_name(faction_name: String) -> bool:
	for scenario: Dictionary in SCENARIOS:
		var faction_values: Array = scenario.get("factions", [])
		for faction_value: Variant in faction_values:
			if typeof(faction_value) != TYPE_DICTIONARY:
				continue
			var faction: Dictionary = faction_value
			if str(faction.get("name", "")) == faction_name:
				return true
	# 663년의 점령군처럼 선택 불가능하지만 캠페인에 존재하는 세력입니다.
	return faction_name == "당"
