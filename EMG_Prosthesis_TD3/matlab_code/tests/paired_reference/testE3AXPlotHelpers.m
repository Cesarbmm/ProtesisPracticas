function tests = testE3AXPlotHelpers
% Synthetic-only contracts for the public E3AX plotting/export helpers.
tests = functiontests(localfunctions);
end

function setupOnce(t)
root = fileparts(fileparts(fileparts(mfilename("fullpath"))));
t.applyFixture(matlab.unittest.fixtures.PathFixture( ...
    fullfile(root,"analysis","paired_reference","e3ax")));
end

function setup(t)
folder = t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
t.TestData.out = string(folder.Folder);
end

function testEpisodeExportsFourMotorsWithoutChangingSamples(t)
trace = syntheticTrace(25);
out = fullfile(t.TestData.out,"episode");
callWithFigureAudit(t,@() e3axPlotEpisode(trace,out,"Synthetic episode"));
base = "BLANCA_row0001_closing";
verifyArtifacts(t,out,base,["fig","png"]);
fig = readFigure(t,fullfile(out,base + ".fig"));
axesList = findall(fig,"Type","axes");
verifyEqual(t,numel(axesList),4);
for motor = 1:4
    reference = findSeries(axesList,trace.reference(:,motor),"line");
    prediction = findSeries(axesList,trace.prediction(:,motor),"line");
    assertEqual(t,numel(reference),1,"Each reference must appear exactly once.");
    assertEqual(t,numel(prediction),1,"Each prediction must appear exactly once.");
    verifyEqual(t,reference.Parent,prediction.Parent);
    verifyEqual(t,string(reference.Tag),"reference");
    verifyEqual(t,string(prediction.Tag),"prediction");
    verifyTrue(t,contains(string(reference.DisplayName),"Referencia"));
    verifyTrue(t,contains(string(prediction.DisplayName),"h(q)"));
    verifyEqual(t,reference.XData,prediction.XData);
    verifyTrue(t,all(diff(reference.XData(:)) > 0));
end
end

function testEpisodeTextDoesNotGrowWithSampleCount(t)
shortTrace = syntheticTrace(7);
longTrace = syntheticTrace(89);
shortOut = fullfile(t.TestData.out,"short");
longOut = fullfile(t.TestData.out,"long");
callWithFigureAudit(t,@() e3axPlotEpisode(shortTrace,shortOut,"Synthetic episode"));
callWithFigureAudit(t,@() e3axPlotEpisode(longTrace,longOut,"Synthetic episode"));
name = "BLANCA_row0001_closing.fig";
shortFigure = readFigure(t,fullfile(shortOut,name));
longFigure = readFigure(t,fullfile(longOut,name));
shortText = findall(shortFigure,"Type","text");
longText = findall(longFigure,"Type","text");
verifyEqual(t,numel(longText),numel(shortText), ...
    "Plot labels must not add one text object for every sample.");
verifyLessThan(t,numel(longText),size(longTrace.reference,1));
end

function testEpisodeAcceptsMissingQAndRepetitionForOpening(t)
trace = rmfield(syntheticTrace(13),"q");
trace.metadata = rmfield(trace.metadata,"row");
trace.metadata.repetition = 9;
trace.metadata.side = 2;
out = fullfile(t.TestData.out,"opening");
callWithFigureAudit(t,@() e3axPlotEpisode(trace,out,"No encoder trace"));
base = "BLANCA_row0009_opening";
verifyArtifacts(t,out,base,["fig","png"]);
fig = readFigure(t,fullfile(out,base + ".fig"));
axesList = findall(fig,"Type","axes");
verifyEqual(t,numel(axesList),4);
for motor = 1:4
    verifyEqual(t,numel(findSeries(axesList,trace.reference(:,motor),"line")),1);
    verifyEqual(t,numel(findSeries(axesList,trace.prediction(:,motor),"line")),1);
end
end

function testTrainingStatsExportsRecordedValuesAndCompleteObject(t)
trainingStats = syntheticTrainingStats;
out = fullfile(t.TestData.out,"training");
callWithFigureAudit(t,@() e3axExportTrainingStats(trainingStats,out));
verifyArtifacts(t,out,"trainingStats",["mat","csv"]);
verifyArtifacts(t,out,"training_progress",["fig","png","svg","pdf"]);
saved = load(fullfile(out,"trainingStats.mat"));
assertTrue(t,isfield(saved,"trainingStats"));
verifyEqual(t,saved.trainingStats,trainingStats, ...
    "The MAT export must preserve the full object, including unknown fields.");
csv = readtable(fullfile(out,"trainingStats.csv"),TextType="string");
metrics = ["EpisodeReward","AverageReward","EpisodeSteps","AverageSteps","EpisodeQ0"];
for field = ["EpisodeIndex",metrics,"EvaluationStatistic"]
    assertTrue(t,ismember(field,string(csv.Properties.VariableNames)));
    verifyEqual(t,csv.(field),trainingStats.(field),AbsTol=1e-12);
