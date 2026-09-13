function tests=testE3FSubjectInvariantPPO
tests=functiontests(localfunctions);
end

function setupOnce(t)
root=string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
pr=fullfile(root,"analysis","paired_reference");
oldPath=path;t.addTeardown(@() path(oldPath));
addpath(root,pr,fullfile(pr,"e3f"),fullfile(pr,"e3b"),fullfile(pr,"e3ax"),fullfile(pr,"cap192"),fullfile(root,"config"));
addpath(genpath(fullfile(root,"src")));addpath(genpath(fullfile(root,"lib")));
t.TestData.root=root;t.TestData.pr=pr;
t.TestData.cfg=e3fConfig("smoke");
[t.TestData.emg,t.TestData.teacher]=loadE2ADevelopmentEpisode("BLANCA",1,1,includeTeacher=true);
end

function setup(t)
old=struct();if isappdata(0,"configurables_override"),old=getappdata(0,"configurables_override");end
r=rng;t.addTeardown(@() rng(r));t.addTeardown(@() setConfigurablesOverride(old));
bc=e3axConfig("smoke");bc.seed=t.TestData.cfg.seed;
o=e3axOverride(bc);o.run_training=false;o.newTraining=false;setConfigurablesOverride(o);
end

function testGRLForwardIdentity(t)
layer=e3fGradientReversalLayer("test_grl",0.10);
X=dlarray(randn(10,5,"single"));
Z=predict(layer,X);
verifyEqual(t,extractdata(Z),extractdata(X),AbsTol=1e-7);
end

function testGRLGradientSignAndMagnitude(t)
% Mini-batch fijo
lambda=0.10;
rng(42);
X_emg=dlarray(randn(40,4,"single"),"CB");
y_sub=[1 2 3 4];

% Red CON GRL
[actor_grl,~,disc_grl]=e3fNetworks(t.TestData.cfg);
% Red SIN GRL (lambda = -1 para cancelar inversión, o GRL con lambda=-1 => backward = +dLdZ)
disc_normal_layers=[
    featureInputLayer(64,Normalization="none",Name="disc_in")
    fullyConnectedLayer(32,Name="disc_fc1")
    reluLayer(Name="disc_relu1")
    fullyConnectedLayer(7,Name="subject_logits")
];
disc_normal=dlnetwork(disc_normal_layers);
disc_normal.Learnables.Value=disc_grl.Learnables.Value(ismember(disc_grl.Learnables.Layer,["disc_fc1","subject_logits"]));

% Evaluar gradientes
[g_enc_grl,loss_grl]=dlfeval(@evalEncoderGrad,actor_grl,disc_grl,X_emg,y_sub);

% Para la red normal, clonamos learnables de actor
actor_normal=actor_grl;
[g_enc_norm,loss_norm]=dlfeval(@evalEncoderGradNormal,actor_normal,disc_normal,X_emg,y_sub);

verifyEqual(t,loss_grl,loss_norm,AbsTol=1e-5);

% Comprobar producto punto negativo y magnitud
dotProd=0;normGRL=0;normNorm=0;
for i=1:numel(g_enc_grl)
    v_grl=double(extractdata(g_enc_grl{i}));
    v_norm=double(extractdata(g_enc_norm{i}));
    dotProd=dotProd+sum(v_grl.*v_norm,"all");
    normGRL=normGRL+sum(v_grl.^2,"all");
    normNorm=normNorm+sum(v_norm.^2,"all");
end
normGRL=sqrt(normGRL);normNorm=sqrt(normNorm);

verifyTrue(t,dotProd < 0,"El producto punto debe ser negativo (inversion de gradiente).");
ratio=normGRL/normNorm;
verifyEqual(t, ratio, lambda, RelTol=1e-4);
end

function testSubjectDiscriminatorSevenClasses(t)
[~,~,disc]=e3fNetworks(t.TestData.cfg);
verifyEqual(t,disc.Layers(end).OutputSize,7);
verifyEqual(t,numel(t.TestData.cfg.trainSubjects),7);
end

function testMechanicalBranchAbsentFromDiscriminator(t)
cfg=t.TestData.cfg;
[actor,~,disc]=e3fNetworks(cfg);
% Verificar conexiones del layerGraph del actor
emg_latent_layer=actor.Layers(strcmp({actor.Layers.Name},"emg_latent"));
verifyFalse(t,isempty(emg_latent_layer));
% El discriminador solo recibe 64 entradas
verifyEqual(t,disc.Layers(1).InputSize,64);
end

function testActorInferenceIndependentOfSubjectLabel(t)
[actor,~,~]=e3fNetworks(t.TestData.cfg);
act=E3FActor(actor);
s=zeros(52,1);
action=getAction(act,{s});
verifySize(t,action{1},[4 1]);
verifyTrue(t,all(isfinite(action{1})));
end

