function T=e2eVerifyHistory
here=string(fileparts(mfilename("fullpath")));root=fileparts(fileparts(here));out=fullfile(here,"e2e_results");
prereg=fullfile(fileparts(root),"docs","paired_reference","PREREGISTRO_E2E.md");
assert(e2cSHA256(prereg)==strtrim(string(fileread(fullfile(out,"preregistration.sha256")))));
T=readtable(fullfile(out,"historical_hashes_before.csv"),TextType="string");T.currentSHA256=strings(height(T),1);
for k=1:height(T)
    assert(~contains(lower(T.path(k)),"sandbox"));
    T.currentSHA256(k)=e2cSHA256(fullfile(root,T.path(k)));
end
T.unchanged=T.sha256==T.currentSHA256;
assert(all(T.unchanged),"E2E:HistoricalMutation","Una fuente histórica cambió.");
end
