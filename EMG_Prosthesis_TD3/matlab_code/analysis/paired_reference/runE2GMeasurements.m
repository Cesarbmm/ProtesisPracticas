function summary=runE2GMeasurements
% Contrafactual offline de soporte: no modifica Env ni fuentes históricas.
here=string(fileparts(mfilename("fullpath")));root=fileparts(fileparts(here));out=fullfile(here,"e2g_results");
e2gVerifyHistory();[remap,cleanup]=e2cHistoricalRemapper(root); %#ok<ASGLU>
d=load(fullfile(here,"e2f_results","trajectories.mat"),"trajectories");gd=load(fullfile(here,"e2f_results","graphs.mat"),"graphs");graphs=gd.graphs;
controllers=["ORIGINAL","PROJECTED"];trajectories=cell(200,2);floorTraces=cell(200,2);
for e=1:200
    base=d.trajectories{e,2};assert(~any(contains(upper(base.metadata.subject),["MATEO","SANDRA"])));
    trajectories{e,1}=d.trajectories{e,7};trajectories{e,1}.metadata.controller="ORIGINAL";
    projected=base;projected.reference=e2gProjectReference(base.reference,graphs);
    projected.referenceBefore=e2gProjectReference(base.referenceBefore,graphs);
    trajectories{e,2}=e2fRollout(projected,5,graphs,remap);trajectories{e,2}.metadata.controller="PROJECTED";
    floorTraces{e,1}=base;floorTraces{e,1}.metadata.controller="P2_FIXED_ORIGINAL";
    floorTraces{e,2}=projected;floorTraces{e,2}.metadata.controller="P2_FIXED_PROJECTED";
    if mod(e,20)==0,fprintf("E2G H5 proyectado: %d/200 episodios.\n",e);end
end
save(fullfile(out,"trajectories.mat"),"trajectories","controllers","floorTraces","-v7.3");
metricRows={};motorRows={};tables={};periodRows={};crossRows={};supportRows={};rangeRows={};pwmRows={};cycleTables={};
for e=1:200
    base=d.trajectories{e,2};md=base.metadata;n=size(base.reference,1);
    for col=1:2
        t=trajectories{e,col};key=struct("controller",controllers(col),"subject",md.subject,"repetition",md.repetition,"side",md.side,"steps",n);
        [mot,met]=e2bControlMetrics(t);metricRows{end+1}=merge(key,met);tables{end+1}=e2fTraceTable(t); %#ok<AGROW>
        masks=e2dCycleScan(t.q,t.pwm);[ends,ms]=find(masks);
        if ~isempty(ends)
            C=table(repmat(controllers(col),numel(ends),1),repmat(md.subject,numel(ends),1),repmat(md.repetition,numel(ends),1), ...
                repmat(md.side,numel(ends),1),ms,ends,ends==n,VariableNames=["controller","subject","repetition","side","motor","endStep","terminal"]);cycleTables{end+1}=C; %#ok<AGROW>
        end
        for m=1:4
            motorRows{end+1}=merge(key,mot(m));periodRows{end+1}=merge(key,struct("motor",m,"period",e2fPeriodicTrace(t.q,t.pwm,m,false))); %#ok<AGROW>
            for pwm=graphs{m}.actions,pwmRows{end+1}=merge(key,struct("motor",m,"pwm",pwm,"count",nnz(t.pwm(:,m)==pwm)));end %#ok<AGROW>
        end
        for refCol=1:2
            target=trajectories{e,refCol}.reference;error=(t.prediction-target).^2;
            penalty=.01*t.effectiveAction.^2+.05*([t.effectiveAction(1,:);diff(t.effectiveAction)]).^2;
            for m=1:4,crossRows{end+1}=merge(key,struct("evaluationReference",controllers(refCol),"motor",m,"trackingMSE",mean(error(:,m)),"rewardMean",mean(-error(:,m)-penalty(:,m))));end %#ok<AGROW>
        end
    end
    projected=trajectories{e,2}.reference;
    for m=1:4
        g=graphs{m};lo=min(g.h);hi=max(g.h);r=base.reference(:,m);rp=projected(:,m);
        for k=1:n
            [~,nearest]=min(abs(g.h-r(k)));supportRows{end+1}=struct("subject",md.subject,"repetition",md.repetition,"side",md.side,"step",k,"motor",m, ...
                "teacher",r(k),"projected",rp(k),"change",abs(rp(k)-r(k)),"modified",abs(rp(k)-r(k))>1e-12, ...
                "hMin",lo,"hMax",hi,"below",r(k)<lo-1e-12,"above",r(k)>hi+1e-12, ...
                "bestGraphH",g.h(nearest),"signedBestError",g.h(nearest)-r(k), ...
                "p2H",base.prediction(k,m),"originalOracleH",trajectories{e,1}.prediction(k,m),"projectedOracleH",trajectories{e,2}.prediction(k,m)); %#ok<AGROW>
        end
        oldRange=max(r)-min(r);newRange=max(rp)-min(rp);ratio=NaN;if oldRange>1e-12,ratio=newRange/oldRange;end
        rangeRows{end+1}=struct("subject",md.subject,"repetition",md.repetition,"side",md.side,"motor",m,"originalRange",oldRange,"projectedRange",newRange, ...
            "rangeRatio",ratio,"originalFlat",oldRange<=1e-12,"projectedFlat",newRange<=1e-12, ...
            "originalDelta",r(end)-r(1),"projectedDelta",rp(end)-rp(1),"trendEligible",abs(r(end)-r(1))>.02, ...
            "trendRetained",sign(r(end)-r(1))==sign(rp(end)-rp(1)) && abs(rp(end)-rp(1))>1e-12); %#ok<AGROW>
    end
end
M=struct2table([metricRows{:}]);MM=struct2table([motorRows{:}]);[macro,subjects,directions,motors,groups]=e2fAggregate(M,MM);
cycles=table('Size',[0 7],'VariableTypes',{'string','string','double','double','double','double','logical'}, ...
    'VariableNames',{'controller','subject','repetition','side','motor','endStep','terminal'});
if ~isempty(cycleTables),cycles=vertcat(cycleTables{:});end
names=["episode_metrics","episode_motor_metrics","controller_summary","subject_summary","direction_summary","motor_summary","subject_side_summary", ...
    "step_traces","periodic_trajectories","cross_reference_episode_motor","support_steps","reference_variation","pwm_distribution","cycle_windows"];
values={M,MM,macro,subjects,directions,motors,groups,vertcat(tables{:}),struct2table([periodRows{:}]),struct2table([crossRows{:}]), ...
    struct2table([supportRows{:}]),struct2table([rangeRows{:}]),struct2table([pwmRows{:}]),cycles};
for j=1:numel(names),writetable(values{j},fullfile(out,names(j)+".csv"));end
allFloor=[floorTraces trajectories];e2fReachability(allFloor,graphs,out);
pairedReferencePlantManifest(plantSource="patternCurveCanonical",outputPath=fullfile(out,"plant_manifest.json"));
summary=struct("episodes",200,"stepsPerController",2938,"horizon",5,"projectionTested",true,"affineTested",false, ...
    "preregistrationSHA256",strtrim(string(fileread(fullfile(out,"preregistration.sha256")))),"RL_EXECUTED",false);
e2cWriteJSON(fullfile(out,"measurement_summary.json"),summary);e2gVerifyHistory();disp(macro(:,["controller","trackingMSE","rewardMean"]));
end
function c=merge(a,b)
c=a;for f=string(fieldnames(b))',c.(f)=b.(f);end
end
