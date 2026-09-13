function tests=testPairedReferenceE2CIntegrity
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.root=fileparts(fileparts(fileparts(mfilename("fullpath"))));
t.TestData.oldPath=path;addpath(fullfile(t.TestData.root,"analysis","paired_reference"));
end
function teardownOnce(t)
path(t.TestData.oldPath);
end
function testHistoricalSourcesUnchanged(t)
root=t.TestData.root;T=readtable(fullfile(root,"analysis","paired_reference","e2c_results", ...
    "historical_hashes_before.csv"),TextType="string");
verifyGreaterThanOrEqual(t,height(T),453);
for k=1:height(T),verifyEqual(t,e2cSHA256(fullfile(root,T.path(k))),T.sha256(k));end
end
function testPreregistrationAndOriginalMotorSourcesUnchanged(t)
root=t.TestData.root;
verifyEqual(t,e2cSHA256(fullfile(fileparts(root),"docs","paired_reference","PREREGISTRO_E2C.md")), ...
    "bddb7f8f45b6e6e9cbceb45f3c082c2d1a1694b60ed2de3bb1ec3ca1a46d4013");
T=readtable(fullfile(root,"analysis","paired_reference","e2c_results","m3_raw_provenance.csv"),TextType="string");
for k=1:height(T),verifyEqual(t,e2cSHA256(T.file(k)),T.sha256(k));end
end
