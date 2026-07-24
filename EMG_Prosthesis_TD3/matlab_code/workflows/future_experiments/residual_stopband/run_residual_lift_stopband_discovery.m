function results = run_residual_lift_stopband_discovery(options)
%run_residual_lift_stopband_discovery discovers a stable residual stop-band workflow.

arguments
    options = struct()
end

results = runResidualStopbandCampaignCore("discovery", options);
end
