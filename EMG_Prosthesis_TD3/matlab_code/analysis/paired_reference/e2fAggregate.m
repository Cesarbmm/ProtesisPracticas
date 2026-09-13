function [macro,subjects,directions,motorsOut,groups]=e2fAggregate(metrics,motors)
fields=setdiff(string(metrics.Properties.VariableNames),["controller","subject","repetition","side","steps"],"stable");
controllers=unique(metrics.controller,"stable")';gRows={};mRows={};sRows={};dRows={};aRows={};
for controller=controllers
    for subject=unique(metrics.subject)'
        for side=1:2
            mask=metrics.controller==controller & metrics.subject==subject & metrics.side==side;
            gRows{end+1}=means(struct("controller",controller,"subject",subject,"side",side),metrics(mask,:),fields); %#ok<AGROW>
        end
    end
end
groups=struct2table([gRows{:}]);
for controller=controllers
    aRows{end+1}=means(struct("controller",controller),groups(groups.controller==controller,:),fields); %#ok<AGROW>
    for subject=unique(groups.subject)'
        sRows{end+1}=means(struct("controller",controller,"subject",subject),groups(groups.controller==controller & groups.subject==subject,:),fields); %#ok<AGROW>
    end
    for side=1:2
        dRows{end+1}=means(struct("controller",controller,"side",side),groups(groups.controller==controller & groups.side==side,:),fields); %#ok<AGROW>
    end
    for motor=1:4
        temp={};
        for subject=unique(groups.subject)'
            for side=1:2
                mask=motors.controller==controller & motors.subject==subject & motors.side==side & motors.motor==motor;
                temp{end+1}=means(struct("motor",motor),motors(mask,:),fields); %#ok<AGROW>
            end
        end
        mRows{end+1}=means(struct("controller",controller,"motor",motor),struct2table([temp{:}]),fields); %#ok<AGROW>
    end
end
macro=struct2table([aRows{:}]);subjects=struct2table([sRows{:}]);directions=struct2table([dRows{:}]);motorsOut=struct2table([mRows{:}]);
end
function row=means(row,T,fields)
for field=fields,row.(field)=mean(T.(field),"omitnan");end
end
