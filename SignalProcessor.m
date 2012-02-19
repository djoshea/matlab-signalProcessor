
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
        GROUPTYPE_PARAM = 2;
        GROUPTYPE_ANALOG = 3;
        GROUPTYPE_EVENT = 4;
    end

    properties(Hidden=true)
        loader
        signalQueue 
        groupQueue
        trialQueue
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
            obj.trialQueue = Queue(false, 10);
        end

        function poll(obj) 
            obj.receiveNewSignals(obj.loader.poll(obj.maxSignalFilesPerPoll));
        end

        function receiveNewData(obj, newData)
            % check that all newData.data have a .signals variable within
            hasSignals = arrayfun(@(d) isfield(d.data, 'signals'), newData); 

            assert(all(hasSignals), 'Unexpectedly received data without .signals');
            
            % concatenate all of the signals from all of the files
            data = [newData.data];
            signalsCell = {data.signals}';
            signals = cell2mat(signalsCell);
            
            obj.receiveNewSignals(obj, signals);
        end
        
        function receiveNewSignals(obj, signals)
            oldSignals = obj.signalQueue.removeAll();
            signals = [oldSignals signals];

            obj.groupSignals(signals);
        end

        function groupSignals(obj, signals)
           
            while true
                [leftoverSignals controlGroup] = obj.groupSignalsUntilControlGroup(signals);

                if isempty(controlGroup)
                    % no control group encountered, just ran out of signals
                    break;
                end

                % get command from control group
                controlCommand = controlGroup.signals.command;

                if(strcmp(controlCommand, 'nextTrial'))
                    % command to start new trial
                    r = obj.buildTrialFromGroupQueue(controlGroup); 
                    if ~isempty(r)
                        obj.trialQueue.add(r);
                    end
                    signals = leftoverSignals;
                else
                    error('Unknown control command %s', controlCommand);
                end
            end
            
            % add leftover signals to the queue for next time
            obj.signalQueue.add(leftoverSignals);
        end

        function [leftoverSignals controlGroup] = groupSignalsUntilControlGroup(obj, signals)
            % first signal pending should be group version 'v'
            % which tells us how to parse the group of signals

            leftoverSignals = [];
            controlGroup = [];
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

                if group.type == obj.GROUPTYPE_CONTROL
                    % it's a control packet, we're done!
                    controlGroup = group;
                    break;
                else
                    obj.groupQueue.add(group);
                end
            end 
            
            % return the remaining signals
            leftoverSignals = signals(sigOffset:end);
        end

        function s = buildTrialFromGroupQueue(obj, controlGroup)
            s = [];
            groups = obj.groupQueue.removeAll();

            if isempty(groups)
                return;
            end

            timestamps = sort(unique([groups.timestamp]));
            tsStart = timestamps(1);
            tsStop = timestamps(end);
            trialLength = tsStop - tsStart + 1;

            fprintf('Storing trial with length %d...\n', trialLength); 
            tds = TrialDataSerializer(tsStart, tsStop);

            obj.processParamGroups(tds, groups);
            obj.processAnalogGroups(tds, groups);
            obj.processEventGroups(tds, groups);

            s = tds.serialize();
        end

        function processParamGroups(obj, tds, groups)
            paramGroupIdx = find([groups.type]==SignalProcessor.GROUPTYPE_PARAM);
            
            for iPG = 1:length(paramGroupIdx)
                group = groups(paramGroupIdx(iPG));
                paramNames = fieldnames(group.signals);
                for iP = 1:length(paramNames)
                    [name units] = obj.parseNameUnits(paramNames{iP});
                    value = double(group.signals.(paramNames{iP}); % convert to double since most params are scalar
                    tds.addParam(group.name, name, value, units);
                end
            end 
        end

        function r = processAnalogGroups(obj, r, groups)
            analogGroupIdx = find([groups.type]==SignalProcessor.GROUPTYPE_ANALOG);

            groupNames = sort(unique({groups.name}));
            nGroups = length(groupNames);
            namesForGroup = @(groupName) groups(strcmp{group.name

            for ts = r.time.start:r.time.stop

            for iAG = 1:length(analogGroupIdx)
                group = groups(analogGroupIdx(iAG));
                analogNames = fieldnames(group.signals);
                for iP = 1:length(paramNames)
                    % convert to double since most params are scalar
                    r.(group.name).(paramNames{iP}) = double(group.signals.(paramNames{iP}));
                end
            end 
        end

        function [name units] = parseNameUnits(nameWithUnits)
            % takes 'name(units)' and splits into name and units
            [name parenUnits] = strtok(nameWithUnits, '('));
            if ~isempty(parenUnits)
                if length(parenUnits >= 2) && parenUnits(1) == '(' && parenUnits(end) == ')'
                    units = parenUnits(2:end-1);
                else
                    % something's amiss, return the whole thing untouched
                    units = '';
                    name = nameWithUnits;
                end
            else
                units = '';
            end
        end

    end
end

