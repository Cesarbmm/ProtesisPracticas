function cause=e2cM3Classify(regionEvidence,provenanceValid)
% Regla preregistrada, sin seleccionar clasificacion a partir de conveniencia.
if ~provenanceValid || isempty(regionEvidence) || ...
        any(regionEvidence.sameIndexSupported==0 | regionEvidence.sameQSupported==0)
    cause="UNRESOLVED";return
end
sameIndex=regionEvidence.sameIndexNegative./regionEvidence.sameIndexSupported;
sameQ=regionEvidence.sameQNegative./regionEvidence.sameQSupported;
if all(sameIndex>.5 & sameQ>.5)
    cause="REPEATABLE_EMPIRICAL_STRUCTURE";
elseif all(sameIndex==0 & sameQ==0)
    cause="AVERAGING_ARTIFACT";
elseif all(sameIndex<=.5 & sameQ<=.5) && any(sameIndex>0 | sameQ>0)
    cause="LOW_REPEATABILITY";
else
    cause="MIXED";
end
end
