function [T,C]=e3cImitationMetrics(P,Y,S)
rows={};conf={};
for split=["TRAIN","VALIDATION"]
    for dimension=["all","direction","subject"]
        values="ALL";if dimension=="direction",values=["1","2"];elseif dimension=="subject",values=unique(S.subject(S.split==split))';end
        for value=values
            ix=S.split==split;if dimension=="direction",ix=ix & S.side==str2double(value);elseif dimension=="subject",ix=ix & S.subject==value;end
            indices=find(ix);n=numel(indices);if n==0,continue;end
            p=P(:,:,indices);y=Y(:,indices);[~,pred]=max(p,[],1);pred=reshape(pred,4,[]);[~,order]=sort(p,1,'descend');
            head=zeros(4,4);nll=zeros(4,n);
            for m=1:4
                cm=accumarray([y(m,:)',pred(m,:)'],1,[15,15]);f1=zeros(15,1);
                for c=1:15
                    den=sum(cm(c,:))+sum(cm(:,c));if den>0,f1(c)=2*cm(c,c)/den;end
                    for j=1:15,conf{end+1}=struct("split",split,"dimension",dimension,"value",value,"motor",m,"truth",c,"prediction",j,"count",cm(c,j));end %#ok<AGROW>
                end
                for k=1:n,nll(m,k)=-log(max(p(y(m,k),m,k),realmin));end
                top2=reshape(order(1:2,m,:),2,[]);
                head(m,:)=[mean(pred(m,:)==y(m,:)),mean(f1),mean(nll(m,:)),mean(any(top2==y(m,:),1))];
                rows{end+1}=struct("split",split,"dimension",dimension,"value",value,"motor",m,"samples",n, ...
                    "accuracy",head(m,1),"macroF1",head(m,2),"NLL",head(m,3),"top2",head(m,4), ...
                    "jointExact",mean(all(pred==y,1)),"jointNLL",mean(sum(nll(1:m,:),1))); %#ok<AGROW>
            end
            % Joint NLL completo para cada fila, no suma parcial por motor.
            for k=numel(rows)-3:numel(rows),rows{k}.jointNLL=mean(sum(nll,1));end
            rows{end+1}=struct("split",split,"dimension",dimension,"value",value,"motor",0,"samples",n, ...
                "accuracy",mean(head(:,1)),"macroF1",mean(head(:,2)),"NLL",mean(head(:,3)),"top2",mean(head(:,4)), ...
                "jointExact",mean(all(pred==y,1)),"jointNLL",mean(sum(nll,1))); %#ok<AGROW>
        end
    end
end
T=struct2table([rows{:}]);C=struct2table([conf{:}]);
end
