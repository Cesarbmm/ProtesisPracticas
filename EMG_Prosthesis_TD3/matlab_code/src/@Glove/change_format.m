function glove_tb = change_format(gloveData, format)
%change_format() returns the glove data in the desired format. Formats can
%have very different representations of the data. 
%
% # INPUTS
%  gloveData        struct with fields, thumb, yaw, etc...
%  format           string with name of the format
%
% # OUTPUTS
%  glove_tb         glove data in format
%

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

%% Input Validation
arguments
    gloveData
    format (1, 1) string
end


%%
switch format
    case "sum_by_finger"
        % f1 - combination of ring and pinky
        g2.little = [gloveData.pinkyUp]' + [gloveData.pinkyDown]' ...
            + [gloveData.ringUp]' + [gloveData.ringDown]';

        % f2
        g2.index = [gloveData.indexDown]' + [gloveData.indexUp]';

        %f3
        g2.thumb = [gloveData.thumb]';

        % f4
        g2.mid = [gloveData.middleDown]' + [gloveData.middleUp]';

        
        glove_tb = struct2table( g2 );
        return;

    otherwise
        error("Format %s not defined", format)
end