function data = sealedLoadData(outDir)
% sealedLoadData carga los datos de MATEO y SANDRA una vez autorizada el unblinding.
% Selecciona 10 repeticiones por sujeto (20 episodios c/u, 40 total), de forma identica
% al protocolo de desarrollo E2B-E4.

arguments
    outDir (1, 1) string = ""
end

root = string(fileparts(fileparts(fileparts(fileparts(mfilename("fullpath"))))));
folder = fullfile(root, "data", "datasets", "Denis Dataset");
subjects = ["MATEO", "SANDRA"];

selectedRows = {};
evalData = {};
inventoryRows = {};

for sIdx = 1:numel(subjects)
    subj = subjects(sIdx);
    fPath = fullfile(folder, subj + ".mat");
    assert(isfile(fPath), "Sealed:MissingFile", "Falta archivo de datos para %s.", subj);
    d = load(fPath, "emgs", "gloves");
    nRows = size(d.emgs, 1);
    validPairs = false(nRows, 1);

    for rep = 1:nRows
        el = false(1, 2);
        for side = 1:2
            e = d.emgs{rep, side};
            t = d.gloves{rep, side};
            el(side) = isnumeric(e) && size(e, 2) == 8 && size(e, 1) >= 80 && ...
                all(isfinite(e), "all") && isstruct(t) && size(t, 1) >= 4;
            inventoryRows{end+1} = struct("subject", subj, "repetition", rep, ...
                "side", side, "eligible", el(side), "emgSamples", size(e, 1), "teacherSamples", size(t, 1)); %#ok<AGROW>
        end
        validPairs(rep) = all(el);
    end

    eligible = find(validPairs);
    assert(~isempty(eligible), "Sealed:NoEligibleRows", "No se encontraron filas elegibles para %s.", subj);
    chosen = eligible(unique(round(linspace(1, numel(eligible), min(10, numel(eligible))))));

    for r = chosen(:)'
        for side = 1:2
            selectedRows{end+1} = struct("subject", subj, "repetition", r, "side", side, ...
                "split", "TEST", "emgSamples", size(d.emgs{r, side}, 1), ...
                "teacherSamples", size(d.gloves{r, side}, 1)); %#ok<AGROW>
            evalData{end+1} = struct("subject", subj, "repetition", r, "side", side, ...
                "emg", d.emgs{r, side}, "teacher", d.gloves{r, side}, ...
                "pairData", struct("emgs", {d.emgs(r, :)}, "teachers", {d.gloves(r, :)})); %#ok<AGROW>
        end
    end
end

selectionTable = struct2table([selectedRows{:}]);
inventoryTable = struct2table([inventoryRows{:}]);

if strlength(outDir) > 0 && isfolder(outDir)
    writetable(selectionTable, fullfile(outDir, "evaluation_selection.csv"));
    writetable(selectionTable, fullfile(outDir, "selected_episodes.csv"));
    writetable(inventoryTable, fullfile(outDir, "sealed_inventory.csv"));
end

data = struct("selection", selectionTable, "inventory", inventoryTable, "evaluation", {evalData});
end
