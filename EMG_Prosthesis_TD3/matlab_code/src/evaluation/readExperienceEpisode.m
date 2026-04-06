function experiences = readExperienceEpisode(fileName)
%readExperienceEpisode reads one saved demonstration trajectory.

data = load(fileName);

if isfield(data, "episodeData") && isfield(data.episodeData, "Experience")
    experiences = data.episodeData.Experience;
elseif isfield(data, "Experience")
    experiences = data.Experience;
else
    error("Experience file %s does not contain episodeData.Experience.", fileName);
end

for i = 1:numel(experiences)
    if ~iscell(experiences(i).Observation)
        experiences(i).Observation = {experiences(i).Observation};
    end
    if ~iscell(experiences(i).Action)
        experiences(i).Action = {experiences(i).Action};
    end
    if ~iscell(experiences(i).NextObservation)
        experiences(i).NextObservation = {experiences(i).NextObservation};
    end
end
end
