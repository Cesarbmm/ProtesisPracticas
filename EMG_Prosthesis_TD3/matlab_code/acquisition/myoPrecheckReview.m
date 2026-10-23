function review=myoPrecheckReview(q)
% Presentar los umbrales existentes, sin recalificar variación EMG como intención.
errors=intersect(string(q.warnings),["INSUFFICIENT_SAMPLES","CHANNEL_COUNT","NONFINITE_RAW","TIMESTAMP_ORDER"]);
significant=intersect(string(q.warnings),["FLAT_CHANNEL","CLIPPING_OVER_1_PERCENT","NOMINAL_FS_OUTSIDE_180_220", ...
 "WALL_RATE_OUTSIDE_180_220","REPEATED_ROWS_OVER_5_PERCENT_NOT_PROOF_OF_DROPOUT"]);
flat="ninguno";if ~isempty(q.flat_channels),flat=join("CH"+q.flat_channels,", ");end
clip=find(q.clipping_fraction>.01);clipped="ninguno";if ~isempty(clip),clipped=join("CH"+clip,", ");end
warnings="ninguno";if ~isempty(q.warnings),warnings=join(string(q.warnings),", ");end
message=sprintf('Canales: %d · Fs por timestamps: %.2f Hz\nCanales planos: %s\nClipping >1%%: %s\n\nAvisos: %s\n\nRevisar visualmente estabilidad: saltos anormales, cambios de contacto o brazalete flojo. No hay un detector automático validado de mala colocación/inestabilidad. Si se observa, recolocar y repetir el precheck.', ...
 q.channels,q.actual_emg_fs,flat,clipped,warnings);
review=struct('has_errors',~isempty(errors),'requires_review',~isempty(errors)||~isempty(significant),'message',string(message), ...
 'errors',errors,'significant_warnings',significant);
end
