classdef E3AXSession < handle
    % Callbacks de un único train. Nunca reinicia agente ni Env para evaluar.
    properties
        cfg
        out
        data
        records = struct([])
        lastLogged = 0
    end
    methods
        function obj=E3AXSession(cfg,out,data)
            obj.cfg=cfg;obj.out=out;obj.data=data;
        end
        function [statistic,scores,evaluationData]=evaluate(obj,agent,env,info)
            statistic=[];scores=[];evaluationData=[];episode=info.EpisodeIndex;
            if ~ismember(episode,obj.cfg.checkpoints),return;end
            try
                checkpoint=obj.saveCheckpoint(agent,env,episode);
                validation=obj.data.evaluation(cellfun(@(x) x.split=="VALIDATION",obj.data.evaluation));
                folder=fullfile(obj.out,"evaluation","checkpoints",sprintf("Episode%05d",episode));
                result=e3axEvaluate(checkpoint,validation,folder,"TD3_Episode"+episode,false);
                obj.recordEvaluation(result,episode);
                episodeMetrics=readtable(fullfile(folder,"metrics","episode_metrics.csv"));
                statistic=result.reward;scores=episodeMetrics.rewardMean;
                evaluationData=struct("path",folder,"episodes",result.episodes,"metric","reward macro VALIDATION original","episodeScoreMetric","reward medio por episodio");
            catch ex
                e2cWriteJSON(fullfile(obj.out,"EVALUATION_ERROR.json"),struct("episode",episode,"message",ex.message,"report",getReport(ex,'extended','hyperlinks','off')));
                rethrow(ex);
            end
        end
        function recordEvaluation(obj,result,episode)
            result.episode=episode;
            if isempty(obj.records),obj.records=result;else,obj.records(end+1)=result;end
            writetable(struct2table(obj.records),fullfile(obj.out,"checkpoint_validation.csv"));
        end
        function checkpoint=saveCheckpoint(obj,agent,env,episode)
            checkpoint=fullfile(obj.out,"checkpoints",sprintf("AgentEpisode%06d.mat",episode));
            assert(~isfile(checkpoint),"E3AX:CheckpointExists","No sobrescribir %s",checkpoint);
            saved_agent=agent;saved_actor=getActor(agent);cfg=obj.cfg;rngState=rng; %#ok<NASGU>
            envSchedule=struct("episodeCounter",env.episodeCounter,"repetitionId",env.repetitionId,"episodes_shuffled",env.episodes_shuffled, ...
                "episodeType",string(env.episodeType),"q",env.motorData(end,:)); %#ok<NASGU>
            checkpointInfo=struct("episode",episode,"agentCheckpointAvailable",true,"fullTrainingResumeAvailable",false, ...
                "infoToSave",agent.AgentOptions.InfoToSave,"note","Buffer/optimizers/targets requested; exact full-session resume not implemented or validated"); %#ok<NASGU>
            temporary=checkpoint+".writing.mat";save(temporary,"saved_agent","saved_actor","cfg","rngState","envSchedule","checkpointInfo","-v7.3");
            assert(~isfile(checkpoint));[ok,msg]=movefile(temporary,checkpoint);assert(ok,"E3AX:CheckpointWrite","%s",msg);
            e2cWriteJSON(checkpoint+".json",checkpointInfo);fprintf("Checkpoint durable: %s\n",checkpoint);
        end
        function answer=logEpisode(obj,info)
            % R2023b AbstractTrainOptions entrega info.TrainingStatistics.
            answer=false;ep=info.EpisodeIndex(end);
            if ep<=obj.lastLogged,return;end
            row=table(ep,info.EpisodeReward(end),info.AverageReward(end),info.EpisodeSteps(end),info.AverageSteps(end),info.EpisodeQ0(end),info.TotalAgentSteps(end), ...
                VariableNames=["EpisodeIndex","EpisodeReward","AverageReward","EpisodeSteps","AverageSteps","EpisodeQ0","TotalAgentSteps"]);
            file=fullfile(obj.out,"training_incremental.csv");
            if isfile(file),writetable(row,file,WriteMode="append",WriteVariableNames=false);else,writetable(row,file);end
            obj.lastLogged=ep;
            if ismember(ep,obj.cfg.checkpoints)
                trainingStatsAtCheckpoint=info;rngState=rng; %#ok<NASGU>
                file=fullfile(obj.out,"checkpoints",sprintf("TrainingEpisode%06d.mat",ep));assert(~isfile(file));
                save(file,"trainingStatsAtCheckpoint","rngState","-v7.3");
            end
        end
    end
end
