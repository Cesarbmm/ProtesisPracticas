"""Verificación independiente CSV/Bellman; FAIL científico no es fallo de integridad."""
import csv,hashlib,json,math
from collections import defaultdict
from functools import lru_cache
from pathlib import Path
from verifyE2EArtifacts import scaled_encoder,quantize,average,close,cycle_windows
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];OUT=HERE/'e2f_results'
ACTIONS=[0,-64,64,-96,96,-128,128,-160,160,-192,192,-224,224,-255,255]
def read(name):
 with (OUT/(name+'.csv')).open(encoding='utf-8-sig') as f:return list(csv.DictReader(f))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def key(r):return (r['controller'],r['subject'],int(r['repetition']),int(r['side']),int(r['motor']))
def macro(items,controller,field):
 if field=='action_no_motion':
  episodes=defaultdict(lambda:[0,0]);groups=defaultdict(list)
  for k,r in items.items():
   if k[0]==controller:
    pair=episodes[k[1:4]];pair[0]+=r['_noMotion'];pair[1]+=r['_active']
  for (s,e,d),(no,active) in episodes.items():groups[s,d].append(no/active if active else math.nan)
  return average([average(v) for v in groups.values()])
 groups=defaultdict(list)
 for k,r in items.items():
  if k[0]==controller:groups[(k[1],k[3],k[4])].append(r[field])
 return average([average(v) for v in groups.values()])
