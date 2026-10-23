function text=myoPrecheckInstruction(elapsed)
% Instrucciones diagnósticas, nunca fases/trials científicos.
if elapsed<8,text="REPOSO · RELAJA LA MANO";
elseif elapsed<15,text="ABRE CÓMODAMENTE LA MANO";
elseif elapsed<22,text="CIERRA CÓMODAMENTE · NO APRIETES CON FUERZA";
else,text="VUELVE A REPOSO · no busques una posición concreta";
end
end
