function isDone = checkEndEpisode(this)
%this.checkEndEpisode returns the flag isDone when the episode has
%finished. When using prerecorded, waits till data is exhausted, ignores episode duration.


% # ---- motors are still in the home position after a period of time

% # ---- the hand reached the desired position

% # ---- the episode was too long
% when prerecorded
if this.usePrerecorded
    % ignores episode duration when using prerecorded
    isDone = this.myo.exhausted || this.glove.exhausted;
else
    isDone = this.episodeTic.elapsed_time >= this.episodeDuration;
end
this.isDone = isDone;
end