def verify():
 history=read('historical_hashes_before')
 for r in history:
  assert 'sandbox' not in r['path'].lower();assert sha((ROOT/r['path']).resolve())==r['sha256'],r['path']
 assert sha(ROOT.parent/'docs/paired_reference/PREREGISTRO_E2F.md')==(OUT/'preregistration.sha256').read_text().strip()
 edges={};nodes={};byq=defaultdict(list)
 for r in read('graph_edges'):
  m=int(r['motor']);i=int(r['qIndex']);a=int(r['actionIndex'])-1;j=int(r['nextIndex']);q=float(r['qBefore']);dest=float(r['qAfter'])
  assert int(r['pwm'])==ACTIONS[a];edges[m,i,a]=j;nodes[m,i]=(q,scaled_encoder(q,m));nodes[m,j]=(dest,scaled_encoder(dest,m))
  close(float(r['hAfter']),scaled_encoder(dest,m),'graph h',1e-12)
  close(float(r['deltaQ']),dest-q,'graph delta',2e-9)
 for (m,i),(q,h) in nodes.items():
  byq[m,q].append(i)
  for a in range(15):assert (m,edges[m,i,a]) in nodes
 groups=defaultdict(list)
 for r in read('step_traces'):
  assert r['subject'] not in {'MATEO','SANDRA'};groups[key(r)].append(r)
 calculated={};counts=defaultdict(int);maxReward=0.;dpChecks=0
 for k,R in groups.items():
  R.sort(key=lambda r:int(r['step']));controller,subject,rep,side,m=k
  q=[float(R[0]['qBefore'])]+[float(r['qAfter']) for r in R];h=[scaled_encoder(v,m) for v in q]
  pwm=[int(r['pwm']) for r in R];u=[v/255 for v in pwm];prev=0.;errors=[];rewards=[];delta=[]
  for n,r in enumerate(R):
   assert int(r['step'])==n+1;assert pwm[n] in ACTIONS;assert quantize(float(r['rawAction']))==pwm[n]
   close(float(r['qBefore']),q[n],'continuity',1e-9);close(float(r['hAfter']),h[n+1],'h',1e-12)
   close(float(r['previousPwm']),prev*255,'previous',1e-10);close(float(r['effective']),u[n],'action',1e-14)
   err=h[n+1]-float(r['referenceAfter']);d=(u[n]-prev)**2;reward=-(err**2+.01*u[n]**2+.05*d)
   maxReward=max(maxReward,abs(reward-float(r['rewardMotor'])));close(float(r['rewardMotor']),reward,'reward',2e-12)
   indices=byq[m,q[n]];a=ACTIONS.index(pwm[n]);assert any(abs(nodes[m,edges[m,i,a]][0]-q[n+1])<=1e-9 for i in indices)
   if pwm[n]==0:close(q[n+1],q[n],'zero hold',1e-9)
   errors.append(err);rewards.append(reward);delta.append(d);prev=u[n]
  windows=cycle_windows(q,h,pwm);active=[i for i,v in enumerate(pwm) if v];nomotion=sum(abs(q[i+1]-q[i])<=1e-9 for i in active)
  calculated[k]=dict(trackingMSE=average([v*v for v in errors]),MAE=average([abs(v) for v in errors]),rewardMean=average(rewards),
   actionL2=average([v*v for v in u]),deltaActionL2=average(delta),flat_response=float(max(h)-min(h)<=1e-9),
   action_no_motion=nomotion/len(active) if active else math.nan,saturationFraction=average([float(abs(v)>=.95) for v in u]),_active=len(active),_noMotion=nomotion)
  counts[controller,'cycles']+=int(len(R) in windows);counts[controller,'windows']+=len(windows)
  counts[controller,'m3']+=sum(m==3 and pwm[i]>0 and q[i+1]<q[i] for i in range(len(pwm)))
  # Comprobación recursiva independiente de valor óptimo, sin código MATLAB.
  if controller.startswith('ORACLE_') and rep in [1,104] and subject in ['BLANCA','IVANNA']:
   H=int(controller[-1]);n=len(R)//2;targets=tuple(float(r['referenceAfter']) for r in R[n:n+H]);previous=ACTIONS.index(pwm[n-1]) if n else 0
   @lru_cache(None)
   def bellman(i,p,t):
    if t==len(targets):return 0.
    return min((nodes[m,edges[m,i,a]][1]-targets[t])**2+.01*(ACTIONS[a]/255)**2+.05*((ACTIONS[a]-ACTIONS[p])/255)**2+
     bellman(edges[m,i,a],a,t+1) for a in range(15))
   actual=ACTIONS.index(pwm[n]);valid=False
   for i in byq[m,q[n]]:
    j=edges[m,i,actual];actualCost=(nodes[m,j][1]-targets[0])**2+.01*(pwm[n]/255)**2+.05*((pwm[n]-ACTIONS[previous])/255)**2+bellman(j,actual,1)
    valid|=abs(actualCost-bellman(i,previous,0))<=1e-11
   assert valid,('Bellman',k,n);dpChecks+=1
 for r in read('episode_motor_metrics'):
  expected=calculated[key(r)]
  for field,v in expected.items():
   if not field.startswith('_'):close(float(r[field]),v,field,2e-11)
 for r in read('controller_summary'):
  for field in next(iter(calculated.values())):
   if not field.startswith('_'):close(float(r[field]),macro(calculated,r['controller'],field),'macro '+field,2e-11)
 reach={};reachRows=0
 for controller in {k[0] for k in groups}:
  R=read('reachability_'+controller);assert len(R)%15==0;aggregates=defaultdict(lambda:defaultdict(list))
  for n in range(0,len(R),15):
   block=R[n:n+15];errors=[];r0=block[0];m=int(r0['motor']);i=int(r0['qIndex']);target=float(r0['referenceAfter']);current=abs(nodes[m,i][1]-target)
   for r,a in zip(block,range(15)):
    j=edges[m,i,a];assert int(r['pwm'])==ACTIONS[a];assert int(r['nextIndex'])==j
    close(float(r['qAfter']),nodes[m,j][0],'reach endpoint',1e-9);err=abs(nodes[m,j][1]-target);close(float(r['absoluteError']),err,'reach error',1e-12);errors.append(err)
   best=min(errors);close(float(r0['bestOneStepError']),best,'reach min',1e-12);assert best<=current+1e-12
   g=aggregates[key(r0)];g['minimumReachableError'].append(best);g['minimumReachableMSE'].append(best**2)
   g['reachableTargetFraction'].append(float(best<current-1e-12));g['within005Fraction'].append(float(best<=.05));reachRows+=15
  for k,fields in aggregates.items():reach[k]={f:average(v) for f,v in fields.items()}
 for r in read('reachability_summary'):
  for field in next(iter(reach.values())):close(float(r[field]),macro(reach,r['controller'],field),'reach macro',2e-11)
 fixed=defaultdict(list)
 for r in read('fixed_reference_traces'):fixed[tuple(int(r[f]) for f in ['horizon','caseId','referenceIndex','initialStateIndex'])].append(r)
 fixedStats={}
 for k,R in fixed.items():
  R.sort(key=lambda r:int(r['step']));m=k[1]+2;Q=[float(r['qBefore']) for r in R[-32:]];P=[int(r['previousPwm']) for r in R[-32:]]
  h=[scaled_encoder(q,m) for q in Q];period=0
  if max(h)-min(h)>.05:
   for p in range(2,9):
    if all(abs(Q[i]-Q[i+p])<=1e-9 and P[i]==P[i+p] for i in range(32-p)):period=p;break
  fixedStats[k]=period
 for r in read('fixed_reference_summary'):
  k=tuple(int(r[f]) for f in ['horizon','caseId','referenceIndex','initialStateIndex']);assert int(r['period'])==fixedStats[k]
 g=json.loads((OUT/'primary_gates.json').read_text());P=macro(calculated,'P_2','trackingMSE');O=macro(calculated,'ORACLE_H5','trackingMSE')
 close(g['mseImprovementPct'],100*(P-O)/P,'improvement',1e-9)
 floor=macro(reach,'P_2','minimumReachableMSE')/P;close(g['p2OneStepFloorRatio'],floor,'floor')
 assert g['pass3']==(floor<=.5+1e-12);assert g['finalCycles']==counts['ORACLE_H5','cycles'];assert g['m3Reversals']==counts['ORACLE_H5','m3']
 tests=json.loads((OUT/'test_summary.json').read_text());assert tests['previousPassed']==144 and tests['passed']==tests['totalTests']
 manifest=OUT/'artifact_manifest.json';artifacts=0
 if manifest.exists():
  for r in json.loads(manifest.read_text())['artifacts']:
   p=OUT/r['file'];assert sha(p)==r['sha256'],str(p);artifacts+=1
 return dict(verified=True,historicalHashes=len(history),artifactHashes=artifacts,graphEdges=len(edges),motorSteps=sum(map(len,groups.values())),
  reachabilityDestinations=reachRows,bellmanIndependentChecks=dpChecks,maxRewardReconstructionError=maxReward,
  primaryFinalCycles=counts['ORACLE_H5','cycles'],primaryFixedCycles=sum(p>0 for k,p in fixedStats.items() if k[0]==5),
  oneStepFloorRatio=floor,tests=tests['passed'],RL_PILOT_AUTHORIZED=bool(g['measuredGatesPass']))
if __name__=='__main__':print(json.dumps(verify(),indent=2))