end
fig = readFigure(t,fullfile(out,"training_progress.fig"));
axesList = findall(fig,"Type","axes");
verifyEqual(t,numel(axesList),4);
for field = metrics
    series = findSeries(axesList,trainingStats.(field),"line");
    assertEqual(t,numel(series),1,"A recorded metric must be plotted once: " + field);
    verifyEqual(t,series.XData(:),trainingStats.EpisodeIndex);
end
end

function testTrainingStatsMissingOptionalMetricsRemainUnrecorded(t)
trainingStats = struct("EpisodeIndex",[2;5;11],"EpisodeReward",[-7;2;4]);
out = fullfile(t.TestData.out,"minimal_training");
callWithFigureAudit(t,@() e3axExportTrainingStats(trainingStats,out));
verifyArtifacts(t,out,"trainingStats",["mat","csv"]);
verifyArtifacts(t,out,"training_progress",["fig","png","svg","pdf"]);
saved = load(fullfile(out,"trainingStats.mat"));
verifyEqual(t,saved.trainingStats,trainingStats);
csv = readtable(fullfile(out,"trainingStats.csv"),TextType="string");
verifyEqual(t,csv.EpisodeIndex,trainingStats.EpisodeIndex);
verifyEqual(t,csv.EpisodeReward,trainingStats.EpisodeReward);
optional = ["AverageReward","EpisodeSteps","AverageSteps","EpisodeQ0","EvaluationStatistic"];
for field = optional
    if ismember(field,string(csv.Properties.VariableNames))
        verifyTrue(t,all(ismissing(csv.(field))), ...
            "An absent optional metric may only be exported as missing: " + field);
    end
end
fig = readFigure(t,fullfile(out,"training_progress.fig"));
axesList = findall(fig,"Type","axes");
verifyEqual(t,numel(axesList),4);
series = finiteSeries(axesList,"line");
assertEqual(t,numel(series),1,"Only the recorded episode reward may be plotted.");
verifyEqual(t,series.YData(:),trainingStats.EpisodeReward);
verifyEqual(t,series.XData(:),trainingStats.EpisodeIndex);
emptyPanels = 0;
for ax = reshape(axesList,1,[])
    if isempty(finiteSeries(ax,"line"))
        emptyPanels = emptyPanels + 1;
        titleText = lower(join(string(ax.Title.String)," "));
        verifyTrue(t,contains(titleText,"no registrado"), ...
            "An empty optional panel must explicitly say that it was not recorded.");
    end
end
verifyEqual(t,emptyPanels,3);
end

function testComparisonExportsAllMetricsAndMarksPrivilegedPolicies(t)
macro = syntheticComparison;
out = fullfile(t.TestData.out,"comparison");
callWithFigureAudit(t,@() e3axPlotComparison(macro,out));
verifyArtifacts(t,out,"policy_comparison",["fig","png","svg"]);
if isfile(fullfile(out,"policy_comparison.pdf"))
    verifyArtifacts(t,out,"policy_comparison","pdf");
end
fig = readFigure(t,fullfile(out,"policy_comparison.fig"));
verifyComparison(t,fig,macro);
end

function testComparisonAcceptsRewardMeanColumn(t)
macro = syntheticComparison;
macro = renamevars(macro,"reward","rewardMean");
out = fullfile(t.TestData.out,"comparison_reward_mean");
callWithFigureAudit(t,@() e3axPlotComparison(macro,out));
verifyArtifacts(t,out,"policy_comparison",["fig","png","svg"]);
fig = readFigure(t,fullfile(out,"policy_comparison.fig"));
verifyComparison(t,fig,macro);
end

