extends SceneTree
## Read-only master catalog exporter. JSON is authoritative; CSV/HTML are generated views.
func _initialize() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/officers_v1.json"))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/portraits/fictional_20261008/manifest.json"))
	var csv := FileAccess.open("res://data/officer_roster.csv",FileAccess.WRITE)
	csv.store_buffer(PackedByteArray([239,187,191]))
	csv.store_csv_line(PackedStringArray(["ID","이름","구분","무관·문관","업무 역할","성별","대표 나이","키(cm)","체중(kg)","체형","연도별 소속·지역","초상 파일","시트 칸(0부터)","인물 출처·성격"]))
	var records: Dictionary = data.definitions.duplicate(true)
	for scenario: Dictionary in data.scenarios.values():
		for row: Dictionary in scenario.entries:
			if not records.has(row.officer_id):
				records[row.officer_id] = data.definitions[row.catalog_id].duplicate(true)
				records[row.officer_id].display_name = row.display_name
	for id: String in records:
		var d: Dictionary = records[id]
		var appearances: Dictionary = d.get("appearance",{})
		var assignments: Array[String] = []
		for scenario: Dictionary in data.scenarios.values():
			for row: Dictionary in scenario.entries:
				if row.officer_id == id: assignments.append("%d %s:%s" % [scenario.year,scenario.factions[row.faction_id],row.location if not row.location.is_empty() else "현재 명령 지도 밖/미배치"])
		csv.store_csv_line(PackedStringArray([id,d.display_name,d.origin,d.get("character_type",""),d.get("role",""),d.get("gender","unknown"),str(appearances.get("portrait_age","")),str(appearances.get("height_cm","")),str(appearances.get("weight_kg","")),appearances.get("body_type","")," / ".join(assignments),d.get("portrait",{}).get("atlas","기존 이름별 초상 연결"),str(d.get("portrait",{}).get("cell","")),d.get("identity_source","")]))
	var html := "<!doctype html><html lang='ko'><meta charset='utf-8'><meta name='viewport' content='width=device-width'><title>가상 장수 초상 라이브러리</title><style>body{margin:32px;background:#fcfaf5;color:#173035;font:16px sans-serif}input{padding:12px;width:440px;max-width:90%}main{display:grid;grid-template-columns:repeat(auto-fill,minmax(210px,1fr));gap:20px;margin-top:24px}article{border:1px solid #d3cdbf;padding:12px;border-radius:6px}.portrait{aspect-ratio:1;background-size:400% 400%;background-repeat:no-repeat;background-color:#ddd}p{font-size:14px;line-height:1.6}small{overflow-wrap:anywhere}a{color:#bf4d13}</style><h1>가상 장수 초상 라이브러리</h1><p>190명 · 여성 76 / 남성 114 · 무관 95 / 문관 95 · 살집 있는 체형 19명(10%). 외형·체중·성별·능력은 가상 설정이며 역사적 사실이 아닙니다. 나이는 첫 등장 연도의 대표 설정입니다.</p><p>원본 명부: <a href='../../../data/officers_v1.json'>officers_v1.json</a> · 전체 명단: <a href='../../../data/officer_roster.csv'>officer_roster.csv</a> · 생성 이미지 자체는 수정하지 않고 4×4 아틀라스의 각 칸을 개별 초상으로 연결합니다.</p><input aria-label='장수 검색' placeholder='이름·세력·성별·무관·문관 검색' oninput=\"document.querySelectorAll('article').forEach(x=>x.hidden=!x.textContent.toLowerCase().includes(this.value.toLowerCase()))\"><main>"
	for row: Dictionary in manifest.generated_portraits:
		var a: Dictionary = row.appearance
		var gender := "여성" if a.gender == "female" else "남성"
		var image_path: String = str(row.file).get_file()
		var cell: int = row.cell
		html += "<article><div class='portrait' role='img' aria-label='%s 초상' style='background-image:url(%s);background-position:%.5f%% %.5f%%'></div><h3>%s</h3><p>%s · %s · %s · %s<br>%d세 · %dcm · %dkg<br>%s</p><small>%s</small></article>" % [row.name,image_path,float(cell%4)/3.0*100.0,float(cell/4)/3.0*100.0,row.name,row.culture,row.character_type,row.role,gender,a.portrait_age,a.height_cm,a.weight_kg,"살집 있는 체형" if a.overweight else a.body_type,row.id]
	html += "</main></html>"
	html = html.replace("\\\"","\"")
	var f := FileAccess.open("res://assets/portraits/fictional_20261008/index.html",FileAccess.WRITE)
	f.store_string(html)
	print("EXPORTED ",records.size()," master/scenario identities and ",manifest.generated_portraits.size()," portraits")
	quit()