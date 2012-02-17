
classdef IndexedFileLoader < handle
% obj = IndexedFileLoader(indexFileName, dataDir, fileLoadFn)
%
% This class monitors an index file which contains a list of filenames to load.
% As other programs append lines to this file, if you call poll(),
% this class will read the new lines that have been written, 
% run some function to load that file (fileLoadFn, default is just @load)
% and return the results.
%
% You can also have the class periodically poll() using a timer object(). You can
% control the timer using start() and stop(). Whenever new files have been loaded
% the function .updateFn will be called with the new data that was loaded.
%
% The function wraps the calls to fileLoadFn and updateFn in try catch blocks such
% that if your callback function throws an exception, the file loader will rewind
% back to its state before loading that block of data. In other words, if something
% goes wrong, you can fix it and resume just by calling poll() or start() again
% without missing any files added to the index.

	properties
        indexFileName % path to the index file
        indexFid % file handle for index file
        dataDir % path to find each file within

        cachedIndexPosition = 0; % position in index file after last successful poll

        fileLoadFn = @load % function to process file with, must accept filename arg

        hPollTimer % timer for periodic polling
        updateFn % callback to call with newData from polling
        pollPeriod = 0.5;
	end

	methods
        % constructor
        function obj = IndexedFileLoader(indexFileName, dataDir, fileLoadFn)
            obj.indexFileName = indexFileName;

            if ~exist('dataDir', 'var')
                dataDir = fileparts(obj.indexFileName);
            end
            obj.dataDir = dataDir;

            if exist('fileLoadCallback', 'var')
                obj.fileLoadCallback = fileLoadFn;
            end
        end

        % destructor
        function delete(obj)
            % close the index file
            if ~isempty(obj.indexFid) && obj.indexFid ~= -1
                fclose(obj.indexFid);
            end

            % delete the timer
            obj.stop();
        end

        % open the index file
        function initialize(obj)
            assert(exist(obj.indexFileName, 'file') ~= 0, ...
                'Cannot find index file %s', obj.indexFileName);

            assert(exist(obj.dataDir, 'dir') ~= 0, ...
                'Cannot find data directory %s', obj.dataDir);

            % open file for reading
            obj.indexFid = fopen(obj.indexFileName, 'r');
            if obj.indexFid == -1
                error('Could not open index file %s', obj.indexFid);
            end

            obj.reset();
        end

        % check the index file for new entries, load them and return results
        function newData = poll(obj, maxFiles)
            if ~exist('maxFiles', 'var')
                maxFiles = Inf;
            end

            if isempty(obj.indexFid)
                obj.initialize();
            end

            newData = []; 
            idx = 1;
            while(idx <= maxFiles)
                line = fgetl(obj.indexFid);

                if line == -1
                    break;
                end

                filePath = fullfile(obj.dataDir, line);
                assert(exist(filePath, 'file') ~= 0, ...
                    'Cannot open new file %s', filePath);

                newData(idx).file = filePath;

                try
                    newData(idx).data = obj.fileLoadFn(filePath);
                catch exc
                    % something went wrong in the callback
                    % revert to our prior position in the index file
                    % and rethrow the exception
                    fprintf('Error evaluating fileLoadFn on %s\nRewinding index file.\n', filePath);
                    obj.rewindToCachedIndexPosition();
                    obj.stop();
                    rethrow(exc);
                end
                idx = idx + 1;
            end
            
            % cache where we are in case something goes wrong next time
            obj.cachedIndexPosition = ftell(obj.indexFid);
        end

        % start at the beginning of the index file
        function reset(obj)
            assert(~isempty(obj.indexFid), 'No open index file yet.');

            obj.stop();
            fseek(obj.indexFid, 0, 'bof');

            obj.cachedIndexPosition = ftell(obj.indexFid);
        end

        % rewind in the index file to where it was before the last call to poll()
        function rewindToCachedIndexPosition(obj)
            assert(~isempty(obj.indexFid) & ~isempty(obj.cachedIndexPosition));
            fseek(obj.indexFid, obj.cachedIndexPosition, 'bof');
        end

        % begin timed updates
        function start(obj, updateFn)
            if ~exist('updateFn', 'var') || isempty(updateFn)
                error('Usage: obj.start(updateFn = @(newData))');
            end

            obj.updateFn = updateFn;
            obj.hPollTimer = timer('TimerFcn', @(varargin) obj.timerCallback(), ...
                'Period', obj.pollPeriod, 'ExecutionMode', 'fixedRate');
            start(obj.hPollTimer);
        end

        function stop(obj)
            if ~isempty(obj.hPollTimer) && isvalid(obj.hPollTimer)
                stop(obj.hPollTimer);
                delete(obj.hPollTimer);
            end

            obj.hPollTimer = [];
        end

    end

    methods(Access=protected)
        function timerCallback(obj)
            newData = obj.poll();
            if ~isempty(newData)
                try
                    obj.updateFn(newData);
                catch exc
                    obj.rewindToCachedIndexPosition(obj)
                    obj.stop();
                    rethrow(exc);
                end
            end
        end
    end




end

