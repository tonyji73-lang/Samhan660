"""Build a proposed inland-only alpha mesh, not an approval or edited artwork."""
import json, math
from pathlib import Path
root=Path(__file__).resolve().parents[1]/'ui/korea_layout_v1/south_v3'
# Inland forest/ridge contour around the two clearings. Excludes western river,
# Daegaya, east coast, estuary and every outer patch seam. Reviewed separately.
polygon=[(670,790),(697,780),(733,783),(763,800),(776,818),(772,840),(754,847),(724,840),(689,835),(671,827)]
def inside(x,y):
    yes=False
    for a,b in zip(polygon,polygon[1:]+polygon[:1]):
        if (a[1]>y)!=(b[1]>y) and x<(b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0]:yes=not yes
    return yes
def distance(p,a,b):
    dx,dy=b[0]-a[0],b[1]-a[1]
    t=max(0,min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dy)/(dx*dx+dy*dy)))
    return math.hypot(p[0]-a[0]-t*dx,p[1]-a[1]-t*dy)
vertices=[]
for y in range(740,1001,2):
    for x in range(560,861,2):
        d=min(distance((x,y),a,b) for a,b in zip(polygon,polygon[1:]+polygon[:1])) if inside(x,y) else 0
        t=min(1,d/4); alpha=t*t*(3-2*t)
        vertices.append([x,y,(x-560)/300,(y-740)/260,alpha])
data={'region':[560,740,300,260],'grid':[151,131],'vertices':vertices,'folded_cells':0,'polygon_native':polygon,'transition_native_px':4,
      'scope':'Dalgubeol/Geumseong inland clearings and intervening forest/ridge only; no river/coast/Daegaya/outer edge approval','uv':'identity; vertex alpha only'}
(root/'inland_registration.json').write_text(json.dumps(data,separators=(',',':')),encoding='utf-8')
print('Proposed inland mesh',len(vertices),'vertices; registration approval unchanged')
