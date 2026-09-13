function T=e3dIntentMetrics(dir,phase,S)
rows={};
for split=["TRAIN","VALIDATION"]
    subjects=["ALL";unique(S.subject(S.split==split))];
    for subject=subjects'
        ix=find(S.split==split & (subject=="ALL" | S.subject==subject));
        for task=["direction","phase_direction"]
            if task=="direction",p=dir(:,ix);y=S.side(ix)';K=2;else,p=phase(:,ix);y=S.phaseDirection(ix)';K=6;end
            [~,pred]=max(p,[],1);cm=accumarray([y',pred'],1,[K K]);f1=zeros(K,1);
            for k=1:K,den=sum(cm(k,:))+sum(cm(:,k));if den>0,f1(k)=2*cm(k,k)/den;end;end
            chosen=p(sub2ind(size(p),y,1:numel(y)));
            rows{end+1}=struct("split",split,"subject",subject,"task",task,"samples",numel(ix),"macroF1",mean(f1),"NLL",mean(-log(max(chosen,realmin))),"accuracy",mean(pred==y)); %#ok<AGROW>
        end
    end
end
T=struct2table([rows{:}]);
end
