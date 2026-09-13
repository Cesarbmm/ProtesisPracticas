function [macro,subjects,directions,motorsOut,groups]=e2eAggregate(metrics,motors)
% Misma ponderación temporal/episodio/sujeto-lado de E2B/E2D.
fields=setdiff(string(metrics.Properties.VariableNames),["enabled","subject","repetition","side","steps"],"stable");
gRows={};mRows={};sRows={};dRows={};aRows={};
for enabled=[0 1]
    for subject=unique(metrics.subject)'
        for side=1:2
            mask=metrics.enabled==enabled & metrics.subject==subject & metrics.side==side;
            gRows{end+1}=means(struct("enabled",enabled,"subject",subject,"side",side),metrics(mask,:),fields); %#ok<AGROW>
        end
    end
end
groups=struct2table([gRows{:}]);
for enabled=[0 1]
    aRows{end+1}=means(struct("enabled",enabled),groups(groups.enabled==enabled,:),fields); %#ok<AGROW>
    for subject=unique(groups.subject)'
        sRows{end+1}=means(struct("enabled",enabled,"subject",subject),groups(groups.enabled==enabled & groups.subject==subject,:),fields); %#ok<AGROW>
    end
    for side=1:2
        dRows{end+1}=means(struct("enabled",enabled,"side",side),groups(groups.enabled==enabled & groups.side==side,:),fields); %#ok<AGROW>
    end
    for motor=1:4
        temp={};
        for subject=unique(groups.subject)'
            for side=1:2
                mask=motors.enabled==enabled & motors.subject==subject & motors.side==side & motors.motor==motor;
                temp{end+1}=means(struct("motor",motor),motors(mask,:),fields); %#ok<AGROW>
            end
        end
        mRows{end+1}=means(struct("enabled",enabled,"motor",motor),struct2table([temp{:}]),fields); %#ok<AGROW>
    end
end
macro=struct2table([aRows{:}]);subjects=struct2table([sRows{:}]);directions=struct2table([dRows{:}]);motorsOut=struct2table([mRows{:}]);
end
function row=means(row,T,fields)
for field=fields,row.(field)=mean(T.(field),"omitnan");end
end
