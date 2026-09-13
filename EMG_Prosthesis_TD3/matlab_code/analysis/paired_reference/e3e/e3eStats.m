classdef e3eStats
    % e3eStats: Funciones estadísticas de base implementadas exclusivamente con
    % funciones núcleo de MATLAB (sin depender de Statistics and Machine Learning Toolbox).
    methods (Static)
        function y = prctile(x, p)
            x = sort(x(~isnan(x)));
            N = numel(x);
            if N == 0, y = NaN; return; end
            if N == 1, y = x(1); return; end
            p = p(:);
            q = (p / 100) * (N - 1) + 1;
            k = floor(q);
            d = q - k;
            k = max(1, min(N, k));
            k_next = max(1, min(N, k + 1));
            y = x(k) + d .* (x(k_next) - x(k));
        end

        function y = iqr(x)
            p75 = e3eStats.prctile(x, 75);
            p25 = e3eStats.prctile(x, 25);
            y = p75 - p25;
        end

        function y = mad(x)
            med = median(x(~isnan(x)));
            y = median(abs(x(~isnan(x)) - med));
        end

        function [tStat, pVal] = ttest2(x1, x2)
            x1 = x1(~isnan(x1));
            x2 = x2(~isnan(x2));
            n1 = numel(x1);
            n2 = numel(x2);
            if n1 < 2 || n2 < 2
                tStat = NaN; pVal = NaN; return;
            end
            m1 = mean(x1); m2 = mean(x2);
            v1 = var(x1); v2 = var(x2);
            se = sqrt(v1 / n1 + v2 / n2);
            if se < 1e-12
                tStat = 0; pVal = 1; return;
            end
            tStat = (m1 - m2) / se;

            % Welch-Satterthwaite degrees of freedom
            dfNum = (v1 / n1 + v2 / n2)^2;
            dfDen = ((v1 / n1)^2 / (n1 - 1)) + ((v2 / n2)^2 / (n2 - 1));
            df = max(1, dfNum / max(dfDen, 1e-12));

            % Two-tailed p-value from Student's t via incomplete beta function
            betaArg = df / (df + tStat^2);
            pVal = betainc(betaArg, df / 2, 0.5);
        end

        function [coeff, score, latent, explained] = pca(X)
            % X es N x D (cada fila es una muestra, cada columna un feature)
            % Centrar X
            [N, D] = size(X);
            mu = mean(X, 1);
            Xc = X - mu;

            % Matriz de covarianza
            C = (Xc' * Xc) / max(1, N - 1);

            % Descomposición espectral
            [V, D_mat] = eig(C);
            eigVals = diag(D_mat);

            % Ordenar descendente
            [latent, sortIdx] = sort(eigVals, 'descend');
            coeff = V(:, sortIdx);

            % Proyección de scores
            score = Xc * coeff;

            % Varianza explicada (%)
            totalVar = sum(latent);
            if totalVar > 1e-12
                explained = 100 * (latent / totalVar);
            else
                explained = zeros(size(latent));
            end
        end
    end
end
