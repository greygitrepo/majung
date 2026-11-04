import json,sys,collections
d=json.load(open(sys.argv[1]))
print(len(d))
h=[r for r in d if '노숙' in (r.get('MLSV_TRGET') or '')]
print(len(h))
c=collections.Counter(r['RDNMADR'].split()[0] if r['RDNMADR'] else r['LNMADR'].split()[0] for r in h)
print(c)
for i,r in enumerate(h):
  print(i,'|',r['FCLTY_NM'],'|',r['RDNMADR'] or r['LNMADR'],'|',r['MLSV_PLACE'],'|',r['MLSV_DATE'],'|',r['MLSV_TIME'],'|',r['PHONE_NUMBER'],'|',r['OPER_INSTITUTION_NM'],'|',r['INSTT_NM'],'|',r['REFERENCE_DATE'],'|',r['OPER_CLOSE_DATE'],'|',r['MLSV_TRGET'])
