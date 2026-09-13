"""Distribuciones/gates E2G. Python estándar, sin abrir datasets ni históricos."""
import csv,itertools,json,math
from collections import defaultdict
from pathlib import Path
from verifyE2EArtifacts import scaled_encoder,average
HERE=Path(__file__).resolve().parent
OUT=HERE/'e2g_results'
def read(name):
 with (OUT/(name+'.csv')).open(encoding='utf-8-sig') as f:return list(csv.DictReader(f))
def write(name,rows):
 with (OUT/(name+'.csv')).open('w',newline='',encoding='utf-8') as f:
  w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
def num(x):return float(x)
def quantile(v,p):
 v=sorted(v);x=(len(v)-1)*p;i=int(x);return v[i]+(v[min(i+1,len(v)-1)]-v[i])*(x-i)
def stats(v):
 return dict(zip(['minimum','p1','p5','median','p95','p99','maximum'],[quantile(v,p) for p in [0,.01,.05,.5,.95,.99,1]]))
def macro(rows,field):
 episodes=defaultdict(list)
 for r in rows:episodes[(r['subject'],r['repetition'],r['side'],r['motor'])].append(float(r[field]))
 groups=defaultdict(list)
 for (s,e,d,m),v in episodes.items():groups[(s,d,m)].append(average(v))
 return average([average(v) for v in groups.values()])
def groups(rows):
 for n in range(4):
  for dims in itertools.combinations(['motor','subject','side'],n):
   grouped=defaultdict(list)
   for r in rows:grouped[tuple(r[d] for d in dims)].append(r)
   for key,v in sorted(grouped.items()):
    metadata={'motor':'ALL','subject':'ALL','side':'ALL'};metadata.update(dict(zip(dims,key)))
    yield metadata,v
