function report = run_no_glove_stage6_campaign(options)
%run_no_glove_stage6_campaign runs 12k only after an approved pilot gate.
arguments
    options struct = struct()
end
options.phase = "campaign";
report = run_no_glove_stage6_training(options);
end
