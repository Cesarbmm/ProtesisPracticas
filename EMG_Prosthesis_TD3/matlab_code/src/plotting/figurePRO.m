function [theAx, theFig] = figurePRO(idx)
% creates and axes to plotting with enhanced characteristics. 

%{
Laboratorio de Inteligencia y Visión Artificial
ESCUELA POLITÉCNICA NACIONAL
Quito - Ecuador

autor: Jonathan Zea
jonathan.a.zea@ieee.org

"I find that I don't understand things unless I try to program them."
-Donald E. Knuth

02 January 2024
%}


if nargin == 1
    theFig = figure(idx);
    clf(theFig)
else
    theFig = figure;
    % detecting if docked
    if ~isequal(theFig.Position(1:2), [1 1])
        theFig.WindowState = 'maximized';
    end
end


theFig.PaperOrientation = 'landscape';

theAx = axes(theFig, 'fontSize', 25); 
hold(theAx, 'on');
