function build_residual_multiseed_publication_figure(resultsMatPath, outFile)
%BUILD_RESIDUAL_MULTISEED_PUBLICATION_FIGURE Export a paper-ready summary plot.

if nargin < 1 || strlength(string(resultsMatPath)) == 0
    resultsMatPath = findLatestMultiseedResults();
end
if nargin < 2 || strlength(string(outFile)) == 0
    outFile = defaultOutputPath();
end

data = load(resultsMatPath, "results", "perSeedTable");
if isfield(data, "results") && isfield(data.results, "perSeedTable")
    perSeedTable = data.results.perSeedTable;
    benchmark = data.results.benchmark;
elseif isfield(data, "perSeedTable")
    perSeedTable = data.perSeedTable;
    benchmark = getAgent7250Benchmark();
else
    error("Results file %s does not contain a perSeedTable.", resultsMatPath);
end

figDir = fileparts(char(outFile));
if strlength(string(figDir)) > 0 && ~exist(figDir, "dir")
    mkdir(figDir);
end

metricLabels = {'trackingMSE', 'actionL2', 'saturationFraction', 'deltaActionL2'};
means = [ ...
    mean(perSeedTable.finalTrackingMse, "omitnan"), ...
    mean(perSeedTable.finalActionL2, "omitnan"), ...
    mean(perSeedTable.finalSaturationFraction, "omitnan"), ...
    mean(perSeedTable.finalDeltaActionL2, "omitnan")];
ci95Half = [ ...
    computeCi95HalfWidth(perSeedTable.finalTrackingMse), ...
    computeCi95HalfWidth(perSeedTable.finalActionL2), ...
    computeCi95HalfWidth(perSeedTable.finalSaturationFraction), ...
    computeCi95HalfWidth(perSeedTable.finalDeltaActionL2)];
benchmarkValues = [ ...
    benchmark.trackingMse, ...
    benchmark.actionL2, ...
    benchmark.saturationFraction, ...
    benchmark.deltaActionL2];
perSeedValues = { ...
    perSeedTable.finalTrackingMse, ...
    perSeedTable.finalActionL2, ...
    perSeedTable.finalSaturationFraction, ...
    perSeedTable.finalDeltaActionL2};

f = figure("Visible", "off", "Color", "w", "Position", [100 100 1400 740]);
t = tiledlayout(f, 2, 2, "TileSpacing", "compact", "Padding", "compact");
legendHandles = gobjects(0);
for i = 1:numel(metricLabels)
    nexttile(t);
    hBar = bar(1, means(i), "FaceColor", [0.00 0.45 0.74], "EdgeColor", "none", "BarWidth", 0.55);
    hold on
    hErr = errorbar(1, means(i), ci95Half(i), "k", "LineWidth", 1.7, "CapSize", 12);
    hRef = yline(benchmarkValues(i), "--", "Color", [0.85 0.33 0.10], "LineWidth", 1.8);
    hPts = scatter(ones(height(perSeedTable), 1), perSeedValues{i}, 46, ...
        "filled", "MarkerFaceColor", [0.93 0.69 0.13], "MarkerFaceAlpha", 0.85, ...
        "MarkerEdgeColor", [0.20 0.20 0.20]);
    hold off
    xlim([0.5 1.5]);
    xticks(1);
    xticklabels({'Residual multi-seed'});
    ylabel(metricLabels{i});
    title(metricLabels{i}, "FontWeight", "bold");
    grid on
    if i == 1
        legendHandles = [hBar, hErr, hRef, hPts]; %#ok<AGROW>
        legend(legendHandles, {"mean", "95% CI", "Agent7250", "per-seed runs"}, ...
            "Location", "best", "Box", "off");
    end
end
title(t, "Residual Lift reproducibility against the Agent7250 benchmark", ...
    "FontWeight", "bold");

exportgraphics(f, outFile, "Resolution", 260);
close(f);
end

function resultsMatPath = findLatestMultiseedResults()
scriptDir = fileparts(mfilename("fullpath"));
docsRoot = fileparts(scriptDir);
projectRoot = fileparts(docsRoot);
repoRoot = fileparts(projectRoot);
workspaceRoot = fileparts(repoRoot);
candidateRoots = [ ...
    string(fullfile(workspaceRoot, "Agentes", "residual_lift_multiseed")), ...
    string(fullfile(repoRoot, "Agentes", "residual_lift_multiseed"))];

matches = [];
for i = 1:numel(candidateRoots)
    searchRoot = candidateRoots(i);
    if exist(searchRoot, "dir")
        matches = dir(fullfile(searchRoot, "**", "residual_lift_multiseed_results.mat"));
        if ~isempty(matches)
            break;
        end
    end
end

if isempty(matches)
    error("No residual_lift_multiseed_results.mat file was found under any Agentes/residual_lift_multiseed root.");
end
[~, idx] = max([matches.datenum]);
resultsMatPath = string(fullfile(matches(idx).folder, matches(idx).name));
end

function outFile = defaultOutputPath()
scriptDir = fileparts(mfilename("fullpath"));
docsRoot = fileparts(scriptDir);
outFile = string(fullfile(docsRoot, "figures", "residual_multiseed_summary_20260330.png"));
end

function ci95Half = computeCi95HalfWidth(values)
values = double(values(:));
values = values(~isnan(values));
n = numel(values);
if n <= 1
    ci95Half = NaN;
    return;
end

sigma = std(values, 0);
if exist("tinv", "file") == 2
    tCritical = tinv(0.975, n - 1);
else
    tCritical = approximateTCritical95(n - 1);
end
ci95Half = tCritical * sigma / sqrt(n);
end

function tCritical = approximateTCritical95(df)
switch df
    case 1
        tCritical = 12.706;
    case 2
        tCritical = 4.303;
    case 3
        tCritical = 3.182;
    case 4
        tCritical = 2.776;
    case 5
        tCritical = 2.571;
    case 6
        tCritical = 2.447;
    case 7
        tCritical = 2.365;
    case 8
        tCritical = 2.306;
    case 9
        tCritical = 2.262;
    case 10
        tCritical = 2.228;
    otherwise
        tCritical = 1.96;
end
end
