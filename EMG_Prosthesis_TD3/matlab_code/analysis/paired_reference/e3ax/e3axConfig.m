function cfg=e3axConfig(mode)
arguments,mode (1,1) string {mustBeMember(mode,["long","smoke"])}="long";end
root=string(fileparts(fileparts(fileparts(fileparts(mfilename("fullpath"))))));
cfg=struct("mode",mode,"root",root,"seed",20260908,"maxEpisodes",20000,"checkpoints",[250 500 1000 2000 5000 10000 15000 20000], ...
    "trainSubjects",["BLANCA","CECILIA","DENIS","EMILIA","GABI","GABRIEL","IVANNA"],"validationSubjects",["JOE","JONATHAN","KHAROL"], ...
    "referenceContractValidated",false,"exploratoryTrainingAuthorized",true,"hardwareAuthorized",false,"referenceTransform","ORIGINAL", ...
    "fullTrainingResumeAvailable",false,"plots","training-progress","maxSteps",50,"evaluationFrequency",250);
if mode=="smoke",cfg.maxEpisodes=5;cfg.checkpoints=[2 5];cfg.evaluationFrequency=1;end
cfg.outputParent=fullfile(root,"results","e3ax_"+mode);
cfg.splitRule="Orden alfabético DEVELOPMENT: primeros7TRAIN, últimos3VALIDATION; congelado antes de smoke";
end
