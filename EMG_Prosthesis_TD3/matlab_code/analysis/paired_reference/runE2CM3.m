function summary=runE2CM3(options)
% Mapa y procedencia M3, analisis exclusivamente local sin editar la planta.
arguments
    options.outputDir (1,1) string = ""
end
here=string(fileparts(mfilename("fullpath")));root=fileparts(fileparts(here));
out=options.outputDir;if out=="",out=fullfile(here,"e2c_results");end
if ~isfolder(out),mkdir(out);end
prereg=fullfile(fileparts(root),"docs","paired_reference","PREREGISTRO_E2C.md");
assert(e2cSHA256(prereg)=="bddb7f8f45b6e6e9cbceb45f3c082c2d1a1694b60ed2de3bb1ec3ca1a46d4013");
curvePath=fullfile(root,"src","@SimController","pattern_curve.mat");
limitPath=fullfile(root,"src","@SimController","plant_limits_canonical.csv");
avgs=load(curvePath,"avgs").avgs;limits=readtable(limitPath,TextType="string");
s=load(fullfile(here,"e2b_results","trajectories.mat"),"trajectories");
observed=[];traces=s.trajectories;pool=[];
for k=1:numel(traces),observed=[observed;traces{k}.q(:,3)];end %#ok<AGROW>
pool=observed;fields=["sp_3F","sp_5F","sp_7F","sp_9F","sp_BF","sp_DF","sp_FF"];
speeds=[64 96 128 160 192 224 255];
for f=fields
    for d=["closing","opening"]
        rec=avgs.(f).(d).m_3;pool=[pool;rec.avg(:);rec.data(:)]; %#ok<AGROW>
    end
