function summary=runE3FSmokeTest()
% Ejecuta el smoke test de E3F (6 episodios) de forma determinista y reproducible.
root=fileparts(mfilename("fullpath"));
addpath(root);
summary=runE3FTraining(mode="smoke");
end
