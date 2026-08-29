function layout = buildObservationLayout( ...
        observationVariant, numEmgFeatures, emgHistoryLength, numMotors)
%buildObservationLayout defines the auditable index contract for each state.

arguments
    observationVariant (1, 1) string
    numEmgFeatures (1, 1) double {mustBeInteger, mustBePositive}
    emgHistoryLength (1, 1) double {mustBeInteger, mustBePositive}
    numMotors (1, 1) double {mustBeInteger, mustBePositive}
end

layout = struct( ...
    "variant", observationVariant, ...
    "emg", [], ...
    "encoder", [], ...
    "deltaEncoder", [], ...
    "previousEffectiveAction", [], ...
    "referencePosition", [], ...
    "referenceVelocity", [], ...
    "declaredRest", [], ...
    "holdLatch", [], ...
    "totalLength", 0);

switch observationVariant
    case "legacy44"
        emgCount = numEmgFeatures;
        layout.emg = 1:emgCount;
        layout.encoder = emgCount + (1:numMotors);
        layout.totalLength = emgCount + numMotors;

    case "markov52"
        emgCount = numEmgFeatures;
        layout = appendMarkovFields(layout, emgCount, numMotors);

    case "stackedEmg132"
        emgCount = numEmgFeatures * emgHistoryLength;
        layout = appendMarkovFields(layout, emgCount, numMotors);

    case "intentMarkov60"
        emgCount = numEmgFeatures;
        layout = appendIntentFields(layout, emgCount, numMotors);

    case "intentDeclaredRestHoldMarkov62"
        emgCount = numEmgFeatures;
        layout = appendIntentFields(layout, emgCount, numMotors);
        layout.declaredRest = layout.totalLength + 1;
        layout.holdLatch = layout.totalLength + 2;
        layout.totalLength = layout.totalLength + 2;

    otherwise
        error("buildObservationLayout:UnsupportedVariant", ...
            "Unsupported observationVariant '%s'.", observationVariant);
end
end

function layout = appendMarkovFields(layout, emgCount, numMotors)
layout.emg = 1:emgCount;
nextIndex = emgCount + 1;
layout.encoder = nextIndex:(nextIndex + numMotors - 1);
nextIndex = nextIndex + numMotors;
layout.deltaEncoder = nextIndex:(nextIndex + numMotors - 1);
nextIndex = nextIndex + numMotors;
layout.previousEffectiveAction = nextIndex:(nextIndex + numMotors - 1);
layout.totalLength = nextIndex + numMotors - 1;
end

function layout = appendIntentFields(layout, emgCount, numMotors)
layout = appendMarkovFields(layout, emgCount, numMotors);
nextIndex = layout.totalLength + 1;
layout.referencePosition = nextIndex:(nextIndex + numMotors - 1);
nextIndex = nextIndex + numMotors;
layout.referenceVelocity = nextIndex:(nextIndex + numMotors - 1);
layout.totalLength = nextIndex + numMotors - 1;
end
