function e3axAssertEnvContract(p)
% Compara constantes efectivas ya cargadas, no sólo el override solicitado.
names=["unifyActions","episodeDuration","speeds","period","verbose","flagSaveTraining","episode_save_freq", ...
    "plotEpisodeOnTest","maxNumberStepsInEpisodes","simMotors","quantizeCommandsForSimulation", ...
    "actionCommandActivationThreshold","actionCommandLevels","enableDetailedActionDiagnostics","savePerMotorMetrics","rf_modify_actions"];
for field=names
    actual=eval("Env."+field);
    assert(isequaln(actual,p.(field)),"E3AX:StaleEnv","Env.%s conserva otra configuración. Abrir MATLAB nuevo.",field);
end
% Las funciones anónimas de configurables capturan parámetros de su creación.
assert(strcmp(func2str(Env.encoderNormCalculator),func2str(p.encoder2state_scale)),"E3AX:StaleEnv");
assert(strcmp(func2str(Env.flexJoined_scaler),func2str(p.flexJoined_scale)),"E3AX:StaleEnv");
assert(isequaln(Env.encoderNormCalculator([1;100;5000;9000]),p.encoder2state_scale([1;100;5000;9000])),"E3AX:StaleEnv");
assert(isequaln(Env.flexJoined_scaler([4092 2046 1023 2046]),p.flexJoined_scale([4092 2046 1023 2046])),"E3AX:StaleEnv");
f=functions(Env.featureCalculator);g=functions(p.fGetFeatures);
assert(strcmp(f.function,g.function) && isequaln(f.workspace{1}.params.norm,g.workspace{1}.params.norm),"E3AX:StaleEnv");
r=functions(Env.reward_function);s=functions(p.reward_function);
assert(strcmp(r.function,s.function) && strcmp(r.workspace{1}.params.rewardType,s.workspace{1}.params.rewardType),"E3AX:StaleEnv");
end
