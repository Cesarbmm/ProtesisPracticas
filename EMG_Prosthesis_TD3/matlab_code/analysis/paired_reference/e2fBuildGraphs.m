function graphs=e2fBuildGraphs(baselines,fixedSource,out)
% Cierre bit-exacto por motor, exclusivamente mediante la API E0P canonica.
arguments
    baselines cell
    fixedSource table
    out (1,1) string
end
assert(contains(replace(lower(out),"\","/"),"e2f_results"),"E2F:OutputScope");
assert(~isempty(baselines),"E2F:MissingBaselines");
assert(all(ismember(["motor","qBefore","qAfter"],string(fixedSource.Properties.VariableNames))), ...
    "E2F:FixedSourceSchema");
if ~isfolder(out),mkdir(out);end
actions=[0 -64 64 -96 96 -128 128 -160 160 -192 192 -224 224 -255 255];
maxStates=10000;graphs=cell(1,4);rows=cell(1,4);
for motor=1:4
    seed=0;
    for k=1:numel(baselines)
        trace=baselines{k};
        assert(~any(contains(upper(string(trace.metadata.subject)),["MATEO","SANDRA"])), ...
            "E2F:SealedSubject");
        seed=[seed;trace.q(:,motor)]; %#ok<AGROW>
    end
    fixed=fixedSource(fixedSource.motor==motor,:);
    seed=[seed;fixed.qBefore;fixed.qAfter];
    assert(all(isfinite(seed)),"E2F:InvalidGraphSeed");
    % La clave conserva el double completo, incluyendo el signo de cero.
    keys=unique(cellstr(num2hex(seed)),"sorted");
    q=hex2num(char(keys));n=numel(q);initialStates=n;
    assert(n<=maxStates,"E2F:GraphStateLimit");
    indices=containers.Map(keys,num2cell(1:n));
    next=zeros(maxStates,numel(actions));cursor=1;
    while cursor<=n
        state=zeros(1,4);state(motor)=q(cursor);
        for ai=1:numel(actions)
            command=zeros(1,4);command(motor)=actions(ai);
            output=SimController.prosthesis_simulator(state,command,.2,.14, ...
                plantSource="patternCurveCanonical");
            assert(isequal(size(output),[1 4]),"E2F:PlantStepShape");
            destination=output(1,motor);key=num2hex(destination);
            if ~isKey(indices,key)
                assert(n<maxStates,"E2F:GraphStateLimit", ...
                    "Motor %d no cerro con el limite preregistrado de %d estados.",motor,maxStates);
                n=n+1;q(n,1)=destination;indices(key)=n;
            end
            next(cursor,ai)=indices(key);
        end
        cursor=cursor+1;
    end
    next=next(1:n,:);assert(all(next>=1 & next<=n,"all"),"E2F:GraphNotClosed");
    fullState=zeros(n,4);fullState(:,motor)=q;
    h=encoder2Flex(fullState)./[4092 2046 1023 2046];
    graphs{motor}=struct("motor",motor,"q",q,"next",next,"h",h(:,motor), ...
        "actions",actions,"initialStates",initialStates,"closed",true, ...
        "qHex",string(cellstr(num2hex(q))),"period",.2,"samplingPeriod",.14, ...
        "plantSource","patternCurveCanonical","maxStates",maxStates);
    [qi,ai]=ndgrid(1:n,1:numel(actions));qi=qi(:);ai=ai(:);dest=next(:);
    rows{motor}=table(repmat(motor,numel(qi),1),qi,string(cellstr(num2hex(q(qi)))), ...
        q(qi),ai,reshape(actions(ai),[],1),dest,q(dest),h(dest,motor),q(dest)-q(qi), ...
        VariableNames=["motor","qIndex","qHex","qBefore","actionIndex","pwm", ...
        "nextIndex","qAfter","hAfter","deltaQ"]);
    fprintf("E2F grafo M%d: %d semillas, %d estados cerrados, %d aristas.\n", ...
        motor,initialStates,n,n*numel(actions));
end
edges=vertcat(rows{:});writetable(edges,fullfile(out,"graph_edges.csv"));
save(fullfile(out,"graphs.mat"),"graphs","-v7.3");
end
