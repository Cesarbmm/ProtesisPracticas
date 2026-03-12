%saving_dataset saves the Denis dataset by person.

%{
Laboratorio de Inteligencia y Visión Artificial
ESCUELA POLITÉCNICA NACIONAL
Quito - Ecuador

autor: Laboratorio IA
jonathan.a.zea@ieee.org

"I find that I don't understand things unless I try to program them."
-Donald E. Knuth

18 January 2024
%}

cc all
%% Configs
dataset_denis = "./development/04 adapt dataset Denis/datos_guante/";
users = {"CECILIA", "GABI", "MATEO", "DENIS", "GABRIEL", "JONATHAN", ...
"EMILIA", "IVANNA", "KHAROL", "BLANCA", "SANDRA", "JOE"};

speeds = {"FAST", "SLOW", "MEDIUM"};
% %% Aux and dependent variables
% % libs
% addpath(genpath('src'))

output_folder = "data\datasets\Denis RAW 0\";
%%
for u = users
    metadata = struct();
    
    emgs = {};
    gloves = {};


    for s = speeds
        f = dir(fullfile(dataset_denis, u{1}, s{1}));
        if size(f, 1) ~= 202
            warning("%s %s has %d files!\n", u{1}, s{1}, size(f, 1) - 2);
        end

        Print(sprintf("User %s | speed %s\n", u{1}, s{1}));

        for ff = f'
            if ff.isdir
                continue
            end

            msg = Print(ff.name);

            vars = load(fullfile(ff.folder, ff.name));

            % --- only first time
            if ~isfield(metadata, u{1})
                metadata.(u{1}).gender = vars.genero;
                metadata.(u{1}).acquisition_date = vars.fechaHora;
                metadata.(u{1}).files = {};
            end

            metadata.(u{1}).files{end + 1} = ff.name;

            % -- verify
            emgs{end + 1} = vars.myo;
            gloves{end + 1} = vars.glove;

            msg.clear();
        end
    end

    metadata.(u{1}).files = reshape(metadata.(u{1}).files, 2, [])';

    emgs = reshape(emgs, 2, [])';
    gloves = reshape(gloves, 2, [])';

    % --- checkings
    for fn = metadata.(u{1}).files'
        close = fn{1};
        open = fn{2};
        cs = strsplit(close, "_");
        os = strsplit(open, "_");
        
        assert(isequal(cs{1}, os{1}))
        assert(isequal(cs{2}, os{2}))
        assert(isequal(cs{3}, "close"))
        assert(isequal(os{3}, "open"))
        assert(isequal(cs{4}, os{4}))
        assert(isequal(cs{5}, os{5}))
    end

    save(fullfile(output_folder, u{1}), "gloves", "emgs","metadata")
end
