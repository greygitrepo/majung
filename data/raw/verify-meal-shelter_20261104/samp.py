import json,sys,random,collections
d=json.load(open(sys.argv[1]))
prev=set(x.strip() for x in open(sys.argv[2]).read().split('|')[3::4]) if False else None
prev=set(l.split('|')[3].strip() for l in open(sys.argv[2]))
def sido(r):
  a=(r['RDNMADR'] or r['LNMADR'] or '').split()
  return a[0] if a else '?'
el=[]
for i,r in enumerate(d):
  if '노숙' in (r.get('MLSV_TRGET') or ''): continue
  if r['OPER_CLOSE_DATE']: continue
  if '중단' in r['MLSV_DATE']+r['MLSV_TIME'] or '종료' in r['MLSV_DATE']+r['MLSV_TIME']: continue
  if r['REFERENCE_DATE']<'2025-11-04': continue
  if r['FCLTY_NM'].strip() in prev: continue
  el.append((i,r))
print('eligible',len(el), collections.Counter(sido(r) for i,r in el))
rng=random.Random(20261104); rng.shuffle(el)
cnt=collections.Counter(); out=[]
for i,r in el:
  s=sido(r)
  if cnt[s]>=2: continue
  cnt[s]+=1; out.append((i,r))
  if len(out)==30: break
for n,(i,r) in enumerate(out,1):
  print(f"R{n:02d} | row{i} | {sido(r)} | {r['FCLTY_NM']} | {r['RDNMADR'] or r['LNMADR']} | {r['MLSV_PLACE']} | {r['MLSV_DATE']} | {r['MLSV_TIME']} | {r['PHONE_NUMBER']} | {r['OPER_INSTITUTION_NM']} | {r['INSTT_NM']} | {r['REFERENCE_DATE']} | {r['MLSV_TRGET']}")
