classdef TrialDataSaver

    properties(Hidden)
        pathMgr 
        day
    end

    properties
        subject = '';
        protocol = '';
    end

    properties(Dependent)
        dayStr
        matFile 
        maxTrialIdInFile
        trialIdsInFile
    end

    methods
        function obj = TrialDataSaver(subject, protocol, day)
            % TrialDataSaver(subject, protocol, [day = now])
            obj.pathMgr = FilePathManager();

            if exist('subject', 'var')
                obj.subject = subject;
            end
            if exist('protocol', 'var')
                obj.protocol = protocol;
            end

            if ~exist('day', 'var')
                day = now;
            end
            obj.day = day;
        end

        function path = get.matFile(obj)
            path = obj.pathMgr.getTrialsDataFile(obj.subject, obj.protocol, obj.day);
        end

        function dayStr = get.dayStr(obj)
            dayStr = datestr(obj.day, 'yyyy-mm-dd');
        end

        function trialIds = get.trialIdsInFile(obj)
            if ~exist(obj.matFile, 'file')
                trialIds = [];
                return;
            end
            vars = whos('-file', obj.matFile, '-regexp', '^r\d+$');
            
            trialIds = arrayfun(@(v) str2num(getfield(regexp(v.name, 'r(?<id>\d+)', 'names'), 'id')), vars);
        end
                
        function trialId = get.maxTrialIdInFile(obj)
            trialIds = obj.trialIdsInFile;
            if isempty(trialIds)
                trialId = 0;
            else
                trialId = max(trialIds);
            end
        end

        function assertOkayToSave(obj)
            assert(~isempty(obj.subject) && ischar(obj.subject), 'Specify .subject string before saving');
            assert(~isempty(obj.protocol) && ischar(obj.protocol), 'Specify .protocol string before saving');
        end

        function saveTrial(obj, r, trialId)
            % saveTrial(r, [trialId])
            % if trialId is specified, it is used, though an error is thrown if it overwrites a trial with the same id in the file
            % if not specified, the smallest integer trialId which is not found in the mat file will be used automatically

            obj.assertOkayToSave();
            matFile = obj.matFile;
            assert(~isempty(r) && isstruct(r), 'Trial data must be a structure');

            trialIds = obj.trialIdsInFile;
            if ~exist('trialId', 'var')
                % automatically use the next available trial id
                if isempty(trialIds)
                    trialId = 1;
                else
                    trialId = max(trialIds) + 1;
                end
            end

            varNameFn = @(trialId) sprintf('r%d', trialId);
            varName = varNameFn(trialId);

            assert(~ismember(trialId, trialIds), 'Trial with id %d already found within mat file', trialId);

            % create the directory for the mat file in case it doesn't exist
            matFileDir = fileparts(matFile);
            if ~exist(matFileDir)
                fprintf('Creating directory %s\n', matFileDir);
                mkdir(matFileDir);
            end

            % save this trial
            data.(varName) = r;
            fprintf('Saving %6s in %s\n', varName, matFile);
            if exist(matFile, 'file')
                save(matFile, '-struct', 'data', '-append');
            else
                save(matFile, '-struct', 'data');
            end
        end
    end


end
