# gera itens.json (valor de cada item para conferir as negociações). Rode de dentro de servidor/ sempre que mudar preços/itens no jogo.
import re,json,sys
s=open('../jogo/main.gd').read()
out={}
for name in ['DECKS','WFX','FELTS','RAILS','CUES','MONTHLY','ELITE']:
    m=re.search(r'^const '+name+r' := \[(.*?)^\]',s,re.S|re.M)
    for line in m.group(1).splitlines():
        i=re.search(r'"id": "([^"]+)"',line)
        if not i: continue
        p=re.search(r'"price": (\d+)',line); ps=re.search(r'"pass": (\d+)',line)
        v=int(p.group(1)) if p else 0
        if v==0 and ps: v=int(ps.group(1))*100
        if v>0: out[i.group(1)]=v
json.dump(out,open('itens.json','w'),indent=0,sort_keys=True)
print(len(out))