def run():
 S=read('support_steps');dist=[];summaries=[]
 for key,R in groups(S):
  for field in ['teacher','projected','p2H','originalOracleH','projectedOracleH']:
   dist.append(dict(**key,signal=field,samples=len(R),**stats([num(r[field]) for r in R])))
  outside=macro(R,'below')+macro(R,'above');changes=[num(r['change']) for r in R]
  summaries.append(dict(**key,samples=len(R),below=macro(R,'below'),inside=1-outside,above=macro(R,'above'),outside=outside,
   modifiedFractionMacro=macro(R,'modified'),modifiedFractionSteps=average([num(r['modified']) for r in R]),
   meanChangeMacro=macro(R,'change'),meanChangeSteps=average(changes),p95Change=quantile(changes,.95),maxChange=max(changes)))
 write('coordinate_distributions',dist);write('support_and_transformation',summaries)
 hs=defaultdict(dict)
 with (HERE/'e2f_results/graph_edges.csv').open(encoding='utf-8-sig') as f:
  for r in csv.DictReader(f):hs[r['motor']][r['qHex']]=scaled_encoder(num(r['qBefore']),int(r['motor']))
 envelopes=[dict(motor=m,uniqueQStates=len(v),uniqueHValues=len(set(v.values())),**stats(list(v.values()))) for m,v in sorted(hs.items())]
 write('graph_h_distributions',envelopes)
 V=read('reference_variation');var=[]
 for key,R in groups(V):
  ratios=[num(r['rangeRatio']) for r in R if math.isfinite(num(r['rangeRatio']))]
  eligible=[r for r in R if num(r['trendEligible'])];retained=average([num(r['trendRetained']) for r in eligible]) if eligible else float('nan')
  var.append(dict(**key,episodeMotors=len(R),originalRangeMean=macro(R,'originalRange'),projectedRangeMean=macro(R,'projectedRange'),
   medianRangeRatio=quantile(ratios,.5) if ratios else float('nan'),originalFlatFraction=average([num(r['originalFlat']) for r in R]),
   projectedFlatFraction=average([num(r['projectedFlat']) for r in R]),flatIncreasePP=100*average([num(r['projectedFlat'])-num(r['originalFlat']) for r in R]),
   trendEligible=len(eligible),trendRetainedFraction=retained))
 write('variation_summary',var)
 X=read('cross_reference_episode_motor');cross=[]
 for policy,ref in itertools.product(['ORIGINAL','PROJECTED'],repeat=2):
  R=[r for r in X if r['controller']==policy and r['evaluationReference']==ref]
  for key,items in groups(R):cross.append(dict(controller=policy,evaluationReference=ref,**key,trackingMSE=macro(items,'trackingMSE'),rewardMean=macro(items,'rewardMean')))
 write('cross_reference_summary',cross)
 all_summary=next(r for r in summaries if r['motor']==r['subject']==r['side']=='ALL')
 controller={r['controller']:r for r in read('controller_summary')};reach={r['controller']:r for r in read('reachability_summary')}
 M=read('episode_metrics');T=read('step_traces');P=read('periodic_trajectories');C=read('cycle_windows');F=read('fixed_summary')
 m3=sum(r['controller']=='PROJECTED' and r['motor']=='3' and num(r['pwm'])>0 and num(r['qAfter'])<num(r['qBefore']) for r in T)
 zero_motion=sum(r['controller']=='PROJECTED' and num(r['pwm'])==0 and abs(num(r['qAfter'])-num(r['qBefore']))>1e-9 for r in T)
 cycles=sum(num(r['persistentTwoCycle']) for r in M if r['controller']=='PROJECTED')
 periods=sum(num(r['period'])>0 for r in P if r['controller']=='PROJECTED')
 fixed=[r for r in F if r['controller']=='PROJECTED']
 fixed_periods=sum(num(r['period'])>0 for r in fixed);fixed_cycles=sum(num(r['terminalCycle']) for r in fixed);fixed_hold=sum(num(r['last20Hold']) for r in fixed)
 original_bound=macro([dict(r,bound=num(r['change'])**2) for r in S],'bound')
 projected_outside=sum(not(num(r['hMin'])-1e-12<=num(r['projected'])<=num(r['hMax'])+1e-12) for r in S)
 vd=[r for r in var if r['subject']=='ALL' and r['motor']!='ALL' and r['side']!='ALL']
 variation_pass=all(r['medianRangeRatio']>=.5 and r['flatIncreasePP']<=5+1e-12 and (not r['trendEligible'] or r['trendRetainedFraction']>=.95) for r in vd)
 evidence=json.loads((OUT/'coordinate_evidence.json').read_text(encoding='utf-8'))
 gateA=all(x['pairedPhysicalCalibrationDemonstrated'] for x in evidence['motors'])
 gateB=projected_outside==0 # bound=0 exactamente: validación numérica, no calibración.
 gateC=cycles==0 and periods==0 and m3==0 and zero_motion==0 and fixed_periods==0 and fixed_cycles==0 and fixed_hold==20
 summary=dict(supportMismatchCause='MIXED',physicalCalibrationDemonstrated=gateA,projectionTested=True,affineAlignmentTested=False,
  selectedTransformation='NONE_FOR_TRAINING; PROJECTION_DIAGNOSTIC_ONLY',outsideMacro=all_summary['outside'],outsideByMotor={r['motor']:r['outside'] for r in summaries if r['motor']!='ALL' and r['subject']==r['side']=='ALL'},
  transformedSampleFractionMacro=all_summary['modifiedFractionMacro'],transformedSampleFractionSteps=all_summary['modifiedFractionSteps'],
  transformedMeanChange=all_summary['meanChangeMacro'],transformedP95Change=all_summary['p95Change'],transformedMaxChange=all_summary['maxChange'],
  originalOracleMSE=num(controller['ORIGINAL']['trackingMSE']),projectedOracleMSE=num(controller['PROJECTED']['trackingMSE']),
  originalOracleReward=num(controller['ORIGINAL']['rewardMean']),projectedOracleReward=num(controller['PROJECTED']['rewardMean']),
  originalFloorP2Fixed=num(reach['P2_FIXED_ORIGINAL']['minimumReachableMSE']),projectedFloorP2Fixed=num(reach['P2_FIXED_PROJECTED']['minimumReachableMSE']),
  originalFloorOracleVisited=num(reach['ORIGINAL']['minimumReachableMSE']),projectedFloorOracleVisited=num(reach['PROJECTED']['minimumReachableMSE']),
  originalOutsideBoundMSE=original_bound,projectedOutsideBoundMSE=0 if projected_outside==0 else None,
  originalTargetsOutsideSupport=all_summary['outside'],projectedTargetsOutsideSupport=projected_outside/len(S),
  projectedFinalCycles=cycles,projectedCycleWindows=sum(r['controller']=='PROJECTED' for r in C),projectedPeriodicTrajectories=periods,
  projectedM3Reversals=m3,zeroMotionFailures=zero_motion,fixedCycles=fixed_cycles,fixedPeriods=fixed_periods,fixedStable=fixed_hold,
  gatesBeforeTests=dict(A=gateA,B=gateB,C=gateC,D=variation_pass),result='REFERENCE_CONTRACT_NOT_VALIDATED' if not all([gateA,gateB,gateC,variation_pass]) else 'PENDING_TESTS',
  RL_PILOT_AUTHORIZED=False,E3A_PREPARED=False,E3A_EXECUTED=False)
 (OUT/'scientific_summary.json').write_text(json.dumps(summary,indent=2,ensure_ascii=False)+'\n',encoding='utf-8');print(json.dumps(summary,indent=2))
if __name__=='__main__':run()
