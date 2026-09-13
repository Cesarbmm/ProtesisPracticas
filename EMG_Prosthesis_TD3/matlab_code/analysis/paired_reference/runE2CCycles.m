function summary=runE2CCycles(options)
% Analisis causal OFFLINE; nunca train, dataset de sujetos ni cambios de planta.
arguments
    options.outputDir (1,1) string = ""
end
here=string(fileparts(mfilename("fullpath")));root=fileparts(fileparts(here));
out=options.outputDir;if out=="",out=fullfile(here,"e2c_results");end
if ~isfolder(out),mkdir(out);end
prereg=fullfile(fileparts(root),"docs","paired_reference","PREREGISTRO_E2C.md");
assert(e2cSHA256(prereg)=="bddb7f8f45b6e6e9cbceb45f3c082c2d1a1694b60ed2de3bb1ec3ca1a46d4013");
had=isappdata(0,"configurables_override");old=struct();if had,old=getappdata(0,"configurables_override");end
restore=onCleanup(@() restoreOverride(old,had)); %#ok<NASGU>
setConfigurablesOverride(struct("run_training",false,"flagSaveTraining",false,"plotEpisodeOnTest",false));
[remap,mapCleanup]=e2cHistoricalRemapper(root); %#ok<ASGLU>
s=load(fullfile(here,"e2b_results","trajectories.mat"),"trajectories");
subjects=["BLANCA","IVANNA"];reps=[1 104];sides=[1 2];motors=[3 4];
rows={};localRows={};betweenRows={};boundaryRows={};fixedRows={};fixedSummary={};caseSummary={};orbitRows={};
maxQError=0;maxActionError=0;maxRewardError=0;
for c=1:2
    trace=[];
    for k=1:numel(s.trajectories)
        t=s.trajectories{k};m=t.metadata;
        if m.subject==subjects(c) && m.repetition==reps(c) && m.side==sides(c) && m.controller=="P_2"
            trace=t;break
        end
    end
    assert(~isempty(trace));n=size(trace.pwm,1);motor=motors(c);first=n-3;
    qReplay=trace.q(1,:);prev=zeros(1,4);
    for k=1:n
        before=h(qReplay);err=trace.referenceBefore(k,:)-before;
        raw=max(-1,min(1,2*err));[effective,pwm]=remap(raw);effective=effective';pwm=pwm';
        next=SimController.prosthesis_simulator(qReplay,pwm,.2,.14,plantSource="patternCurveCanonical");
        after=h(next);tracking=-(after-trace.reference(k,:)).^2;
        ap=.01*effective.^2;dp=.05*(effective-prev).^2;rw=tracking-ap-dp;
        maxQError=max(maxQError,max(abs(next-trace.q(k+1,:))));
        maxActionError=max(maxActionError,max(abs(raw-trace.rawAction(k,:))));
        maxRewardError=max(maxRewardError,abs(mean(rw)-trace.reward(k)));
        assert(isequal(pwm,trace.pwm(k,:)));
        for j=1:4
            rows{end+1}=struct("caseId",c,"subject",subjects(c),"repetition",reps(c), ...
                "side",sides(c),"step",k,"motor",j,"cycleWindow",k>=first && j==motor, ...
                "referenceBefore",trace.referenceBefore(k,j),"referenceAfter",trace.reference(k,j), ...
                "hBefore",before(j),"trackingErrorBefore",err(j),"raw",raw(j), ...
                "effective",effective(j),"pwm",pwm(j),"quantizationError",effective(j)-raw(j), ...
                "qBefore",qReplay(j),"qAfter",next(j),"deltaQ",next(j)-qReplay(j), ...
                "trackingTermMotor",tracking(j),"actionPenaltyMotor",ap(j), ...
                "deltaActionPenaltyMotor",dp(j),"rewardMotor",rw(j), ...
                "trackingTermEpisode",mean(tracking),"actionPenaltyEpisode",mean(ap), ...
                "deltaActionPenaltyEpisode",mean(dp),"rewardEpisode",mean(rw)); %#ok<AGROW>
        end
        qReplay=next;prev=effective;
    end
    refs=trace.referenceBefore(first:end,motor);pair=trace.q(first:first+1,motor);
    % Intervalo teacher que conserva exactamente los dos PWM observados.
    rLow=-Inf;rHigh=Inf;loIncluded=true;hiIncluded=true;
    for stateIndex=1:2
        command=trace.pwm(first+stateIndex-1,motor);levels=[64 96 128 160 192 224 255];
        index=find(levels==abs(command));
        if index==1,a=.05;ain=true;else,a=(levels(index-1)+levels(index))/510;ain=false;end
        if index==7,b=Inf;else,b=(levels(index)+levels(index+1))/510;end
        pred=hMotor(pair(stateIndex),motor);
        if command>0,lower=pred+a/2;upper=pred+b/2;lowerIn=ain;upperIn=true;
        else,lower=pred-b/2;upper=pred-a/2;lowerIn=true;upperIn=ain;end
        if lower>rLow,rLow=lower;loIncluded=lowerIn;elseif lower==rLow,loIncluded=loIncluded&&lowerIn;end
        if upper<rHigh,rHigh=upper;hiIncluded=upperIn;elseif upper==rHigh,hiIncluded=hiIncluded&&upperIn;end
    end
    orbitRows{end+1}=struct("caseId",c,"lowerReference",rLow,"upperReference",rHigh, ...
        "lowerIncluded",loIncluded,"upperIncluded",hiIncluded,"nonempty",rHigh>rLow); %#ok<AGROW>
    offsets=[-128 -64 -16 -1 0 1 16 64 128];
    for k=first:n
        for dq=offsets
            q=trace.q(k,motor)+dq;
            for dr=linspace(-.04,.04,81)
                r=trace.referenceBefore(k,motor)+dr;
                value=oneStep(q,r,motor,remap);
                localRows{end+1}=withMetadata(value,c,k,dq,dr); %#ok<AGROW>
            end
        end
    end
    for q=linspace(min(pair),max(pair),1001)
        betweenRows{end+1}=withMetadata(oneStep(q,refs(1),motor,remap),c,0,NaN,NaN); %#ok<AGROW>
    end
    % Todas las fronteras reales firmadas. El salto de signo no es +224 a -64.
    positive=[.05 ([64 96 128 160 192 224]+[96 128 160 192 224 255])/2/255];
    boundaries=sort([-positive positive]);boundaryCrosses=false;
    for stateIndex=1:2
        q=pair(stateIndex);pred=hMotor(q,motor);
        for b=boundaries
            r=pred+b/2;
            low=oneStep(q,r-5e-11,motor,remap);exact=oneStep(q,r,motor,remap);high=oneStep(q,r+5e-11,motor,remap);
            crosses=(hMotor(low.qNext,motor)-r)*(hMotor(high.qNext,motor)-r)<0;
            boundaryCrosses=boundaryCrosses || crosses;
            boundaryRows{end+1}=struct("caseId",c,"stateIndex",stateIndex,"q",q, ...
                "rawBoundary",b,"errorBoundary",b/2,"referenceBoundary",r, ...
                "pwmBelow",low.pwm,"pwmAt",exact.pwm,"pwmAbove",high.pwm, ...
                "pwmJump",high.pwm-low.pwm,"qNextBelow",low.qNext,"qNextAbove",high.qNext, ...
                "qNextJump",high.qNext-low.qNext,"crossesTeacher",crosses); %#ok<AGROW>
        end
    end
    fixedRefs=[refs;mean(refs)];primaryPersists=true;allPersists=true;anyOrbit=false;primaryOvershoot=true;
    for rIndex=1:5
        r=fixedRefs(rIndex);
        for stateIndex=1:2
            q=pair(stateIndex);qs=q;us=[];
            for k=1:100
                value=oneStep(q,r,motor,remap);qs(end+1,1)=value.qNext;us(end+1,1)=value.pwm; %#ok<AGROW>
                fixedRows{end+1}=struct("caseId",c,"referenceIndex",rIndex,"initialStateIndex",stateIndex, ...
                    "step",k,"reference",r,"qBefore",q,"hBefore",value.hBefore,"raw",value.raw, ...
                    "effective",value.effective,"pwm",value.pwm,"qAfter",value.qNext); %#ok<AGROW>
                q=value.qNext;
            end
            tail=qs(end-20:end);tailU=us(end-19:end);
            orbit=max(abs(tail(1:end-2)-tail(3:end)))<1e-9 && ...
                abs(hMotor(tail(end),motor)-hMotor(tail(end-1),motor))>.05 && ...
                all(tailU(1:end-1).*tailU(2:end)<0);
            originalPair=orbit && all(min(abs(tail-pair'),[],2)<1e-9);
            over=all((hMotor(tail(1:end-1),motor)-r).*(hMotor(tail(2:end),motor)-r)<0);
            allPersists=allPersists && originalPair;anyOrbit=anyOrbit || orbit;
            if rIndex==1,primaryPersists=primaryPersists && originalPair;primaryOvershoot=primaryOvershoot && over;end
            fixedSummary{end+1}=struct("caseId",c,"referenceIndex",rIndex,"reference",r, ...
                "initialStateIndex",stateIndex,"originalPairPersists",originalPair,"anyTwoCycle",orbit, ...
                "overshootEachStep",over,"lastQ",qs(end),"previousQ",qs(end-1)); %#ok<AGROW>
        end
    end
    cause=e2cCycleClassify(maxQError<1e-9,anyOrbit,primaryOvershoot,boundaryCrosses);
    windowRaw=trace.rawAction(first:end,motor);windowPwm=trace.pwm(first:end,motor);
    caseSummary{end+1}=struct("caseId",c,"subject",subjects(c),"repetition",reps(c), ...
        "motor",motor,"primaryFixedReference",refs(1),"referenceRange",[min(refs),max(refs)], ...
        "pair",pair',"fixedPrimaryPersists",primaryPersists,"allFixedReferencesPersist",allPersists, ...
        "primaryOvershoot",primaryOvershoot,"quantizationBoundaryCrossesTeacher",boundaryCrosses, ...
        "observedRaw",windowRaw',"observedPWM",windowPwm', ...
        "observedMaxRawJump",max(abs(diff(windowRaw))),"observedMaxPWMJump",max(abs(diff(windowPwm))), ...
        "cause",cause); %#ok<AGROW>
end
T=struct2table([rows{:}]);writetable(T,fullfile(out,"cycle_reconstruction.csv"));
writetable(T(T.cycleWindow,:),fullfile(out,"cycle_windows.csv"));
L=struct2table([localRows{:}]);writetable(L,fullfile(out,"cycle_local_map.csv"));
B=struct2table([betweenRows{:}]);writetable(B,fullfile(out,"cycle_between_states.csv"));
Q=struct2table([boundaryRows{:}]);writetable(Q,fullfile(out,"cycle_quantization_boundaries.csv"));
F=struct2table([fixedRows{:}]);writetable(F,fullfile(out,"cycle_fixed_reference_replay.csv"));
FS=struct2table([fixedSummary{:}]);writetable(FS,fullfile(out,"cycle_fixed_reference_summary.csv"));
O=struct2table([orbitRows{:}]);writetable(O,fullfile(out,"cycle_orbit_reference_intervals.csv"));
summary=struct("cases",[caseSummary{:}],"maxHistoricalQError",maxQError, ...
    "maxHistoricalRawError",maxActionError,"maxHistoricalRewardError",maxRewardError, ...
    "boundaryMaxPWMJump",max(abs(Q.pwmJump)),"preregistrationSHA256",e2cSHA256(prereg), ...
    "sourceTrajectoriesSHA256",e2cSHA256(fullfile(here,"e2b_results","trajectories.mat")), ...
    "continuousPlantCounterfactualAvailable",false,"trainingExecuted",false);
save(fullfile(out,"cycle_artifacts.mat"),"T","L","B","Q","F","FS","O","summary");
e2cWriteJSON(fullfile(out,"cycle_summary.json"),summary);
assert(maxQError<1e-9 && maxActionError<1e-12 && maxRewardError<1e-12);
disp(summary);
end
function result=oneStep(q,r,motor,remap)
pred=hMotor(q,motor);raw=max(-1,min(1,2*(r-pred)));[effective,pwm]=remap(raw);
initial=zeros(1,4);initial(motor)=q;command=zeros(1,4);command(motor)=pwm;
next=SimController.prosthesis_simulator(initial,command,.2,.14,plantSource="patternCurveCanonical");
result=struct("q",q,"reference",r,"hBefore",pred,"error",r-pred,"raw",raw, ...
    "effective",effective,"pwm",pwm,"quantizationError",effective-raw,"qNext",next(motor));
end
function result=withMetadata(value,c,k,dq,dr)
result=struct("caseId",c,"historicalStep",k,"qOffset",dq,"referenceOffset",dr);
for name=string(fieldnames(value))',result.(name)=value.(name);end
end
function value=h(q)
value=encoder2Flex(q)./[4092 2046 1023 2046];
end
function value=hMotor(q,motor)
all=zeros(numel(q),4);all(:,motor)=q(:);all=h(all);value=reshape(all(:,motor),size(q));
end
function restoreOverride(old,had)
if had,setConfigurablesOverride(old);else,clearConfigurablesOverride();end
end
