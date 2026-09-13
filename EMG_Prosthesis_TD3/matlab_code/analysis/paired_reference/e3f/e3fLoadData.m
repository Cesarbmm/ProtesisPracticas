function data=e3fLoadData(cfg,out)
allowed=[cfg.trainSubjects cfg.validationSubjects];
assert(numel(unique(allowed))==10 && ~any(ismember(allowed,["MATEO","SANDRA"])));
folder=fullfile(cfg.root,"data","datasets","Denis Dataset");
emgs={};gloves={};rows={};evalEmgs=struct();subjectMap=[];
for subIdx=1:numel(cfg.trainSubjects)
    subject=cfg.trainSubjects(subIdx);
    file=fullfile(folder,subject+".mat");
    d=load(file,"emgs","gloves");
    assert(isequal(size(d.emgs),size(d.gloves)) && size(d.emgs,2)==2);
    nRows=size(d.emgs,1);
    for r=1:nRows
        for side=1:2
            e=d.emgs{r,side};g=d.gloves{r,side};
            assert(size(e,2)==8 && size(e,1)>=40 && numel(g)>=2 && all(isfinite(e),"all"));
            teacherSteps=ceil((numel(g)-1)/2)-1;emgSteps=ceil((size(e,1)-1)/40)-1;
            assert(min(teacherSteps,emgSteps)<=cfg.maxSteps,"E3F:Horizon","Teacher excede maxSteps.");
            rows{end+1}=struct("subject",subject,"subjectIndex",subIdx,"row",r,"side",side,"datasetIndex",size(emgs,1)+r); %#ok<AGROW>
        end
    end
    emgs=[emgs;d.emgs]; %#ok<AGROW>
    gloves=[gloves;d.gloves]; %#ok<AGROW>
    subjectMap=[subjectMap;repmat(subIdx,nRows,1)]; %#ok<AGROW>
    evalEmgs.(subject)=d.emgs;
end

for subject=cfg.validationSubjects
    file=fullfile(folder,subject+".mat");
    d=load(file,"emgs");
    evalEmgs.(subject)=d.emgs;
end

inventory=struct2table([rows{:}]);writetable(inventory,fullfile(out,"training_inventory.csv"));

if cfg.mode=="smoke"
    % Para smoke: seleccionar al menos 3 filas de sujetos distintos para que el discriminador vea variabilidad
    chosen=[];chosenMap=[];
    for subIdx=1:min(3,numel(cfg.trainSubjects))
        subRows=find(subjectMap==subIdx);
        eligible=subRows(cellfun(@(x) size(x,1)>=900,emgs(subRows,1)) & cellfun(@(x) size(x,1)>=900,emgs(subRows,2)) & ...
            cellfun(@numel,gloves(subRows,1))>=45 & cellfun(@numel,gloves(subRows,2))>=45);
        assert(~isempty(eligible),"E3F:SmokeData","No hay episodios elegibles.");
        chosen=[chosen;eligible(1)]; %#ok<AGROW>
        chosenMap=[chosenMap;subIdx]; %#ok<AGROW>
    end
    emgs=emgs(chosen,:);gloves=gloves(chosen,:);subjectMap=chosenMap;
    writematrix(chosen,fullfile(out,"smoke_training_rows.csv"));
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
data=struct("emgs",{emgs},"gloves",{gloves},"subjectMap",subjectMap,"evaluation",{evalData},"comparators",{comparators});
end
