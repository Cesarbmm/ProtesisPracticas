function report = run_no_glove_stage6_smoke(options)
%run_no_glove_stage6_smoke runs the fixed 200-episode seed-11 smoke.
arguments
    options struct = struct()
end
options.phase = "smoke";
report = run_no_glove_stage6_training(options);
end
