function summary=e3bFinalEvaluation(out,cfg,data,records)
e2cWriteJSON(fullfile(out,"POST_TRAINING_STATUS.json"),struct("status","RUNNING","trainingExecuted",false));
R=struct2table(records);R=sortrows(R,["mse","reward","steps"],["ascend","descend","ascend"]);best=R(1,:);last=R(R.steps==max(R.steps),:);
fprintf("TEST COMPORTAMENTAL: BEST/LAST categoricos, figuras por episodio de TRAIN y VALIDATION.\n");
be=e3bEvaluate(best.checkpoint,data.evaluation,fullfile(out,"evaluation","best_checkpoint"),"BEST_CATEGORICAL",true);
le=e3bEvaluate(last.checkpoint,data.evaluation,fullfile(out,"evaluation","last_checkpoint"),"LAST_CATEGORICAL",true);
I=e3axCheckEvaluationFiles(out);writetable(I,fullfile(out,"evaluation","episode_figure_index.csv"));
html=["<!doctype html><html lang='es'><meta charset='utf-8'><title>E3B evaluacion</title><style>body{font:16px system-ui;margin:30px;max-width:1300px}td,th{padding:8px;border:1px solid #ddd}table{border-collapse:collapse}img{max-width:100%}</style>"; ...
    "<h1>Evaluacion PPO multicategorico "+cfg.mode+"</h1><p>Referencia ORIGINAL no validada. MATEO/SANDRA sellados.</p>"; ...
    "<p>BEST: "+best.steps+" pasos. LAST: "+last.steps+" pasos. Cada episodio tiene una figura con cuatro motores.</p>"; ...
    "<p><a href='evaluation/best_checkpoint/comparison/VALIDATION/metrics.csv'>Comparacion BEST VALIDATION</a> | <a href='evaluation/last_checkpoint/comparison/VALIDATION/metrics.csv'>Comparacion LAST VALIDATION</a></p>"; ...
    "<img src='evaluation/best_checkpoint/comparison/VALIDATION/comparison.png'>"; ...
    "<img src='evaluation/best_checkpoint/categorical_summary.png'>"; ...
    "<table><tr><th>Checkpoint</th><th>Split</th><th>Sujeto</th><th>Fila</th><th>Direccion</th><th>MSE</th><th>Figuras</th></tr>"];
for k=1:height(I)
    x=I(k,:);html(end+1)="<tr><td>"+x.checkpoint+"</td><td>"+x.split+"</td><td>"+x.subject+"</td><td>"+x.row+"</td><td>"+x.direction+"</td><td>"+sprintf("%.6f",x.trackingMSE)+"</td><td><a href='"+x.png+"'>PNG</a> | <a href='"+x.fig+"'>FIG</a></td></tr>";
end
html(end+1)="</table></html>";file=fullfile(out,"TEST_COMPORTAMENTAL.html");f=fopen(file,'w','n','UTF-8');assert(f>=0);fprintf(f,'%s',join(html,newline));fclose(f);
first=data.evaluation{1}.base.metadata;directions=["closing","opening"];
for cp=[best.checkpoint,last.checkpoint]
    kind="best_checkpoint";if cp==last.checkpoint && best.checkpoint~=last.checkpoint,kind="last_checkpoint";end
    dest=fullfile(out,"evaluation",kind,"viewer_trace.mat");if ~isfile(dest),exportE3AXViewerTrace(cp,string(first.subject),first.repetition,directions(first.side),dest);end
end
% Si BEST==LAST, ambos directorios siguen teniendo evidencia independiente.
lastViewer=fullfile(out,"evaluation","last_checkpoint","viewer_trace.mat");
if ~isfile(lastViewer),copyfile(fullfile(out,"evaluation","best_checkpoint","viewer_trace.mat"),lastViewer);end
summary=struct("bestCheckpoint",best.checkpoint,"bestSteps",best.steps,"lastCheckpoint",last.checkpoint,"lastSteps",last.steps, ...
    "bestEvaluation",be,"lastEvaluation",le,"classification",e3bClassify(R,cfg),"pngCount",height(I),"figCount",height(I), ...
    "episodeCountPerCheckpoint",numel(data.evaluation),"report",file,"MATEO_SANDRA_SEALED",true);
e2cWriteJSON(fullfile(out,"evaluation","final_summary.json"),summary);
e2cWriteJSON(fullfile(out,"POST_TRAINING_STATUS.json"),struct("status","COMPLETE","report",file,"figurePairs",height(I)));
end
