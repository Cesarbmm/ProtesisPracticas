function report = run_no_glove_stage6_pilot(options)
%run_no_glove_stage6_pilot runs the fixed 2k [11,22,33] pilot.
arguments
    options struct = struct()
end
options.phase = "pilot";
report = run_no_glove_stage6_training(options);
end
