function e2cArtifactManifest(out)
files=dir(fullfile(out,"*"));sources={};
for file=files'
    if file.isdir || string(file.name)=="artifact_manifest.json",continue,end
    sources{end+1}=struct("file",string(file.name),"bytes",file.bytes, ...
        "sha256",e2cSHA256(fullfile(out,file.name))); %#ok<AGROW>
end
e2cWriteJSON(fullfile(out,"artifact_manifest.json"),struct("artifacts",[sources{:}]));
end
