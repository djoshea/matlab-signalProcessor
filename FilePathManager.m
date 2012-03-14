classdef FilePathManager < handle

    properties
        pathRoot        
        pathSignals
        pathTrials
    end

    methods
        function obj = FilePathManager(pathRoot)
            if ~exist('pathRoot', 'var')
                pathRoot = '/expdata';
            end

            obj.pathRoot = pathRoot;
            obj.pathSignals = fullfile(obj.pathRoot, 'signals');
            obj.pathTrials = fullfile(obj.pathRoot, 'trials');

            if ~exist(obj.pathSignals, 'dir')
                mkdir(obj.pathSignals);
            end
            if ~exist(obj.pathTrials, 'dir')
                mkdir(obj.pathTrials);
            end
        end
       
        function path = getSignalsPath(obj, day)
            % getSignalsPath([day = now])
            
            % get path for today if necessary
            if ~exist('day', 'var')
                day = now;
            end

            path = fullfile(obj.pathSignals, datestr(day, 'yyyymmdd'));
        end

        function path = getSignalsIndexFile(obj, day)
            % get path for today if necessary
            if ~exist('day', 'var')
                day = now;
            end

            path = fullfile(obj.getSignalsPath(day), 'index.txt'); 
        end
        
        function path = getTrialsPath(obj, subject, protocol, day)
            % getTrialsPath(subject, protocol, [day = now])

            % get path for today if necessary
            if ~exist('day', 'var')
                day = now;
            end

            path = fullfile(obj.pathTrials, subject, protocol, ...
                datestr(day, 'yyyymmdd'));
        end

        function path = getTrialsDataFile(obj, subject, protocol, day)
            % getTrialDataFile(obj, subject, protocol, [day = now])

            % get path for today if necessary
            if ~exist('day', 'var')
                day = now;
            end

            if isempty(subject) || isempty(protocol)
                path = '?';
                return;
            end
            
            fname = sprintf('%s%s_%s.individual.mat', subject(1), ...
                datestr(day, 'yyyymmdd'), protocol);
            path = obj.getTrialsPath(subject, protocol, day);

            path = fullfile(path, fname);
        end
    end
end
