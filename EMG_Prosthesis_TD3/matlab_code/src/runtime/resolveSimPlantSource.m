function source = resolveSimPlantSource(requested)
%resolveSimPlantSource seleccion validada, sin cache ni deteccion de toolboxes.
arguments
    requested (1, 1) string = ""
end
source = requested;
if source == ""
    source = "legacyAuto";
    if exist("configurables", "file") == 2
        p = configurables();
        if isfield(p, "simPlantSource")
            source = string(p.simPlantSource);
        end
    end
end
if ~isscalar(source) || ~ismember(source, ["legacyAuto", "patternCurveCanonical"])
    error("ProtesisPracticas:InvalidPlantSource", ...
        "simPlantSource debe ser legacyAuto o patternCurveCanonical.");
end
end