end
domain=[min(pool),max(pool)];qGrid=unique([pool;(ceil(domain(1)):floor(domain(2)))']);
regionsAll={};cellsAll={};maps={};validation={};evidence={};repeatRows={};provenance={};curveChecks={};
sourceDir=fullfile(root,"development","archive","simulator_creation_assets");
oldPath=path;pathCleanup=onCleanup(@() path(oldPath)); %#ok<NASGU>
addpath(sourceDir); % solo este directorio, nunca genpath del repositorio.
for speedIndex=1:7
    f=fields(speedIndex);pwm=speeds(speedIndex);rec=avgs.(f).closing.m_3;
    curve=rec.avg(:);data=rec.data;N=size(data,2);
    l=limits(limits.motor==3 & limits.direction=="closing" & limits.speed_field==f,:);
    lim=[l.min_lim l.max_lim];
    [regions,cells]=e2cM3ReversalIntervals(curve,lim,domain);
    regions.pwm=repmat(pwm,height(regions),1);cells.pwm=repmat(pwm,height(cells),1);
    regionsAll{end+1}=regions;cellsAll{end+1}=cells; %#ok<AGROW>
    points=unique([qGrid;regions.lower;regions.upper;regions.lower-1e-8;regions.lower+1e-8; ...
        regions.upper-1e-8;regions.upper+1e-8]);points=points(points>=domain(1)&points<=domain(2));
    [next,idx]=e2cM3CurveStep(points,curve,lim);delta=next-points;
    membership=e2cM3RegionMembership(points,regions);
    assert(isequal(membership,delta<0));
    maps{end+1}=table(points,repmat(pwm,numel(points),1),next,delta,idx,delta<0, ...
        VariableNames=["qBefore","pwm","qAfter","deltaQ","startIndex","reversal"]); %#ok<AGROW>
    % Todos los estados observados y cada celda de reversal contra API real.
    probe=unique([observed;cells.lower;cells.upper;(cells.lower+cells.upper)/2; ...
        cells.lower-1e-8;cells.lower+1e-8;cells.upper-1e-8;cells.upper+1e-8; ...
        points(round(linspace(1,numel(points),201)))]);
    fast=e2cM3CurveStep(probe,curve,lim);
    real=zeros(size(probe));
    for k=1:numel(probe)
        trajectory=SimController.prosthesis_simulator([0 0 probe(k) 0],[0 0 pwm 0],.2,.14, ...
            plantSource="patternCurveCanonical");real(k)=trajectory(end,3);
    end
    assert(isequal(fast,real));
    validation{end+1}=table(probe,repmat(pwm,numel(probe),1),fast,real,fast-real, ...
        VariableNames=["qBefore","pwm","offlineNext","simulatorNext","error"]); %#ok<AGROW>
    % Procedencia: aplicar UNICAMENTE indices/filtros historicos, sin ajustar offsets.
    folder=fullfile(sourceDir,"raw data Cx2",extractAfter(f,"sp_"));files=dir(fullfile(folder,"*.csv"));
    rawSegments={};rawFiles={};rawStarts=[];sourceHashes={};
    for k=1:numel(files)
        name=string(files(k).name);if contains(name,"Regreso"),continue,end
        token=regexp(name,'Prueba(\d+)','tokens','once');
        if ~filter_prueba(string(token{1}),extractAfter(f,"sp_"),""),continue,end
        file=fullfile(folder,name);raw=readRaw(file);
        start=max(10,find_start_point(raw))-1;
        rawSegments{end+1}=raw.z(start:end);rawFiles{end+1}=file;rawStarts(end+1)=start;sourceHashes{end+1}=e2cSHA256(file); %#ok<AGROW>
    end
    assert(numel(rawSegments)==N,"E2C:RawCountMismatch","Numero de repeticiones diferente.");
    columnValid=true;
    for j=1:N
        segment=rawSegments{j};err=max(abs(segment(1:size(data,1))-data(:,j)));
        columnValid=columnValid && err==0;
        provenance{end+1}=struct("pwm",pwm,"column",j,"file",string(rawFiles{j}), ...
            "sha256",string(sourceHashes{j}),"rawStartIndex",rawStarts(j), ...
            "storedLength",size(data,1),"availableRawLength",numel(segment),"maxError",err); %#ok<AGROW>
    end
    avgError=max(abs(mean(data,2)-curve));stdError=max(abs(std(data,0,2)-rec.std(:)));
    assert(avgError<1e-10 && stdError<1e-10 && columnValid);
    curveChecks{end+1}=struct("pwm",pwm,"length",numel(curve),"repeats",N, ...
        "avgError",avgError,"stdError",stdError,"rawColumnsExact",columnValid, ...
        "curveMin",min(curve),"curveMax",max(curve)); %#ok<AGROW>
    for cellIndex=1:height(cells)
        row=cells(cellIndex,:);q=(row.lower+row.upper)/2;i=row.startIndex;e=row.endIndex;
        sameIndex=data(e,:)-data(i,:);sameQ=nan(1,N);supported=false(1,N);
        for j=1:N
            % Con el mismo q, sin clamp de promedio ni HOLD convertido en evidencia.
            own=find(data(:,j)>=q,1);
            if ~isempty(own)
                supported(j)=true;sameQ(j)=data(min(own+200,size(data,1)),j)-q;
            end
            rawSeg=rawSegments{j};rawDelta=rawSeg(e)-rawSeg(i);
            fullDelta=NaN;if i+200<=numel(rawSeg),fullDelta=rawSeg(i+200)-rawSeg(i);end
            repeatRows{end+1}=struct("pwm",pwm,"cellIndex",cellIndex,"column",j, ...
                "qProbe",q,"startIndex",i,"endIndex",e,"sameIndexDelta",sameIndex(j), ...
                "sameQSupported",supported(j),"sameQDelta",sameQ(j),"rawSameIndexDelta",rawDelta, ...
                "rawFull200Delta",fullDelta,"storedClampedEnd",i+200>size(data,1), ...
                "rawStartIndex",rawStarts(j)+i-1,"rawEndIndex",rawStarts(j)+e-1); %#ok<AGROW>
        end
        validQ=sameQ(supported);
        evidence{end+1}=struct("pwm",pwm,"cellIndex",cellIndex,"lower",row.lower,"upper",row.upper, ...
            "qProbe",q,"qNext",row.qNext,"averageDeltaFromProbe",row.qNext-q, ...
            "averageSameIndexDelta",curve(e)-curve(i),"startIndex",i,"endIndex",e, ...
            "storedClampedEnd",i+200>numel(curve),"stdAtStart",rec.std(i),"stdAtEnd",rec.std(e), ...
            "totalRepeats",N,"sameIndexSupported",N,"sameIndexNegative",nnz(sameIndex<0), ...
            "sameIndexZero",nnz(sameIndex==0),"sameIndexPositive",nnz(sameIndex>0), ...
            "sameIndexMean",mean(sameIndex),"sameIndexStd",std(sameIndex), ...
            "sameIndexMin",min(sameIndex),"sameIndexMax",max(sameIndex), ...
            "sameQSupported",nnz(supported),"sameQNegative",nnz(validQ<0), ...
            "sameQMean",mean(validQ),"sameQStd",std(validQ),"sameQMin",min(validQ),"sameQMax",max(validQ)); %#ok<AGROW>
    end
    fprintf("M3 PWM %d: %d regiones, %d celdas, %d puntos; API exacta %d.\n",pwm,height(regions),height(cells),numel(points),numel(probe));
end
R=vertcat(regionsAll{:});C=vertcat(cellsAll{:});D=vertcat(maps{:});V=vertcat(validation{:});
E=struct2table([evidence{:}]);I=struct2table([repeatRows{:}]);P=struct2table([provenance{:}]);A=struct2table([curveChecks{:}]);
controllers=["ZERO","P_0.5","P_1","P_2","P_4","P_8","AGENT7250"];visits={};visitTrace={};
for controller=controllers
    qb=[];qa=[];u=[];allStates=[];
    for k=1:numel(traces)
        t=traces{k};if t.metadata.controller~=controller,continue,end
        qb=[qb;t.q(1:end-1,3)];qa=[qa;t.q(2:end,3)];u=[u;t.pwm(:,3)];allStates=[allStates;t.q(:,3)]; %#ok<AGROW>
    end
    anyRegion=e2cM3RegionMembership(qb,R);commandRegion=false(size(qb));
    for speed=speeds,commandRegion=commandRegion | (u==speed & e2cM3RegionMembership(qb,R(R.pwm==speed,:)));end
    reversed=u>0 & qa<qb;
    assert(isequal(commandRegion,reversed));
    visits{end+1}=struct("controller",controller,"statesBefore",numel(qb),"uniqueStatesBefore",numel(unique(qb)), ...
        "uniqueStatesIncludingFinal",numel(unique(allStates)),"inAnyReversalRegion",nnz(anyRegion), ...
        "fractionInAnyReversalRegion",mean(anyRegion),"inCommandReversalRegion",nnz(commandRegion), ...
        "executedReversals",nnz(reversed),"positiveCommandsInside",nnz(anyRegion & u>0), ...
        "zeroCommandsInside",nnz(anyRegion & u==0),"negativeCommandsInside",nnz(anyRegion & u<0)); %#ok<AGROW>
    visitTrace{end+1}=table(repmat(controller,numel(qb),1),qb,u,qa,anyRegion,commandRegion,reversed, ...
        VariableNames=["controller","qBefore","pwm","qAfter","inAnyRegion","inCommandRegion","reversal"]); %#ok<AGROW>
end
G=struct2table([visits{:}]);GT=vertcat(visitTrace{:});coverage={};
grids=["operational_cases.csv","operational_cases_combination_limits.csv","e0_regression_results.csv"];
for file=grids
    g=readtable(fullfile(here,"e0p_results",file),TextType="string");
    if file=="e0_regression_results.csv"
        % El oraculo original contiene exactamente la posicion de cada caso.
        g=readtable(fullfile(here,"plant_e0_regression_cases.csv"));
        g.q_initial=g.pos;
    end
    g=g(g.motor==3 & g.pwm>0 & g.duration==.2,:);inside=false(height(g),1);covered=false(height(R),1);
    for k=1:height(R)
        member=g.pwm==R.pwm(k) & e2cM3RegionMembership(g.q_initial,R(k,:));inside=inside|member;covered(k)=any(member);
    end
    coverage{end+1}=struct("grid",file,"positiveM3Cases",height(g),"casesInReversalRegion",nnz(inside), ...
        "regionsCovered",nnz(covered),"totalRegions",height(R)); %#ok<AGROW>
end
H=struct2table([coverage{:}]);cause=e2cM3Classify(E,all(P.maxError==0));
summary=struct("domain",domain,"mapRows",height(D),"apiValidationCases",height(V), ...
    "apiMaxError",max(abs(V.error)),"regions",height(R),"cells",height(C), ...
    "cause",cause,"rawColumnsVerified",height(P),"rawMaxError",max(P.maxError), ...
    "allReversals",sum(G.executedReversals),"p2Visits",G.inAnyReversalRegion(G.controller=="P_2"), ...
    "p2Reversals",G.executedReversals(G.controller=="P_2"), ...
    "patternCurveSHA256",e2cSHA256(curvePath),"preregistrationSHA256",e2cSHA256(prereg));
tables={R,C,D,V,E,I,P,A,G,GT,H};names=["intervals","cells","dense_map","api_validation", ...
    "repeatability","individual_repeats","raw_provenance","curve_checks","controller_visitation", ...
    "visitation_traces","e0p_coverage"];
for k=1:numel(tables),writetable(tables{k},fullfile(out,"m3_"+names(k)+".csv"));end
save(fullfile(out,"m3_artifacts.mat"),"R","C","D","V","E","I","P","A","G","GT","H","summary","-v7.3");
e2cWriteJSON(fullfile(out,"m3_summary.json"),summary);disp(summary);
end
function raw=readRaw(file)
opts=delimitedTextImportOptions("NumVariables",8);
opts.DataLines=[2 Inf];opts.Delimiter=";";
opts.VariableNames=["time","x","y","z","w","velocidad","voltaje","trama"];
opts.VariableTypes=["string","double","double","double","double","double","double","string"];
opts.ExtraColumnsRule="ignore";raw=readtable(file,opts);
end
