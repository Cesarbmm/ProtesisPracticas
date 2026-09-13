function data=e3axLoadData(cfg,out)
% Sólo sujetos explícitos; nunca cargar el dataset global de configurables.
allowed=[cfg.trainSubjects cfg.validationSubjects];assert(numel(unique(allowed))==10 && ~any(ismember(allowed,["MATEO","SANDRA"])));
folder=fullfile(cfg.root,"data","datasets","Denis Dataset");emgs={};gloves={};rows={};evalEmgs=struct();
for subject=allowed
    assert(ismember(subject,allowed));file=fullfile(folder,subject+".mat");
    if ismember(subject,cfg.trainSubjects)
        d=load(file,"emgs","gloves");assert(isequal(size(d.emgs),size(d.gloves)) && size(d.emgs,2)==2);
        for r=1:size(d.emgs,1)
            for side=1:2
                e=d.emgs{r,side};g=d.gloves{r,side};assert(size(e,2)==8 && size(e,1)>=40 && numel(g)>=2 && all(isfinite(e),"all"));
                teacherSteps=ceil((numel(g)-1)/2)-1;emgSteps=ceil((size(e,1)-1)/40)-1;
                assert(min(teacherSteps,emgSteps)<=cfg.maxSteps,"E3AX:Horizon","Teacher excede50pasos; no truncar silenciosamente.");
                rows{end+1}=struct("subject",subject,"row",r,"side",side,"datasetIndex",size(emgs,1)+r,"emgSamples",size(e,1),"gloveSamples",numel(g)); %#ok<AGROW>
            end
        end
        emgs=[emgs;d.emgs];gloves=[gloves;d.gloves]; %#ok<AGROW>
    else
        d=load(file,"emgs"); % VALIDATION: guante sólo en trazas teacher existentes, no para runtime.
    end
    evalEmgs.(subject)=d.emgs;
end
inventory=struct2table([rows{:}]);writetable(inventory,fullfile(out,"training_inventory.csv"));
if cfg.mode=="smoke"
    eligible=find(cellfun(@(x) size(x,1)>=900,emgs(:,1)) & cellfun(@(x) size(x,1)>=900,emgs(:,2)) & ...
        cellfun(@numel,gloves(:,1))>=45 & cellfun(@numel,gloves(:,2))>=45);
    assert(~isempty(eligible),"E3AX:SmokeData","No hay episodios suficientemente largos para probar aprendizaje con minibatch64.");
    chosen=eligible(1:min(3,numel(eligible)));emgs=emgs(chosen,:);gloves=gloves(chosen,:);writematrix(chosen,fullfile(out,"smoke_training_rows.csv"));
end
d=load(fullfile(cfg.root,"analysis","paired_reference","e2f_results","trajectories.mat"),"trajectories");
base=d.trajectories(:,2);mask=true(200,1);
if cfg.mode=="smoke"
    mask=false(200,1);
    for s=[cfg.trainSubjects(1),cfg.validationSubjects(1)]
        for side=1:2,idx=find(cellfun(@(t) t.metadata.subject==s && t.metadata.side==side,base),1);mask(idx)=true;end
    end
end
base=base(mask);comparators=d.trajectories(mask,[1 3 2 7]);evalData=cell(numel(base),1);selection={};
for j=1:numel(base)
    t=base{j};md=t.metadata;split="VALIDATION";if ismember(md.subject,cfg.trainSubjects),split="TRAIN";end
    evalData{j}=struct("base",t,"emg",evalEmgs.(md.subject){md.repetition,md.side},"split",split);
    selection{j}=struct("subject",md.subject,"row",md.repetition,"side",md.side,"split",split,"teacherSteps",size(t.reference,1));
end
writetable(struct2table([selection{:}]),fullfile(out,"evaluation_selection.csv"));
data=struct("emgs",{emgs},"gloves",{gloves},"evaluation",{evalData},"comparators",{comparators});
end
