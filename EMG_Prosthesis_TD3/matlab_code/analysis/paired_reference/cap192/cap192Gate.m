function g=cap192Gate(original,candidate,checks)
% Umbrales preregistrados. Un reward mas negativo es peor.
g=struct();
g.mseChangePct=100*(candidate.mse-original.mse)/original.mse;
g.rewardWorseningPct=100*(original.reward-candidate.reward)/abs(original.reward);
g.m3ReductionPct=100*(original.m3-candidate.m3)/original.m3;
g.msePass=candidate.mse<=1.05*original.mse;
g.rewardPass=candidate.reward>=original.reward-.05*abs(original.reward);
g.m3Pass=candidate.m3<=.10*original.m3;
g.newFinalCycles=candidate.newFinalCycles;g.newFinalPeriodic=candidate.newFinalPeriodic;
g.newRuntimeFinalCycles=candidate.newRuntimeFinalCycles;g.newRuntimeFinalPeriodic=candidate.newRuntimeFinalPeriodic;
g.orbitPass=all([g.newFinalCycles g.newFinalPeriodic g.newRuntimeFinalCycles g.newRuntimeFinalPeriodic]==0);
g.boundHitFraction192=candidate.boundHitFraction192;g.boundPass=g.boundHitFraction192<=.50;
g.zeroMotionPass=candidate.zeroMotionFailures==0;
g.offReproduced=checks.offReproduced;g.testsPass=checks.testsPass;g.hashesIntact=checks.hashesIntact;
g.supported=all([g.msePass g.rewardPass g.m3Pass g.orbitPass g.boundPass g.zeroMotionPass ...
    g.offReproduced g.testsPass g.hashesIntact]);
end
