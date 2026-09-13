function summary=runPairedReferenceE2D
% Unico punto de entrada de reproduccion E2D. No entrenamiento ni escritura Git.
assert(~contains(lower(string(path)),"sandbox"),"E2D:ForbiddenPath","Usar paths cientificos selectivos.");
runE2DMeasurements();
runE2DDiagnostics();
e2dRunTests();
summary=e2dFinalize();
end
