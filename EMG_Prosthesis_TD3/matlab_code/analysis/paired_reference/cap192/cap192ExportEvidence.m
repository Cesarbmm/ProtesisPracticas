function cap192ExportEvidence
here=string(fileparts(mfilename("fullpath")));pr=fileparts(here);root=fileparts(fileparts(pr));out=fullfile(pr,"cap192_results");
addpath(root,pr,fullfile(pr,"e3ax"));run=fullfile(root,"results","e3ax_long","run_20260908_141321_916_6ebf347b");
S=readtable(fullfile(out,"comparison.csv"),TextType="string",Delimiter=",");
% Figura reproducible, sin anotaciones por muestra.
f=figure(Visible="off",Color="w",Position=[50 50 1300 950]);tiledlayout(3,2,TileSpacing="compact");
fields=["trackingMSE","rewardMean","m3Reversals","boundHitFraction192","flat_response","action_no_motion"];
titles=["MSE","Reward medio","Retrocesos M3","Fraccion |PWM|=192","Respuesta plana","Accion sin movimiento"];
labels=["BEST_OFF","BEST_CAP192","LAST_OFF","LAST_CAP192"];
for k=1:6
    nexttile;Y=zeros(4,2);
    for j=1:4,for s=1:2,splits=["TRAIN","VALIDATION"];Y(j,s)=S.(fields(k))(S.controller==labels(j) & S.split==splits(s));end,end
    bar(Y);xticks(1:4);xticklabels(["BEST original","BEST CAP192","LAST original","LAST CAP192"]);xtickangle(15);
    title(titles(k));grid on;if k==1,legend("TRAIN","VALIDATION",Location="best");end
end
exportgraphics(f,fullfile(out,"comparison.png"),Resolution=150);exportgraphics(f,fullfile(out,"comparison.pdf"));savefig(f,fullfile(out,"comparison.fig"));close(f);
% Dos casos historicos E2C, todos los checkpoints/modos; mismo plotter compacto.
for label=labels
    d=load(fullfile(out,label,"trajectories.mat"),"traces","runtimeTraces");
    for subject=["BLANCA","IVANNA"]
        row=1;side=1;if subject=="IVANNA",row=104;side=2;end
        ix=find(cellfun(@(t) string(t.metadata.subject)==subject && t.metadata.repetition==row && t.metadata.side==side,d.traces));
        assert(isscalar(ix));e3axPlotEpisode(d.traces{ix},fullfile(out,"figures",label),label);
    end
    ep=10000;if startsWith(label,"LAST"),ep=20000;end
    checkpoint=fullfile(run,"checkpoints",compose("AgentEpisode%06d.mat",ep));
    file=fullfile(out,"viewer",label,"viewer_trace.mat");
    if ~isfile(file)
        v=exportE3AXViewerTrace(checkpoint,"BLANCA",1,"closing",file,cap192=endsWith(label,"CAP192"));
    else,v=load(file);end
    ix=find(cellfun(@(t) string(t.metadata.subject)=="BLANCA" && t.metadata.repetition==1 && t.metadata.side==1,d.traces));
    assert(isequal(v.q,d.runtimeTraces{ix}.q) && isequal(v.PWM,d.runtimeTraces{ix}.pwm),"CAP192:ViewerReplayMismatch","El viewer debe conservar la traza medida.");
end
e2cWriteJSON(fullfile(out,"viewer_export.json"),struct("ready",true,"files",4,"actorRuntimeReplayExact",true,"teacherLoaded",false));
end