function testCategoricalActionsExact(t)
expected=[0 -64 64 -96 96 -128 128 -160 160 -192 192 -224 224 -255 255];
verifyEqual(t,e3fCategoryPWM(repmat(1:15,4,1)),repmat(expected,4,1));
verifyEqual(t,e3fCategoryPWM([2;5;10;15]),[-64;96;-192;255]);
verifyError(t,@() e3fCategoryPWM([0;1;1;1]),"E3F:Category");
verifyError(t,@() e3fCategoryPWM([16;1;1;1]),"E3F:Category");
verifyError(t,@() e3fCategoryPWM([2.5;1;1;1]),"E3F:Category");
end

function testSixtyTransitionAndRewardEquivalences(t)
emg=t.TestData.emg;teacher=t.TestData.teacher;
catEnv=e3fTrainingEnv({emg,emg},{teacher,teacher},[1;1]);
legacy=Env("",true,{emg,emg},{teacher,teacher});
levels=[0 -64 64 -96 96 -128 128 -160 160 -192 192 -224 224 -255 255];
for motor=1:4
    for c=1:15
        rng(55);s=reset(catEnv);rng(55);sl=reset(legacy);
        verifyEqual(t,s,sl);
        q0=catEnv.Historical.motorData(end,:);pwm=zeros(4,1);pwm(motor)=levels(c);category=ones(4,1);category(motor)=c;
        clock=Timing(false,.2);plant=SimController(clock);plant.resetBuffer(q0);
        plant.sendAllSpeed(pwm(1),pwm(2),pwm(3),pwm(4));clock.toc(1);direct=plant.read();
        [sc,rc,dc,rec]=step(catEnv,category);[sh,rh,dh]=step(legacy,pwm/255);
        verifyEqual(t,rec.pwm,pwm);verifyEqual(t,rec.effectiveAction,pwm/255);
        verifyEqual(t,rec.q,direct(end,:));verifyEqual(t,rec.q,legacy.motorData(end,:));
        verifyEqual(t,sc,sh);verifyEqual(t,rc,rh);verifyEqual(t,dc,dh);
    end
end
end

function testNoSealedSubjects(t)
cfg=t.TestData.cfg;
verifyFalse(t,any(ismember(cfg.trainSubjects,["MATEO","SANDRA"])));
verifyFalse(t,any(ismember(cfg.validationSubjects,["MATEO","SANDRA"])));
verifyEqual(t,cfg.sealedSubjects,["MATEO","SANDRA"]);
end

function testDeterminism(t)
cfg=e3fConfig("smoke");
rng(cfg.seed,"twister");[a1,c1,d1]=e3fNetworks(cfg);
rng(cfg.seed,"twister");[a2,c2,d2]=e3fNetworks(cfg);
verifyEqual(t,a1.Learnables.Value,a2.Learnables.Value);
verifyEqual(t,c1.Learnables.Value,c2.Learnables.Value);
verifyEqual(t,d1.Learnables.Value,d2.Learnables.Value);
end

function testHistoricalIntegrity(t)
res=jsondecode(fileread(fullfile(t.TestData.pr,"e3f_results","integrity_before.json")));
verifyTrue(t,res.pass);
verifyEqual(t,numel(res.failures),0);
verifyEqual(t,res.files,7641);
end

% Funciones auxiliares para gradientes analiticos
function [g_enc,lossVal]=evalEncoderGrad(actor,disc,X_emg,y_sub)
mech=dlarray(zeros(12,numel(y_sub),"single"),"CB");
[latent,~,~,~,~]=forward(actor,X_emg,mech,Outputs=["emg_latent","head1","head2","head3","head4"]);
disc_logits=forward(disc,latent);
shift=disc_logits-max(disc_logits,[],1);
logProb=shift-log(sum(exp(shift),1));
idx=sub2ind(size(disc_logits),y_sub,1:numel(y_sub));
loss=-mean(logProb(idx),"all");
g_all=dlgradient(loss,actor.Learnables);
lossVal=double(extractdata(loss));
encMask=ismember(actor.Learnables.Layer,["emg_fc1","emg_fc2"]);
g_enc=g_all.Value(encMask);
end

function [g_enc,lossVal]=evalEncoderGradNormal(actor,disc,X_emg,y_sub)
mech=dlarray(zeros(12,numel(y_sub),"single"),"CB");
[latent,~,~,~,~]=forward(actor,X_emg,mech,Outputs=["emg_latent","head1","head2","head3","head4"]);
disc_logits=forward(disc,latent);
shift=disc_logits-max(disc_logits,[],1);
logProb=shift-log(sum(exp(shift),1));
idx=sub2ind(size(disc_logits),y_sub,1:numel(y_sub));
loss=-mean(logProb(idx),"all");
g_all=dlgradient(loss,actor.Learnables);
lossVal=double(extractdata(loss));
encMask=ismember(actor.Learnables.Layer,["emg_fc1","emg_fc2"]);
g_enc=g_all.Value(encMask);
end
