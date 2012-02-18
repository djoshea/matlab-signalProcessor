
classdef SignalProcessor < handle

    properties
        signalDir 
        indexFile
        maxSignalFilesPerPoll = 50;
    end

    properties(Dependent)
        signalsPending
        groupsPending
    end
    
    properties(Constant)
        GROUPTYPE_CONTROL = 1;
        GROUPTYPE_
    end

    properties(Hidden=true)
        loader
        signalQueue 
        groupQueue
    end
    
    methods
        function val = get.signalsPending(obj)
            val = obj.signalQueue.count;
        end

        function val = get.groupsPending(obj)
            val = obj.groupQueue.count;
        end
    end

    methods
        function obj = SignalProcessor()
            signalDir = '/expdata/signals/20120206';
            indexFile = fullfile(signalDir, 'index.txt');
            obj.signalDir = signalDir;
            obj.indexFile = indexFile; 

            obj.loader = IndexedFileLoader(indexFile, signalDir, @load); 

            obj.signalQueue = Queue(false, 1000);
            obj.groupQueue = Queue(false, 1000);
        end

        function poll(obj) 
            obj.receiveNewSignals(obj.loader.poll(obj.maxSignalFilesPerPoll));
        end

        function hasSignals = receiveNewSignals(obj, newData)
            % check that all newData.data have a .signals variable within
            hasSignals = arrayfun(@(d) isfield(d.data, 'signals'), newData); 

            assert(all(hasSignals), 'Unexpectedly received data without .signals');

            % concatenate all of the signals from all of the files
            data = [newData.data];
            signalsCell = {data.signals}';
            signals = cell2mat(signalsCell);
            obj.signalQueue.add(signals); 

            obj.groupSignals();
        end

        function groupSignals(obj)
            [leftoverSignals = obj.groupSignalsUntilControlGroup(signals);

            % add to the queue
            obj.signalQueue.add(leftoverSignals);
        end

        function [leftoverSignals controlGroup] = groupSignalsUntilControlGroup(obj, signals)
            % first signal pending should be group version 'v'
            % which tells us how to parse the group of signals

            leftoverSignals = [];
            if isempty(signals)
               return;
            end
            
            sigOffset = 1;
            nSignals = length(signals);

            while sigOffset <= nSignals
                sigVersion = signals(sigOffset);
                sigOffset = sigOffset + 1;
                group.signals = [];

                assert(strcmp(sigVersion.name, 'v'), 'Error finding group version');
                groupVersion = sigVersion.data;

                if groupVersion == 2
                    nHeaderSignals = 3;

                    % enough signals for header?
                    if(nSignals - sigOffset + 1  < nHeaderSignals)
                        sigOffset = sigOffset - 1; % rewind back to the start
                        break;
                    end

                    sigType = signals(sigOffset);
                    sigName = signals(sigOffset+1);
                    sigN = signals(sigOffset+2);
                    sigOffset = sigOffset + nHeaderSignals; 

                    assert(strcmp(sigType.name, 'type'), 'Error finding group type');
                    assert(strcmp(sigName.name, 'name'), 'Error finding group name');
                    assert(strcmp(sigN.name, 'n'), 'Error finding group n');

                    nSignalsInGroup = double(sigN.data);
                    assert(numel(nSignalsInGroup) == 1, 'Too many values in group n');
                    assert(nSignalsInGroup > 0, 'No signals in group');

                    % enough signals for this group?
                    if(nSignals - sigOffset + 1 < nSignalsInGroup)
                        sigOffset = sigOffset - nHeaderSignals - 1; % rewind back to the start
                        break;
                    end

                    % check the signal timestamps are identical
                    groupSigIdx = sigOffset:sigOffset+nSignalsInGroup-1;
                    timestamp = unique([signals(groupSigIdx).timestamp]);
                    assert(numel(timestamp) == 1, ...
                        'Signals in group have differing timestamps');

                    % build the group struct
                    group.timestamp = timestamp; 
                    group.type = sigType.data;

                    % make name into char row vector
                    groupName = char(sigName.data);
                    if size(groupName,1) > size(groupName,2)
                        groupName = groupName';
                    end
                    group.name = groupName;

                    % put the named signals into the group.signals struct
                    signalNames = {signals(groupSigIdx).name};
                    safeSignalNames = genvarname(signalNames);
                    for i = 1:nSignalsInGroup
                        group.signals.(safeSignalNames{i}) = signals(groupSigIdx(i)).data;
                    end

                    sigOffset = sigOffset + nSignalsInGroup; 
                else
                    error('Unknown signal group version %d', groupVersion);
                end

                obj.groupQueue.add(group);
            end 
            
            leftoverSignals = signals(sigOffset:end);
        end

    end
end

