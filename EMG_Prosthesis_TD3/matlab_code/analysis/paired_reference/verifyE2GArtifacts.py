"""Verificación independiente de aristas, coste, proyección, Bellman y artefactos."""
import csv,hashlib,json,math
from collections import defaultdict
from functools import lru_cache
from pathlib import Path
from verifyE2EArtifacts import scaled_encoder,quantize,average,close,cycle_windows
from verifyE2FArtifacts import macro,key,ACTIONS
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];OUT=HERE/'e2g_results'
def read_at(folder,name):
 with (folder/(name+'.csv')).open(encoding='utf-8-sig') as f:return list(csv.DictReader(f))
def read(name):return read_at(OUT,name)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def verify():
 history=read('historical_hashes_before')
 for r in history:assert sha((ROOT/r['path']).resolve())==r['sha256'],r['path']
 assert sha(ROOT.parent/'docs/paired_reference/PREREGISTRO_E2G.md')==(OUT/'preregistration.sha256').read_text().strip()
 edges={};nodes={};byq=defaultdict(list)
 for r in read_at(HERE/'e2f_results','graph_edges'):
  m=int(r['motor']);i=int(r['qIndex']);a=int(r['actionIndex'])-1;j=int(r['nextIndex']);q=float(r['qBefore']);dest=float(r['qAfter'])
  edges[m,i,a]=j;nodes[m,i]=(q,scaled_encoder(q,m));nodes[m,j]=(dest,scaled_encoder(dest,m))
 for (m,i),(q,h) in nodes.items():byq[m,q].append(i)
 bounds={m:(min(v[1] for (m1,i),v in nodes.items() if m1==m),max(v[1] for (m1,i),v in nodes.items() if m1==m)) for m in range(1,5)}
 original={}
 for r in read_at(HERE/'e2f_results','step_traces'):
  if r['controller']=='ORACLE_H5':original[(r['subject'],r['repetition'],r['side'],r['motor'],r['step'])]=r
 grouped=defaultdict(list);maxReward=0.;dpChecks=0
 for r in read('step_traces'):
  assert r['subject'] not in ['MATEO','SANDRA'];grouped[key(r)].append(r)
 calculated={};counts=defaultdict(int)
 for k,R in grouped.items():
  R.sort(key=lambda r:int(r['step']));controller,subject,rep,side,m=k
  q=[float(R[0]['qBefore'])]+[float(r['qAfter']) for r in R];h=[scaled_encoder(v,m) for v in q]
  pwm=[int(r['pwm']) for r in R];u=[v/255 for v in pwm];prev=0.;errors=[];rewards=[];delta=[]
  for n,r in enumerate(R):
   base=original[(r['subject'],r['repetition'],r['side'],r['motor'],r['step'])]
   for field in ['referenceBefore','referenceAfter']:
    target=float(base[field]);expected=target if controller=='ORIGINAL' else min(max(target,bounds[m][0]),bounds[m][1]);close(float(r[field]),expected,field,1e-12)
   if controller=='ORIGINAL':
    for field in ['qBefore','qAfter','rawAction','effective','pwm','rewardMotor']:close(float(r[field]),float(base[field]),'reuse '+field,1e-12)
   if n==0:close(q[0],float(base['qBefore']),'initial',1e-9)
   assert pwm[n] in ACTIONS and quantize(float(r['rawAction']))==pwm[n]
   close(float(r['qBefore']),q[n],'continuity',1e-9);close(float(r['hAfter']),h[n+1],'h',1e-12);close(float(r['effective']),u[n],'effective',1e-14)
   close(float(r['previousPwm']),prev*255,'prev',1e-10)
   err=h[n+1]-float(r['referenceAfter']);d=(u[n]-prev)**2;reward=-(err**2+.01*u[n]**2+.05*d)
   close(float(r['rewardMotor']),reward,'reward',2e-12);maxReward=max(maxReward,abs(float(r['rewardMotor'])-reward))
   a=ACTIONS.index(pwm[n]);assert any(abs(nodes[m,edges[m,i,a]][0]-q[n+1])<=1e-9 for i in byq[m,q[n]])
   if pwm[n]==0:close(q[n+1],q[n],'zero hold',1e-9)
   errors.append(err);rewards.append(reward);delta.append(d);prev=u[n]
  windows=cycle_windows(q,h,pwm);active=[i for i,v in enumerate(pwm) if v];no=sum(abs(q[i+1]-q[i])<=1e-9 for i in active)
  calculated[k]=dict(trackingMSE=average([v*v for v in errors]),MAE=average([abs(v) for v in errors]),rewardMean=average(rewards),actionL2=average([v*v for v in u]),
   deltaActionL2=average(delta),flat_response=float(max(h)-min(h)<=1e-9),action_no_motion=no/len(active) if active else math.nan,
   saturationFraction=average([float(abs(v)>=.95) for v in u]),_active=len(active),_noMotion=no)
  counts[controller,'cycles']+=int(len(R) in windows);counts[controller,'windows']+=len(windows)
  counts[controller,'m3']+=sum(m==3 and pwm[i]>0 and q[i+1]<q[i] for i in range(len(pwm)))
  if controller=='PROJECTED' and rep in [1,104] and subject in ['BLANCA','IVANNA']:
   n=len(R)//2;targets=tuple(float(r['referenceAfter']) for r in R[n:n+5]);previous=ACTIONS.index(pwm[n-1]) if n else 0
   @lru_cache(None)
   def bellman(i,p,t):
    if t==len(targets):return 0.
    return min((nodes[m,edges[m,i,a]][1]-targets[t])**2+.01*(ACTIONS[a]/255)**2+.05*((ACTIONS[a]-ACTIONS[p])/255)**2+bellman(edges[m,i,a],a,t+1) for a in range(15))
   actual=ACTIONS.index(pwm[n]);valid=False
   for i in byq[m,q[n]]:
    j=edges[m,i,actual];cost=(nodes[m,j][1]-targets[0])**2+.01*u[n]**2+.05*((pwm[n]-ACTIONS[previous])/255)**2+bellman(j,actual,1)
    valid|=abs(cost-bellman(i,previous,0))<=1e-11
   assert valid,('Bellman',k,n);dpChecks+=1
 for r in read('episode_motor_metrics'):
  for field,v in calculated[key(r)].items():
   if not field.startswith('_'):close(float(r[field]),v,field,2e-11)
 for r in read('controller_summary'):
  for field in next(iter(calculated.values())):
   if not field.startswith('_'):close(float(r[field]),macro(calculated,r['controller'],field),field,2e-11)
 reach={};reachRows=0
 for controller in ['P2_FIXED_ORIGINAL','P2_FIXED_PROJECTED','ORIGINAL','PROJECTED']:
  R=read('reachability_'+controller);acc=defaultdict(lambda:defaultdict(list));assert len(R)==176280
  for n in range(0,len(R),15):
   block=R[n:n+15];r0=block[0];m=int(r0['motor']);i=int(r0['qIndex']);target=float(r0['referenceAfter']);errors=[]
   for r,a in zip(block,range(15)):
    j=edges[m,i,a];assert int(r['pwm'])==ACTIONS[a] and int(r['nextIndex'])==j
    close(float(r['qAfter']),nodes[m,j][0],'reach destination',1e-9);err=abs(nodes[m,j][1]-target);close(float(r['absoluteError']),err,'reach error',1e-12);errors.append(err)
   best=min(errors);close(float(r0['bestOneStepError']),best,'reach min',1e-12);acc[key(r0)]['minimumReachableMSE'].append(best**2);reachRows+=15
  for k,v in acc.items():reach[k]={f:average(vals) for f,vals in v.items()}
 for r in read('reachability_summary'):close(float(r['minimumReachableMSE']),macro(reach,r['controller'],'minimumReachableMSE'),'reach macro',1e-12)
 S=json.loads((OUT/'scientific_summary.json').read_text(encoding='utf-8'))
 close(S['projectedOracleMSE'],macro(calculated,'PROJECTED','trackingMSE'),'MSE',1e-12)
 assert S['projectedFinalCycles']==counts['PROJECTED','cycles'] and S['projectedCycleWindows']==counts['PROJECTED','windows'] and S['projectedM3Reversals']==counts['PROJECTED','m3']
 tests=json.loads((OUT/'test_summary.json').read_text());assert tests['previousPassed']==169 and tests['passed']==tests['totalTests']
 assert not S['gatesBeforeTests']['A'] and not S['gatesBeforeTests']['D'] and not S['RL_PILOT_AUTHORIZED']
 artifacts=0
 if (OUT/'artifact_manifest.json').exists():
  manifest=json.loads((OUT/'artifact_manifest.json').read_text())
  for r in manifest['artifacts']:
   assert sha(OUT/r['file'])==r['sha256'],r['file'];artifacts+=1
  for r in manifest['sources']:assert sha(ROOT/r['file'])==r['sha256'],r['file']
 return dict(verified=True,historicalHashes=len(history),artifactHashes=artifacts,motorSteps=sum(map(len,grouped.values())),reachabilityDestinations=reachRows,
  bellmanIndependentChecks=dpChecks,maxRewardReconstructionError=maxReward,tests=tests['passed'],RL_PILOT_AUTHORIZED=False)
if __name__=='__main__':print(json.dumps(verify(),indent=2))
