"""Gates E3D congelados; ninguna seleccion por VALIDATION."""
import csv,json,math,statistics
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];OUT=ROOT/'analysis/paired_reference/e3d_results'
SEEDS=[20260923,20260924,20260925];KINDS=['BASELINE','TEMPORAL_EMG'];LEVELS=[0,-64,64,-96,96,-128,128,-160,160,-192,192,-224,224,-255,255]
def read(p):
    with p.open(encoding='utf-8-sig',newline='') as f:return list(csv.DictReader(f))
def write(name,rows):
    with (OUT/name).open('w',encoding='utf-8',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
def avg(v):
    x=[float(a) for a in v if math.isfinite(float(a))];return statistics.mean(x) if x else math.nan
def select(rows,**criteria):
    r=[r for r in rows if all(str(r[k])==str(v) for k,v in criteria.items())];assert len(r)==1,(criteria,len(r));return r[0]
def gates(A,B,S):
    a=lambda k:avg(r[k] for r in A);b=lambda k:avg(r[k] for r in B);s=lambda k:avg(r[k] for r in S)
    return {
        'A_direction_gain_3pp':b('directionF1')>=a('directionF1')+.03,
        'B_phase_direction_gain_5pp':b('phaseDirectionF1')>=a('phaseDirectionF1')+.05,
        'C_order_gain_2pp':b('phaseDirectionF1')>=s('phaseDirectionF1')+.02,
        'D_opening_MSE_reduction_10pct':b('openingMSE')<=.90*a('openingMSE'),
        'E_closing_MSE_no_worse_5pct':b('closingMSE')<=1.05*a('closingMSE'),
        'F_global_MSE_improves':b('MSE')<a('MSE'),
        'G_zero_final_cycles_periodicity':b('cycles')==0 and b('periodic')==0,
        'H_M3_no_material_increase':sum(r['m3Reversals'] for r in B)<=sum(r['m3Reversals'] for r in A)+1,
        'I_max_category_fraction':b('maxCategoryFraction')<=.90,
    }
def main():
    closed=[];distributions=[];intent=[];imitation=[];scores={k:[] for k in KINDS};shuffled=[]
    for seed in SEEDS:
        for kind in KINDS:
            folder=OUT/f'{kind}_{seed}';assert (folder/'EVALUATION_COMPLETED.json').exists()
            I=read(folder/'imitation_metrics.csv');intentRows=read(folder/'intent_metrics.csv')
            imitation += [dict(kind=kind,seed=seed,control='ordered',**r) for r in I]
            intent += [dict(kind=kind,seed=seed,control='ordered',**r) for r in intentRows]
            if kind=='TEMPORAL_EMG':
                sh=read(folder/'shuffled_intent_metrics.csv');shI=read(folder/'shuffled_imitation_metrics.csv')
                intent += [dict(kind=kind,seed=seed,control='shuffled',**r) for r in sh]
                imitation += [dict(kind=kind,seed=seed,control='shuffled',**r) for r in shI]
                v=select(shI,split='VALIDATION',dimension='all',motor='0')
                shuffled.append(dict(seed=seed,directionF1=float(select(sh,split='VALIDATION',subject='ALL',task='direction')['macroF1']),
                    phaseDirectionF1=float(select(sh,split='VALIDATION',subject='ALL',task='phase_direction')['macroF1']),oracleF1=float(v['macroF1']),oracleNLL=float(v['NLL'])))
            C=read(folder/'categorical_episode_motor.csv')
            for split in ['TRAIN','VALIDATION']:
                for dim,filename,idfield in [('all','summary',None),('direction','directions','side'),('subject','subjects','subject'),('motor','motors','motor')]:
                    for r in read(folder/f'{split}_{filename}.csv'):
                        value=r[idfield] if idfield else 'ALL';cat=[c for c in C if c['split']==split and (not idfield or c[idfield]==value)]
                        catmax=[];zeros=0;total=0
                        for motor in range(1,5):
                            a=[c for c in cat if int(c['motor'])==motor]
                            if not a:continue
                            n=sum(int(c['steps']) for c in a);cnt=[sum(int(c[f'category{j}']) for c in a) for j in range(1,16)];assert sum(cnt)==n
                            catmax.append(max(cnt)/n);zeros+=cnt[0];total+=n
                            for j in range(15):
                                distributions.append(dict(kind=kind,seed=seed,split=split,dimension=dim,value=value,motor=motor,category=j+1,PWM=LEVELS[j],count=cnt[j],fraction=cnt[j]/n,headEntropy=sum(float(c['entropy'])*int(c['steps']) for c in a)/n))
                        metrics={k:float(r[k]) for k in ['trackingMSE','rewardMean','MAE','correlation','actionL2','deltaActionL2','flat_response','action_no_motion','saturationFraction','trackingTerm','actionPenalty','deltaActionPenalty']}
                        closed.append(dict(kind=kind,seed=seed,split=split,dimension=dim,value=value,**metrics,PWM0Fraction=zeros/total,
                            cycles=sum(int(c['cycles']) for c in cat),cycleWindows=sum(int(c['cycleWindows']) for c in cat),periodic=sum(int(c['periodic']) for c in cat),
                            m3Reversals=sum(int(c['m3Reversals']) for c in cat),maxCategoryFraction=max(catmax)))
            glob=select(closed,kind=kind,seed=seed,split='VALIDATION',dimension='all')
            opening=select(closed,kind=kind,seed=seed,split='VALIDATION',dimension='direction',value='2');closing=select(closed,kind=kind,seed=seed,split='VALIDATION',dimension='direction',value='1')
            v=select(I,split='VALIDATION',dimension='all',motor='0')
            score=dict(kind=kind,seed=seed,directionF1=float(select(intentRows,split='VALIDATION',subject='ALL',task='direction')['macroF1']),
                phaseDirectionF1=float(select(intentRows,split='VALIDATION',subject='ALL',task='phase_direction')['macroF1']),
                oracleF1=float(v['macroF1']),oracleNLL=float(v['NLL']),MSE=glob['trackingMSE'],openingMSE=opening['trackingMSE'],closingMSE=closing['trackingMSE'],
                reward=glob['rewardMean'],flat=glob['flat_response'],PWM0Fraction=glob['PWM0Fraction'],actionNoMotion=glob['action_no_motion'],
                openingFlat=opening['flat_response'],openingNoMotion=opening['action_no_motion'],openingCorrelation=opening['correlation'],
                cycles=glob['cycles'],periodic=glob['periodic'],m3Reversals=glob['m3Reversals'],maxCategoryFraction=glob['maxCategoryFraction'])
            scores[kind].append(score)
    gate=gates(scores['BASELINE'],scores['TEMPORAL_EMG'],shuffled)
    write('gates.csv',[dict(gate=k,passGate=v) for k,v in gate.items()])
    write('by_seed.csv',sum(scores.values(),[]));write('shuffled_by_seed.csv',shuffled)
    write('intent_all.csv',intent);write('imitation_all.csv',imitation);write('closed_loop_all.csv',closed);write('pwm_distributions.csv',distributions)
    means={kind:{k:avg(r[k] for r in seq) for k in seq[0] if k not in ['kind','seed']} for kind,seq in scores.items()}
    A=means['BASELINE'];B=means['TEMPORAL_EMG'];S={k:avg(r[k] for r in shuffled) for k in shuffled[0] if k!='seed'}
    E3B={'MSE':.0574389061274616,'openingMSE':.0565534616657263,'closingMSE':.0583243505891969}
    result=dict(E3C_RESULT='TEMPORAL_INFORMATION_NOT_DEMONSTRATED',E3B_RESULT='CAT_LEARNING_SIGNAL',seeds=SEEDS,means=means,shuffled=S,bySeed=scores,gates=gate,
        DIRECTION_GAIN_PP=100*(B['directionF1']-A['directionF1']),PHASE_DIRECTION_GAIN_PP=100*(B['phaseDirectionF1']-A['phaseDirectionF1']),
        ORDER_GAIN_PP=100*(B['phaseDirectionF1']-S['phaseDirectionF1']),E3B_BEST=E3B,
        GLOBAL_GAP_TO_E3B=B['MSE']-E3B['MSE'],OPENING_GAP_TO_E3B=B['openingMSE']-E3B['openingMSE'],CLOSING_GAP_TO_E3B=B['closingMSE']-E3B['closingMSE'],
        TEMPORAL_EMG_CONTEXT_SUPPORTED=all(gate.values()),E3D_RESULT='TEMPORAL_EMG_CONTEXT_SUPPORTED' if all(gate.values()) else 'TEMPORAL_EMG_CONTEXT_NOT_SUPPORTED',
        E3E_PREPARED=False,E3E_TRAINING_EXECUTED=False,MATEO_SANDRA_SEALED=True,REFERENCE_CONTRACT_VALIDATED=False,HARDWARE_AUTHORIZED=False,GIT_REPAIR_ATTEMPTED=False,PUSH=False)
    (OUT/'scientific_summary.json').write_text(json.dumps(result,indent=2,allow_nan=False),encoding='utf-8')
    print(json.dumps(result,indent=2,allow_nan=False))
if __name__=='__main__':main()
