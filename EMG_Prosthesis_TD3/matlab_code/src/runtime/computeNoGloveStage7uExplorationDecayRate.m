function decayRate = computeNoGloveStage7uExplorationDecayRate( ...
        trainingMaxEpisodes, options)
%computeNoGloveStage7uExplorationDecayRate scales TD3 exploration decay to
%a training horizon instead of reusing the fixed ETAPA 6 rate unchanged.
%
% ETAPA 6 (Agent200) used explorationStdDecayRate=1e-4 over a 200-episode/
% ~12200-step run (61 steps/episode), ending at multiplier
% exp(-1e-4*12200)=~0.295 - exploration std never reached its floor
% (0.02). Reusing 1e-4 unchanged over a 10000-episode/~610000-step
% campaign reaches the floor within the first ~1-2% of training (audit
% finding, campaign 2026-09-03_00-49-48-172), coinciding with the actor
% saturating against tanh's bounds for most of the run. This function
% picks the rate that reaches the SAME end-of-training multiplier
% Agent200 experienced, scaled to a different horizon.

arguments
    trainingMaxEpisodes (1, 1) double {mustBeInteger, mustBePositive}
    options.stepsPerEpisode (1, 1) double {mustBeInteger, mustBePositive} = 61
    options.referenceEpisodes (1, 1) double {mustBeInteger, mustBePositive} = 200
    options.referenceDecayRate (1, 1) double {mustBePositive} = 1e-4
    options.referenceStepsPerEpisode (1, 1) double ...
        {mustBeInteger, mustBePositive} = 61
end

referenceEndMultiplier = exp(-options.referenceDecayRate * ...
    options.referenceEpisodes * options.referenceStepsPerEpisode);
totalSteps = trainingMaxEpisodes * options.stepsPerEpisode;
decayRate = -log(referenceEndMultiplier) / totalSteps;
end
