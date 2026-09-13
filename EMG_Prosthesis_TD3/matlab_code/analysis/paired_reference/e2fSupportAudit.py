"""Diagnóstico explicativo posterior al gate congelado, sin cambiar decisiones."""
import bisect,csv,json,math
from collections import defaultdict
from pathlib import Path
from verifyE2EArtifacts import scaled_encoder,average
HERE=Path(__file__).resolve().parent
OUT=HERE/'e2f_results'

def read(name):
 with (OUT/(name+'.csv')).open(encoding='utf-8-sig') as f:return list(csv.DictReader(f))
def write(name,rows):
 with (OUT/(name+'.csv')).open('w',newline='',encoding='utf-8') as f:
  w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
def macro(rows,field):
 episodes=defaultdict(list)
 for r in rows:episodes[(r['subject'],r['repetition'],r['side'],r['motor'])].append(r[field])
 groups=defaultdict(list)
 for (s,e,d,m),v in episodes.items():groups[(s,d,m)].append(average(v))
 return average([average(v) for v in groups.values()])
def quantile(v,p):
 v=sorted(v);x=(len(v)-1)*p;i=int(x);return v[i]+(v[min(i+1,len(v)-1)]-v[i])*(x-i)
def run():
 hs=defaultdict(set)
 for r in read('graph_edges'):
  m=int(r['motor']);hs[m].add(scaled_encoder(float(r['qBefore']),m))
 hs={m:sorted(v) for m,v in hs.items()};rows=[]
 for r in read('reachability_P_2'):
  if float(r['pwm'])!=0:continue
  m=int(r['motor']);ref=float(r['referenceAfter']);v=hs[m];j=bisect.bisect_left(v,ref)
  nearest=min(abs(v[i]-ref) for i in {max(0,j-1),min(len(v)-1,j)})
  outside=max(v[0]-ref,ref-v[-1],0);best=float(r['bestOneStepError'])
  rows.append(dict(subject=r['subject'],repetition=int(r['repetition']),side=int(r['side']),motor=m,step=int(r['step']),
   teacher=ref,graphHMin=v[0],graphHMax=v[-1],outsideEnvelope=int(outside>1e-12),below=int(ref<v[0]-1e-12),above=int(ref>v[-1]+1e-12),
   outsideEnvelopeMSE=outside**2,globalGraphMinimumMSE=nearest**2,oneStepMinimumMSE=best**2))
 write('support_step_diagnostic',rows)
 summary=[]
 for motor in range(5):
  R=rows if motor==0 else [r for r in rows if r['motor']==motor]
  row=dict(motor=motor,steps=len(R))
  for field in ['outsideEnvelope','below','above','outsideEnvelopeMSE','globalGraphMinimumMSE','oneStepMinimumMSE']:row[field]=macro(R,field)
  row['outsideShareOfOneStepFloor']=row['outsideEnvelopeMSE']/row['oneStepMinimumMSE'];summary.append(row)
 write('support_summary_diagnostic',summary)
 distributions=[]
 for controller in ['ZERO','P_2','AGENT7250','ORACLE_H1','ORACLE_H2','ORACLE_H3','ORACLE_H5']:
  A=[r for r in read('reachability_'+controller) if float(r['pwm'])==0]
  for motor,side in [(0,0)]+[(m,0) for m in range(1,5)]+[(0,s) for s in [1,2]]:
   R=[r for r in A if (not motor or int(r['motor'])==motor) and (not side or int(r['side'])==side)]
   v=[float(r['bestOneStepError']) for r in R]
   distributions.append(dict(controller=controller,motor=motor,side=side,steps=len(v),minimum=min(v),p50=quantile(v,.5),
    p90=quantile(v,.9),p95=quantile(v,.95),maximum=max(v),stepWeightedMean=average(v)))
 write('reachability_error_distribution',distributions)
 print(json.dumps(summary,indent=2))
if __name__=='__main__':run()