function trace = syntheticTrace(count)
sample = (0:count-1)' / max(count-1,1);
reference = .08 + sample * [.17 .23 .29 .31] + [0 .11 .22 .33];
prediction = reference + sin((1:count)' * [.31 .43 .59 .71]) * .017;
trace = struct("metadata",struct("subject","BLANCA","row",1,"side",1), ...
    "reference",reference,"prediction",prediction, ...
    "q",[zeros(1,4);1000 * prediction]);
end

function stats = syntheticTrainingStats
stats = struct("EpisodeIndex",[1;3;8;9],"EpisodeReward",[-5;.25;-1.5;3], ...
    "AverageReward",[-5;-2;-1;.5],"EpisodeSteps",[10;12;8;15], ...
    "AverageSteps",[10;11;10;11.25],"EpisodeQ0",[.12;-.35;.5;.7], ...
    "EvaluationStatistic",[NaN;-.5;-.4;-.3], ...
    "sentinel",struct("token","keep the complete training result", ...
    "matrix",[2 3;7 11],"nested",struct("source","synthetic")));
end

function macro = syntheticComparison
controller = ["ZERO";"P2";"AGENT7250";"E3A_EMG";"E3A_EMG_DQ";"ORACLE_H5"];
trackingMSE = [.41;.32;.27;.19;.13;.07];
reward = [-.51;-.43;-.38;-.28;-.21;-.16];
actionL2 = [.01;.17;.23;.29;.31;.37];
deltaActionL2 = [.02;.07;.11;.13;.19;.23];
saturationFraction = [.03;.05;.09;.12;.18;.21];
persistentTwoCycle = [0;4;2;1;1;0];
m3Reversals = [0;3;1;1;0;0];
macro = table(controller,trackingMSE,reward,actionL2,deltaActionL2, ...
    saturationFraction,persistentTwoCycle,m3Reversals);
end

function verifyComparison(t,fig,macro)
axesList = findall(fig,"Type","axes");
verifyEqual(t,numel(axesList),7);
metrics = string(macro.Properties.VariableNames(2:end));
for field = metrics
    series = findSeries(axesList,macro.(field),"bar");
    assertEqual(t,numel(series),1,"Every comparison metric must appear once: " + field);
    ax = series.Parent;
    verifyEqual(t,series.XData(:),(1:height(macro))');
    labels = string(ax.XTickLabel);
    assertEqual(t,numel(labels),height(macro));
    labels = reshape(labels,[],1);
    normalized = replace(upper(erase(labels,"\")),"_"," ");
    for policy = 1:height(macro)
        verifyTrue(t,contains(normalized(policy),replace(macro.controller(policy),"_"," ")));
    end
    privileged = contains(lower(labels),"privileg");
    verifyEqual(t,privileged,ismember(macro.controller,["P2","ORACLE_H5"]), ...
        "P2 and Oracle H5 must be explicitly identified as privileged comparators.");
end
end

function fig = readFigure(t,file)
assertTrue(t,isfile(file),"Expected exported FIG: " + file);
fig = openfig(file,"new","invisible");
t.addTeardown(@() closeIfValid(fig));
end

function verifyArtifacts(t,folder,base,extensions)
for extension = extensions
    file = fullfile(folder,base + "." + extension);
    assertTrue(t,isfile(file),"Missing export: " + file);
    info = dir(file);
    verifyGreaterThan(t,info.bytes,0,"The exported file must not be empty: " + file);
end
end

function matches = findSeries(axesList,values,type)
series = finiteSeries(axesList,type);
matches = gobjects(0,1);
for item = reshape(series,1,[])
    actual = item.YData(:);
    if isequal(size(actual),size(values(:))) && all(abs(actual-values(:)) < 1e-12)
        matches(end+1,1) = item; %#ok<AGROW>
    end
end
end

function series = finiteSeries(axesList,type)
series = gobjects(0,1);
for ax = reshape(axesList,1,[])
    candidates = findall(ax,"Type",type);
    for item = reshape(candidates,1,[])
        if isnumeric(item.YData) && any(isfinite(item.YData),"all")
            series(end+1,1) = item; %#ok<AGROW>
        end
    end
end
end

function callWithFigureAudit(t,action)
% Force the caller default to visible: helpers must opt out themselves.
before = findall(groot,"Type","figure");
ownedCleanup = onCleanup(@() closeNewFigures(before)); %#ok<NASGU>
sentinel = figure("Visible","off","Name","E3AX unrelated figure sentinel");
sentinelColor = sentinel.Color;
key = "E3AXPlotHelpersTestVisibility";
oldVisible = get(groot,"DefaultFigureVisible");
oldCreate = get(groot,"DefaultFigureCreateFcn");
hadData = isappdata(groot,key);
oldData = [];
if hadData, oldData = getappdata(groot,key); end
defaultsCleanup = onCleanup(@() restoreGraphicsDefaults( ...
    oldVisible,oldCreate,key,hadData,oldData)); %#ok<NASGU>
setappdata(groot,key,strings(0,1));
set(groot,"DefaultFigureVisible","on", ...
    "DefaultFigureCreateFcn",@recordFigureVisibility);
action();
visibility = getappdata(groot,key);
verifyNotEmpty(t,visibility,"The helper must create its own export figure.");
verifyTrue(t,all(visibility == "off"),"Export figures must be created invisible.");
assertTrue(t,isgraphics(sentinel,"figure"),"The helper closed an unrelated figure.");
verifyEqual(t,sentinel.Color,sentinelColor);
verifyEqual(t,string(sentinel.Visible),"off");
after = findall(groot,"Type","figure");
expected = [before(:);sentinel];
verifyEqual(t,numel(after),numel(expected),"The helper leaked an export figure.");
verifyTrue(t,all(ismember(expected,after)),"The helper changed unrelated figure handles.");
end

function recordFigureVisibility(fig,~)
key = "E3AXPlotHelpersTestVisibility";
if isappdata(groot,key)
    seen = getappdata(groot,key);
    setappdata(groot,key,[seen;string(fig.Visible)]);
end
end

function restoreGraphicsDefaults(visible,create,key,hadData,oldData)
set(groot,"DefaultFigureVisible",visible,"DefaultFigureCreateFcn",create);
if hadData
    setappdata(groot,key,oldData);
elseif isappdata(groot,key)
    rmappdata(groot,key);
end
end

function closeNewFigures(before)
current = findall(groot,"Type","figure");
for fig = reshape(current,1,[])
    if ~ismember(fig,before), closeIfValid(fig); end
end
end

function closeIfValid(fig)
if isgraphics(fig,"figure"), close(fig); end
end
