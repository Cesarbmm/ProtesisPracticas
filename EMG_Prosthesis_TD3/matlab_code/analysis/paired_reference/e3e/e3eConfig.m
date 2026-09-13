function cfg = e3eConfig()
% E3E frozen configuration
here = string(fileparts(mfilename("fullpath")));
pr = fileparts(here);
root = fileparts(fileparts(pr));

cfg = struct();
cfg.here = here;
cfg.pr = pr;
cfg.root = root;
cfg.output = fullfile(pr, "e3e_results");
cfg.dataPath = fullfile(pr, "e3c_results", "supervised_data.mat");

cfg.trainSubjects = ["BLANCA", "CECILIA", "DENIS", "EMILIA", "GABI", "GABRIEL", "IVANNA"];
cfg.validationSubjects = ["JOE", "JONATHAN", "KHAROL"];
cfg.sealedSubjects = ["MATEO", "SANDRA"];

cfg.seeds = [20260923, 20260924, 20260925];
cfg.categories = [0, -64, 64, -96, 96, -128, 128, -160, 160, -192, 192, -224, 224, -255, 255];
cfg.speeds = 255 * ones(1, 4);
cfg.period = 0.2;
cfg.numFeatures = 40;
cfg.totalMarkov = 52;
end
