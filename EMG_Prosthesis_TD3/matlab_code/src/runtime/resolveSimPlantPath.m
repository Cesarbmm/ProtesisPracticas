function resolved = resolveSimPlantPath(filePath)
%resolveSimPlantPath usa pwd de MATLAB, no el directorio inicial de la JVM.
arguments
    filePath (1, 1) string
end
file = java.io.File(char(filePath));
if ~file.isAbsolute()
    file = java.io.File(pwd, char(filePath));
end
resolved = string(file.getCanonicalPath());
end
