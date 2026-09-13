function report = e4DocumentationPreflight(cfg)
% Validacion cerrada antes de cargar datos o crear archivos de corrida.
expected = e4DocumentationConfig();
assert(isequaln(cfg, expected), "E4Doc:ConfigChanged", "La configuracion documental debe coincidir con el preregistro.");
assert(~any(ismember(cfg.trainSubjects, ["MATEO","SANDRA"])) && isempty(cfg.validationSubjects), "E4Doc:Subjects");
assert(cfg.documentationOnly && ~cfg.scientificFinalModel && ~cfg.mateoSandraAllowed, "E4Doc:Role");
assert(endsWith(cfg.outputParent, fullfile("results","e4_documentation_1m")), "E4Doc:Output");
report = struct("configurationValidated",true,"documentationOnly",true, ...
    "scientificFinalAgentChanged",false,"sealedTestReuse","FORBIDDEN");
end
