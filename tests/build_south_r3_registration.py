"""Reproducible review-only UV correction; does not edit artwork or city data."""
import hashlib
import json
import math
from pathlib import Path
import zipfile

PROJECT = Path(__file__).resolve().parents[1]
ROOT = PROJECT / 'ui/korea_layout_v1/full_r3_v1'
OUT = PROJECT / 'tests/art_review/south_r3_v1'
OUT.mkdir(parents=True, exist_ok=True)
# Manual corresponding features, in the two equal-sized 1254px diagnostic crops.
# These correspondences constrain position only, never river topology or sprite clearance.
POINTS = [
    ('north_confluence', (153, 420), (142, 400)),
    ('west_bend', (129, 620), (127, 592)),
    ('west_confluence', (80, 774), (75, 735)),
    ('daegaya_east_tributary', (135, 879), (137, 810)),
    ('lower_tributary', (116, 923), (134, 844)),
    ('estuary_main_channel', (224, 1190), (222, 1120)),
    ('east_cape', (774, 730), (747, 698)),
    ('east_cape_inner_bay', (722, 754), (706, 722)),
    ('east_coast_upper', (730, 439), (705, 408)),
    ('east_coast_mid', (730, 577), (701, 551)),
    ('east_coast_lower', (710, 1014), (683, 957)),
    ('south_inlet', (484, 1116), (475, 1058)),
]
landmarks = []
for name, a, b in POINTS:
    native = lambda p: [600 + v * 354 / 1254 for v in p]
    landmarks.append(dict(id=name, approved_native=native(a), candidate_native=native(b),
                          confidence='manual approximate correspondence; not topology approval'))

def mapped(x, y):
    dx = dy = 0.0
    weight = 1 / 80**2  # Identity regularizer; the displayed tile rectangle stays fixed.
    for point in landmarks:
        a, b = point['approved_native'], point['candidate_native']
        dist2 = (x-a[0])**2 + (y-a[1])**2
        w = 1 / max(dist2, .000001)
        dx += w * (b[0]-a[0]); dy += w * (b[1]-a[1]); weight += w
    # Prevent sampling beyond each texture axis; permit tangential edge movement.
    # Pinning both axes at a side would visibly stretch a shifted river near that edge.
    tx = min(1, max(0, min(x-600, 954-x) / 12))
    ty = min(1, max(0, min(y-600, 954-y) / 12))
    return x + dx/weight*tx*tx*(3-2*tx), y + dy/weight*ty*ty*(3-2*ty)

vertices = []
for y in range(600, 955, 3):
    for x in range(600, 955, 3):
        sx, sy = mapped(x, y)
        vertices.append([x, y, (sx-600)/354, (sy-600)/354, 1])

def cross(a, b, c):
    return (b[2]-a[2])*(c[3]-a[3]) - (b[3]-a[3])*(c[2]-a[2])

folds = 0
for y in range(118):
    for x in range(118):
        i = y*119+x
        a,b,c,d = (vertices[j] for j in (i,i+1,i+119,i+120))
        folds += cross(a,b,c) <= 0 or cross(b,d,c) <= 0
assert folds == 0, f'{folds} folded cells; do not install'

def mesh_sample(x, y):
    gx,gy = (x-600)/3, (y-600)/3
    ix,iy = min(117,int(gx)),min(117,int(gy)); fx,fy=gx-ix,gy-iy
    i=iy*119+ix
    corners = [vertices[j] for j in (i,i+1,i+119,i+120)]
    weights = [1-fx-fy,fx,fy,0] if fx+fy<=1 else [0,1-fy,1-fx,fx+fy-1]
    return [600 + 354*sum(w*v[k] for w,v in zip(weights,corners)) for k in (2,3)]
for point in landmarks:
    result = mesh_sample(*point['approved_native'])
    point['mesh_residual_native_px'] = math.dist(result, point['candidate_native'])
data = dict(tile='detail_2_2', source_sha256=hashlib.sha256((ROOT/'assets/detail/detail_2_2.png').read_bytes()).hexdigest(),
            region=[600,600,354,354], grid=[119,119], vertices=vertices, folded_cells=folds,
            status='review_only_requires_art_repair', automatic_lod_enabled=False, landmarks=landmarks,
            note='UV only. No feather, tint, sprite relocation or topology claim. Fixed display rectangle; tangential edge UV movement. Adjacent redraws still need art repair.')
(ROOT/'south_registration_review.json').write_text(json.dumps(data,ensure_ascii=False),encoding='utf-8')
(OUT/'uv_landmarks.json').write_text(json.dumps({k:v for k,v in data.items() if k!='vertices'},ensure_ascii=False,indent=2),encoding='utf-8')

# Inspect repackaged archives in place; never extract/reapply their files.
local = {hashlib.sha256(p.read_bytes()).hexdigest():p.name for p in (ROOT/'assets').rglob('*.png')}
archives=[]
for archive in sorted((Path.home()/'Downloads').glob('Samhan660_R3_Assets_Part*.zip')):
    rows=[]
    with zipfile.ZipFile(archive) as z:
        for item in z.infolist():
            if item.filename.lower().endswith('.png'):
                digest=hashlib.sha256(z.read(item)).hexdigest()
                rows.append(dict(member=item.filename,sha256=digest,matching_local=local.get(digest)))
    archives.append(dict(archive=str(archive),pngs=rows))
(OUT/'repack_audit.json').write_text(json.dumps(archives,ensure_ascii=False,indent=2),encoding='utf-8')
print('South review mesh:',len(vertices),'vertices,',folds,'folds; max landmark residual',max(p['mesh_residual_native_px'] for p in landmarks))
print('Repack archives inspected in place:',len(archives))
