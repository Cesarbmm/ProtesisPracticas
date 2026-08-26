function report = run_no_glove_stage6_position_safety_smoke(options)
%run_no_glove_stage6_position_safety_smoke runs the single corrective ablation.

arguments
    options struct = struct()
end

if isfield(options, "phase") && string(options.phase) ~= "smoke"
    error("run_no_glove_stage6_position_safety_smoke:InvalidPhase", ...
        "The corrective launcher is restricted to the 200-episode smoke.");
end
if isfield(options, "positionSafetyAblation") && ...
        ~logical(options.positionSafetyAblation)
    error("run_no_glove_stage6_position_safety_smoke:SafetyRequired", ...
        "The corrective launcher cannot disable its only ablation.");
end
options.phase = "smoke";
options.positionSafetyAblation = true;
report = run_no_glove_stage6_training(options);
end
