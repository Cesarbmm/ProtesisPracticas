"""Analisis preregistrado de E3C. No entrena ni elige hiperparametros."""
import csv,json,math,random,statistics
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];OUT=ROOT/'analysis/paired_reference/e3c_results'
SEEDS=[20260912,20260913,20260914];LEVELS=[0,-64,64,-96,96,-128,128,-160,160,-192,192,-224,224,-255,255]
def read(p):
    with p.open(encoding='utf-8-sig',newline='') as f:return list(csv.DictReader(f))
def write(name,rows):
    with (OUT/name).open('w',encoding='utf-8',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
def avg(v):
    x=[float(a) for a in v if math.isfinite(float(a))];return statistics.mean(x) if x else math.nan
def percentile(v,q):
    v=sorted(v);x=(len(v)-1)*q;k=int(x);return v[k]+(v[min(k+1,len(v)-1)]-v[k])*(x-k)
def select(rows,**criteria):
    r=[r for r in rows if all(str(r[k])==str(v) for k,v in criteria.items())];assert len(r)==1,(criteria,len(r));return r[0]
def gates(F,G,shuffled,counts):
    mf=lambda key:avg(r[key] for r in F);mg=lambda key:avg(r[key] for r in G);ms=lambda key:avg(r[key] for r in shuffled)
    result={
        'A_macroF1_gain_3pp':mg('macroF1')-mf('macroF1')>=.03,
        'B_NLL_reduction_5pct':mg('NLL')<=.95*mf('NLL'),
        'C_opening_MSE_reduction_5pct':mg('openingMSE')<=.95*mf('openingMSE'),
        'D_opening_flat_reduction_5pp':mg('openingFlat')<=mf('openingFlat')-.05,
        'E_closing_MSE_no_worse_5pct':mg('closingMSE')<=1.05*mf('closingMSE'),
        'F_cycles_and_periodicity':all(c['cycles']==0 and c['periodic']==0 for c in counts['GRU']),
        'F_M3_no_material_increase':sum(c['m3Reversals'] for c in counts['GRU'])<=sum(c['m3Reversals'] for c in counts['FF'])+1 and all(g['m3Reversals']<=f['m3Reversals']+1 for f,g in zip(counts['FF'],counts['GRU'])),
        'F_no_global_category_collapse':all(c['maxCategoryFraction']<=.90 for c in counts['GRU']),
        'G_order_shuffle_loses_gain':mg('macroF1')-ms('macroF1')>=.01 and ms('NLL')>=1.01*mg('NLL') and sum(float(s['macroF1'])<float(g['macroF1']) and float(s['NLL'])>float(g['NLL']) for s,g in zip(shuffled,G))>=2,
        'paired_seed_consistency':sum(g['macroF1']>f['macroF1'] for f,g in zip(F,G))>=2 and sum(g['NLL']<f['NLL'] for f,g in zip(F,G))>=2 and sum(g['openingMSE']<f['openingMSE'] for f,g in zip(F,G))>=2,
    };return result
def main():
    im=[];phase=[];closed=[];distributions=[];counts={'FF':[],'GRU':[]};scores={'FF':[],'GRU':[]};shuffled=[];episodes={}
    for seed in SEEDS:
        for kind in ['FF','GRU']:
            folder=OUT/f'{kind}_{seed}';assert (folder/'EVALUATION_COMPLETED.json').exists()
            I=read(folder/'imitation_metrics.csv');im += [dict(kind=kind,seed=seed,control='ordered',**r) for r in I]
            phase += [dict(kind=kind,seed=seed,**r) for r in read(folder/'phase_metrics.csv')]
            if kind=='GRU':
                Sh=read(folder/'shuffled_imitation_metrics.csv');im += [dict(kind=kind,seed=seed,control='shuffled',**r) for r in Sh]
                v=select(Sh,split='VALIDATION',dimension='all',motor='0');shuffled.append({k:float(v[k]) for k in ['macroF1','NLL']})
            C=read(folder/'categorical_episode_motor.csv')
            for split in ['TRAIN','VALIDATION']:
                for dim,filename,idfield in [('all','summary',None),('direction','directions','side'),('subject','subjects','subject'),('motor','motors','motor')]:
                    for r in read(folder/f'{split}_{filename}.csv'):
                        value=r[idfield] if idfield else 'ALL';cat=[c for c in C if c['split']==split and (not idfield or c[idfield]==value)]
                        catmax=[]
                        for motor in range(1,5):
                            a=[c for c in cat if int(c['motor'])==motor]
                            if not a:continue
                            n=sum(int(c['steps']) for c in a);cnt=[sum(int(c[f'category{j}']) for c in a) for j in range(1,16)];assert sum(cnt)==n
                            catmax.append(max(cnt)/n)
                            for j in range(15):
                                distributions.append(dict(kind=kind,seed=seed,split=split,dimension=dim,value=value,motor=motor,category=j+1,PWM=LEVELS[j],count=cnt[j],fraction=cnt[j]/n,headEntropy=sum(float(c['entropy'])*int(c['steps']) for c in a)/n))
                        metrics={k:float(r[k]) for k in ['trackingMSE','rewardMean','MAE','correlation','actionL2','deltaActionL2','flat_response','action_no_motion','saturationFraction','trackingTerm','actionPenalty','deltaActionPenalty']}
                        summary=dict(kind=kind,seed=seed,split=split,dimension=dim,value=value,**metrics,
                                     cycles=sum(int(c['cycles']) for c in cat),cycleWindows=sum(int(c['cycleWindows']) for c in cat),periodic=sum(int(c['periodic']) for c in cat),m3Reversals=sum(int(c['m3Reversals']) for c in cat),maxCategoryFraction=max(catmax))
                        closed.append(summary)
            globalrow=select(closed,kind=kind,seed=seed,split='VALIDATION',dimension='all');opening=select(closed,kind=kind,seed=seed,split='VALIDATION',dimension='direction',value='2');closing=select(closed,kind=kind,seed=seed,split='VALIDATION',dimension='direction',value='1')
            counts[kind].append(globalrow);v=select(I,split='VALIDATION',dimension='all',motor='0')
            score=dict(kind=kind,seed=seed,macroF1=float(v['macroF1']),NLL=float(v['NLL']),accuracy=float(v['accuracy']),jointExact=float(v['jointExact']),MSE=globalrow['trackingMSE'],openingMSE=opening['trackingMSE'],openingFlat=opening['flat_response'],openingNoMotion=opening['action_no_motion'],closingMSE=closing['trackingMSE'])
            scores[kind].append(score)
            episodes[kind,seed]={(r['subject'],r['repetition'],r['side']):r for r in read(folder/'episode_metrics.csv') if r['subject'] in ['JOE','JONATHAN','KHAROL']}
    gate=gates(scores['FF'],scores['GRU'],shuffled,counts);write('gates.csv',[dict(gate=k,passGate=v) for k,v in gate.items()])
    write('imitation_all.csv',im);write('phase_all.csv',phase);write('closed_loop_all.csv',closed);write('pwm_distributions.csv',distributions);write('by_seed.csv',scores['FF']+scores['GRU'])
    keys=sorted(episodes['FF',SEEDS[0]]);paired=[]
    for k in keys:
        row=dict(subject=k[0],row=k[1],side=k[2]);
        for metric in ['trackingMSE','flat_response']:
            f=avg(episodes['FF',s][k][metric] for s in SEEDS);g=avg(episodes['GRU',s][k][metric] for s in SEEDS)
            row[metric+'_FF']=f;row[metric+'_GRU']=g;row[metric+'_diff']=g-f
        paired.append(row)
    write('paired_episode_differences.csv',paired);bootstrap={};draws=[];rng=random.Random(20260922)
    for group in ['VALIDATION','OPENING']:
        rows=paired if group=='VALIDATION' else [r for r in paired if r['side']=='2'];N=len(rows);vals={m:[] for m in ['trackingMSE','flat_response']}
        for b in range(5000):
            ix=[rng.randrange(N) for _ in range(N)];row=dict(group=group,replicate=b+1)
            for m in vals:
                v=sum(rows[j][m+'_diff'] for j in ix)/N;vals[m].append(v);row[m+'_diff']=v
            draws.append(row)
        bootstrap[group]={m:dict(meanDifference=avg(r[m+'_diff'] for r in rows),CI95=[percentile(v,.025),percentile(v,.975)],episodes=N) for m,v in vals.items()}
    write('bootstrap_draws.csv',draws)
    meanScore=lambda kind,key:avg(r[key] for r in scores[kind])
    result=dict(E3B_RESULT='CAT_LEARNING_SIGNAL',seeds=SEEDS,FF_ORACLE_MACRO_F1=meanScore('FF','macroF1'),GRU_ORACLE_MACRO_F1=meanScore('GRU','macroF1'),
        MACRO_F1_GAIN_PP=100*(meanScore('GRU','macroF1')-meanScore('FF','macroF1')),FF_ORACLE_NLL=meanScore('FF','NLL'),GRU_ORACLE_NLL=meanScore('GRU','NLL'),
        NLL_CHANGE_PCT=100*(meanScore('GRU','NLL')/meanScore('FF','NLL')-1),SHUFFLED_HISTORY_MACRO_F1=avg(r['macroF1'] for r in shuffled),SHUFFLED_HISTORY_NLL=avg(r['NLL'] for r in shuffled),
        FF_CLOSED_LOOP_VALIDATION_MSE=meanScore('FF','MSE'),GRU_CLOSED_LOOP_VALIDATION_MSE=meanScore('GRU','MSE'),
        FF_OPENING_MSE=meanScore('FF','openingMSE'),GRU_OPENING_MSE=meanScore('GRU','openingMSE'),FF_OPENING_FLAT_RESPONSE=meanScore('FF','openingFlat'),GRU_OPENING_FLAT_RESPONSE=meanScore('GRU','openingFlat'),
        FF_OPENING_ACTION_NO_MOTION=meanScore('FF','openingNoMotion'),GRU_OPENING_ACTION_NO_MOTION=meanScore('GRU','openingNoMotion'),FF_CLOSING_MSE=meanScore('FF','closingMSE'),GRU_CLOSING_MSE=meanScore('GRU','closingMSE'),
        GRU_M3_REVERSALS=[r['m3Reversals'] for r in counts['GRU']],GRU_CYCLES=[r['cycles'] for r in counts['GRU']],GRU_MAX_CATEGORY_FRACTION=[r['maxCategoryFraction'] for r in counts['GRU']],
        TEMPORAL_INFORMATION_SUPPORTED=all(gate.values()),E3C_RESULT='TEMPORAL_INFORMATION_SUPPORTED' if all(gate.values()) else 'TEMPORAL_INFORMATION_NOT_DEMONSTRATED',gates=gate,bootstrap=bootstrap,
        E3D_LONG_TRAINING_STARTED=False,MATEO_SANDRA_SEALED=True,REFERENCE_CONTRACT_VALIDATED=False,HARDWARE_AUTHORIZED=False,GIT_REPAIR_ATTEMPTED=False,PUSH=False)
    (OUT/'scientific_summary.json').write_text(json.dumps(result,indent=2),encoding='utf-8');print(json.dumps(result,indent=2))
if __name__=='__main__':main()
