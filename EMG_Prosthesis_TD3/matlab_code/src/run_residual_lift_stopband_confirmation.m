function results = run_residual_lift_stopband_confirmation(options)
%run_residual_lift_stopband_confirmation confirms a proposed residual stop-band.

arguments
    options = struct()
end

results = runResidualStopbandCampaignCore("confirmation", options);
end
