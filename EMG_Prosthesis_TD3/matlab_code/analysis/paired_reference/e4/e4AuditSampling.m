function samplingTable = e4AuditSampling(episodeRecords, outDir)
% e4AuditSampling calcula y guarda las estadisticas exactas de muestreo por sujeto:
% - episodes per subject
% - steps per subject
% - opening per subject
% - closing per subject

arguments
    episodeRecords (:, 1) struct
    outDir (1, 1) string = ""
end

if isempty(episodeRecords)
    samplingTable = table();
    return;
end

T = struct2table(episodeRecords);
subjects = unique(T.subject, "stable");
rows = cell(numel(subjects), 1);

for i = 1:numel(subjects)
    s = subjects(i);
    subT = T(T.subject == s, :);
    episodesTotal = height(subT);
    stepsTotal = sum(subT.steps);

    closeT = subT(subT.side == 1, :);
    openT = subT(subT.side == 2, :);

    rows{i} = struct( ...
        "subject", s, ...
        "episodes", episodesTotal, ...
        "steps", stepsTotal, ...
        "closingEpisodes", height(closeT), ...
        "openingEpisodes", height(openT), ...
        "closingSteps", sum(closeT.steps), ...
        "openingSteps", sum(openT.steps));
end

samplingTable = struct2table([rows{:}]);

if strlength(outDir) > 0 && isfolder(outDir)
    writetable(samplingTable, fullfile(outDir, "subject_sampling.csv"));
    e2cWriteJSON(fullfile(outDir, "subject_sampling.json"), table2struct(samplingTable));
end
end
