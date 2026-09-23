"""Validate and package only south art-review evidence, outside the repository."""
import hashlib
import json
from pathlib import Path
import struct
import zipfile
from datetime import datetime

project=Path(__file__).resolve().parents[1]
folder=project/'tests/art_review/south_r3_v1'
issues=json.loads((folder/'issues.json').read_text(encoding='utf-8'))
results=json.loads((folder/'game_captures/results.json').read_text(encoding='utf-8'))
assert results['failures']==0
for row in issues['issues']:
    for suffix in ('approved','candidate','uv-review'):
        path=folder/f"{row['id']}-{suffix}.png"
        assert struct.unpack('>II',path.read_bytes()[16:24])==tuple(row['output_size'])
shots=sorted((folder/'game_captures').glob('*.png'))
assert len(shots)==64, len(shots)
for path in shots:
    width=int(path.name.split('-')[0])
    assert struct.unpack('>II',path.read_bytes()[16:24])==(width,720 if width==1280 else 1080)

files={p.name:p for p in folder.iterdir() if p.suffix in ('.png','.json','.md') and p.name not in ('handoff_manifest.json','delivery.json')}
# Representative real game captures in the transferable ZIP; all 64 stay in the project.
for path in shots:
    if ('-max-base' in path.name or '-max-uv' in path.name or any(x in path.name for x in ('boundary-after','support-production','jeju-retained'))):
        files['game_captures/'+path.name]=path
files['game_captures/results.json']=folder/'game_captures/results.json'
files['verification/SOUTH_R3_REGISTRATION_V1.md']=project/'tests/SOUTH_R3_REGISTRATION_V1.md'
files['verification/south-registration-test.log']=project/'.godot/south-registration-test.log'
root=project/'ui/korea_layout_v1/full_r3_v1'
for tile in ('detail_2_1','detail_2_2','detail_3_1','detail_3_2'):
    files['source_tiles/'+tile+'.png']=root/'assets/detail'/f'{tile}.png'
files['source_tiles/korea_approved_1254.png']=project/'ui/korea_layout_v1/assets/korea_approved_1254.png'
files['source_tiles/korean_fortress_original.png']=project/'ui/korea_layout_v1/assets/korean_fortress_original.png'
files['source_tiles/original_manifest.json']=root/'manifest.json'
manifest={'purpose':'art repair reference, NOT an installed patch; southern auto LOD remains OFF',
          'captures':'18 representative real game captures included; all 64 are in project tests/art_review/south_r3_v1/game_captures',
          'files':{name:hashlib.sha256(path.read_bytes()).hexdigest() for name,path in files.items()}}
(folder/'handoff_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
files['handoff_manifest.json']=folder/'handoff_manifest.json'
archive=Path.home()/'Downloads'/f'Samhan660_South_R3_Art_Repair_{datetime.now():%Y%m%d_%H%M%S}.zip'
with zipfile.ZipFile(archive,'x',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    for name,path in files.items():z.write(path,'Samhan660_South_R3_Art_Repair/'+name)
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    for name,path in files.items():
        assert hashlib.sha256(z.read('Samhan660_South_R3_Art_Repair/'+name)).digest()==hashlib.sha256(path.read_bytes()).digest()
delivery={'zip':str(archive),'bytes':archive.stat().st_size,'sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),
          'entries':len(files),'checked':'CRC, every entry SHA256, crop dimensions, all 64 screenshot dimensions; no extraction/replacement of source assets'}
(folder/'delivery.json').write_text(json.dumps(delivery,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(delivery,ensure_ascii=False))
