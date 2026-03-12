function features = getWmoosFeatures(emg,C,S)
%getWmoosFeatures() is the wrapper for the Wmoos features.
%The features are:
% Standard Deviation            Wmoos_1
% Integrall Absolute Evelope    Wmoos_2
% Mean Absolute Value           Wmoos_4
% EMG Energy                    Wmoos_5
% Root mean square              Wmoos_13
%
% Inputs
%   emg     -m-by-8 raw emg
%
% Outputs
%   features  -features is f-by-1, with f = 40
%
% Ejemplo
%	getWmoosFeatures()
%

%{
Laboratorio de Inteligencia y Visión Artificial
ESCUELA POLITÉCNICA NACIONAL
Quito - Ecuador

autor: ztjona
jonathan.a.zea@ieee.org
Cuando escribí este código, solo dios y yo sabíamos como funcionaba.
Ahora solo lo sabe dios.

"I find that I don't understand things unless I try to program them."
-Donald E. Knuth

16 November 2021
Matlab R2021b.
%}

%%
X = emg';
f1 = WMoos_F1(X);
f2 = WMoos_F2(X);
f3 = WMoos_F4(X);
f4 = WMoos_F5(X);
f5 = WMoos_F13(emg);
features = [
    f1
    f2
    f3
    f4
    f5' % solve
    ];
if nargin > 1
    %normalicing
    L = size(features, 1);
    assert(L == 40, ...
        "Wrong size of EMG features msut be 40 it is %d", L)
    features = normalize(features,'center',C,'scale',S);
end