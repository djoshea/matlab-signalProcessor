
classdef SignalProcessor < handle

    properties
        indexFile = '';
        signalDir = '';
        maxSignalFilesPerPoll = 50;

        currentSubject = '';
        currentProtocol = '';
    end

    properties(Dependent)
        signalsPending
        groupsPending
    end
    
    properties(Constant,Hidden)
        GROUPTYPE_CONTROL = 1;
        GROUPTYPE_PARAM = 2;
        GROUPTYPE_ANALOG = 3;
        GROUPTYPE_EVENT = 4;
    end

    properties(Hidden=true)
        pathMgr
        loader
        trialSaver
        tds
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

        function set.currentProtocol(obj, val)
            obj.currentProtocol = val;
            obj.trialSaver.protocol = val;
        end

        function set.currentSubject(obj, val)
            obj.currentSubject = val;
            obj.trialSaver.subject = val;
        end

    end

    methods
        function obj = SignalProcessor()
            obj.pathMgr = FilePathManager();
            obj.tds = TrialDataSerializer();
            obj.trialSaver = TrialDataSaver();
            obj.reset();
        end

        function reset(obj)
            obj.signalDir = obj.pathMgr.getSignalsPath();
            obj.indexFile = obj.pathMgr.getSignalsIndexFile();
            obj.loader = IndexedFileLoader(obj.indexFile, obj.signalDir, @load); 

            obj.signalQueue = Queue(false, 1000);
            obj.groupQueue = Queue(false, 1000);
            obj.trialQueue = Queue(false, 10);

            % allow buffer expansion / auto field blanking in case groups drop in and out over the day
            obj.trialQueue.structAllowPartialFields = true;
            obj.trialQueue.structAllowAdditionalFields = true;
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
            % remove signals currently on the queue to prepend
            oldSignals = obj.signalQueue.removeAll();
            signals = [oldSignals signals];

            leftoverSignals = obj.processSignals(signals);

            % add leftover signals to the queue for next time
            obj.signalQueue.add(leftoverSignals);
        end

        function leftoverSignals = processSignals(obj, signals)
           
            while true
                [leftoverSignals controlGroup] = obj.groupSignalsUntilControlGroup(signals);

                if isempty(controlGroup)
                    % no control group encountered, just ran out of signals
                    % so, just wait for next time
                    break;
                end

                % get command from control group
                controlCommand = controlGroup.signals.command;

                if(strcmpi(controlCommand, 'SetInfo'))
                    % set the info regarding what kind of data is coming in
                    obj.currentProtocol = controlGroup.signals.protocol;
                    obj.currentSubject = controlGroup.signals.subject;
                    signals = leftoverSignals;
                    
                elseif(strcmp(controlCommand, 'NextTrial'))
                    % command to start new trial

                    % serialize a trial out of the groups in the queue
                    r = obj.buildTrialFromGroupQueue(controlGroup); 
                    if ~isempty(r)
                        obj.trialQueue.add(r);
                    end
                    signals = leftoverSignals;
                else
                    error('Unknown control command %s', controlCommand);
                end
            end
            
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

        function r = buildTrialFromGroupQueue(obj, controlGroup)
            r = [];
            groups = obj.groupQueue.removeAll();

            if isempty(groups)
                return;
            end

            timestamps = sort(unique([groups.timestamp]));
            tds = obj.tds;
            tds.flush();
            tds.protocol = obj.currentProtocol; 
            tds.tsStart = timestamps(1);
            tds.tsEnd = timestamps(end);

            obj.processAnalogGroups(tds, groups);
            obj.processEventGroups(tds, groups);
            obj.processParamGroups(tds, groups);

            r = tds.serialize();

            obj.trialSaver.saveTrial(r);
        end

        function groups = filterGroupsByType(obj, groups, groupType)
            idx = find([groups.type] == groupType);
            groups = groups(idx); 
        end

        function groups = filterGroupsByName(obj, groups, groupName)
            idx = find(strcmp({groups.name}, groupName));
            groups = groups(idx); 
        end

        function processParamGroups(obj, tds, groups)
            groups = obj.filterGroupsByType(groups, SignalProcessor.GROUPTYPE_PARAM);

            for iPG = 1:length(groups)
                group = groups(iPG);
                names = fieldnames(group.signals);
                for iP = 1:length(names)
                    [name units] = obj.parseNameUnits(names{iP});
                    value = group.signals.(names{iP}); % convert to double since most params are scalar
                    tds.addParam(group.name, name, value, units);
                end
            end 
        end

        function processEventGroups(obj, tds, groups)
            groups = obj.filterGroupsByType(groups, SignalProcessor.GROUPTYPE_EVENT);

            for iG = 1:length(groups)
                group = groups(iG);
                name = group.signals.name;
                if isfield(group.signals, 'tag')
                    tag = group.signals.tag;
                else
                    tag = [];
                end
                tds.addEvent(group.name, name, group.timestamp, tag);
            end 
        end

        function r = processAnalogGroups(obj, tds, groups)
            groups = obj.filterGroupsByType(groups, SignalProcessor.GROUPTYPE_ANALOG);

            for iG = 1:length(groups)
                g = groups(iG);
                names = fieldnames(g.signals);
                for iA = 1:length(names)
                    [name units] = obj.parseNameUnits(names{iA});
                    tds.addAnalog(g.name, name, g.timestamp, g.signals.(names{iA}), units, []);
                end
            end

%           groupNames = sort(unique({groups.name}));
%           nGroups = length(groupNames);

%           for iGN = 1:nGroupNames
%               groupsThisName = obj.filterGroupsByName(groups, groupNames{iGN});
%               signalNames = fieldnames(groupsThisName(1).signals);
%               for iA = 1:length(signals)
%                    
%                   tds.addAnalog
%               for iP = 1:length(paramNames)
%                   % convert to double since most params are scalar
%                   r.(group.name).(paramNames{iP}) = double(group.signals.(paramNames{iP}));
%               end
%           end 
        end

        function [name units] = parseNameUnits(obj, nameWithUnits)
            % genvarname is used to escape variable names, and replaces ( ) with these codes
            nameWithUnits = strrep(nameWithUnits, '0x28', '(');
            nameWithUnits = strrep(nameWithUnits, '0x29', ')');

            % takes 'name(units)' and splits into name and units
            [name parenUnits] = strtok(nameWithUnits, '(');
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

