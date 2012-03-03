classdef TrialDataSerializer < handle
% This class takes trial signal data and constructs a 
    properties
        protocol = ''; % written into .meta.protocol parameter
        tsStart = [];
        tsEnd = [];
        tUnits = 'ms';

        % NOTE: each groupName can only exist in one of analogData, eventData, or paramData
        % In other words each group must hold one type of data
        analogData
%           struct('groupName', '', ...
%                  'name', '', ...
%                  'times', [], ...
%                  'values', [], ...
%                  'units', '', ...
%                  'scaleFn', [] ...
%                  );
        eventData
%           struct('groupName', '', ...
%                  'name', '', ...
%                  'times', [], ...
%                  'tags', {} ... % cell array, one per event occurrence 
%                 );
        paramData
%           struct('groupName', '', ...
%                  'name', '', ...
%                  'value', [], ...
%                  'units', []  ...
%                  );
    end

    properties(Constant)
        FORMAT = 'tds'; % identifies this r struct as TrialDataSerializer serialized
        VERSION = 20120218; % written into .meta.version parameter

        reservedGroupNames = {'meta', 'time'};
        reservedNames = {'type'};
    end

    properties(Dependent, SetAccess=private)
        groupNames % list of all group names present
        groupNamesAnalog
        groupNamesEvent
        groupNamesParam
        duration
        timeVector 
    end

    methods % Dependent get methods

        function names = get.groupNames(obj)
            names = unique([obj.groupNamesAnalog obj.groupNamesEvent obj.groupNamesParam]);
        end

        function vec = get.timeVector(obj)
            vec = 0:(obj.duration-1);
        end

        function analogNames = get.groupNamesAnalog(obj)
            if ~isempty(obj.analogData)
                analogNames = unique({obj.analogData.groupName});
            else
                analogNames = {};
            end
        end

        function eventNames = get.groupNamesEvent(obj)
            if ~isempty(obj.eventData)
                eventNames = unique({obj.eventData.groupName});
            else
                eventNames = {};
            end
        end

        function paramNames = get.groupNamesParam(obj)
            if ~isempty(obj.paramData)
                paramNames = unique({obj.paramData.groupName});
            else
                paramNames = {};
            end
        end

        function val = get.duration(obj)
            val = obj.tsEnd-obj.tsStart+1; 
        end

    end

    methods % constructor, flush(), and disp()
        
        function obj = TrialDataSerializer()
            obj.flush();
        end

        function flush(obj)
            % reset this object's state so that it can be used for the next trial
            obj.tsStart = [];
            obj.tsEnd = [];

            obj.analogData = struct([]);
            obj.eventData = struct([]);
            obj.paramData = struct([]);
        end

        function disp(obj)
            fprintf('TrialDataSerializer handle\n\n');

            if isempty(obj.protocol)
                fprintf('Protocol: <unknown>\n');
            else
                fprintf('Protocol: %s\n', obj.protocol);
            end

            if(isempty(obj.tsStart) || isempty(obj.tsEnd))
                fprintf('Time: <unknown>\n');
            else
                fprintf('Time: %d : %d [ %d %s ]\n', ...
                    obj.tsStart, obj.tsEnd, obj.duration, obj.tUnits); 
            end

            fprintf('\n');
            groupNames = obj.groupNames;

            if isempty(groupNames)
                fprintf('No data groups\n');
            else
                nGroups = length(groupNames);
                for iG = 1:nGroups
                    groupType = obj.getGroupType(groupNames{iG});
                    
                    if strcmp(groupType, 'analog')
                        idx = obj.findAnalogByGroupName(groupNames{iG});
                        if isempty(idx)
                            names = {};
                        else
                            names = sort({obj.analogData(idx).name});
                        end

                    elseif strcmp(groupType, 'event')
                        idx = obj.findEventByGroupName(groupNames{iG});
                        if isempty(idx)
                            names = {};
                        else
                            names = sort({obj.eventData(idx).name});
                        end
                        
                    elseif strcmp(groupType, 'param')
                        idx = obj.findParamByGroupName(groupNames{iG});
                        if isempty(idx)
                            names = {};
                        else
                            names = sort({obj.paramData(idx).name});
                        end
                    end
                   
                    fprintf('%s [ %s ]\n', groupNames{iG}, groupType);
                    for iN = 1:length(names)
                        fprintf('  %s\n', names{iN});
                    end
                end
            end
            
            fprintf('\n');
        end

    end

    methods % find by name and group type methods

        function type = getGroupType(obj, groupName)
            if ismember(groupName, obj.groupNamesAnalog)
                type = 'analog';
            elseif ismember(groupName, obj.groupNamesEvent)
                type = 'event';
            elseif ismember(groupName, obj.groupNamesParam)
                type = 'param';
            else
                type = '';
            end
        end

        function assertGroupTypeMatches(obj, groupName, groupType)
            actualGroupType = obj.getGroupType(groupName);
            assert(isempty(actualGroupType) || strcmp(groupType, actualGroupType), ...
                'Group %s has already been assigned to be a %s group', groupName, actualGroupType);
        end

        function idx = findParamByGroupName(obj, groupName)
            if isempty(obj.paramData)
                idx = [];
            else
                idx = find(strcmp({obj.paramData.groupName}, groupName));
            end
        end

        function idx = findEventByGroupName(obj, groupName)
            if isempty(obj.eventData)
                idx = [];
            else
                idx = find(strcmp({obj.eventData.groupName}, groupName));
            end
        end
        
        function idx = findAnalogByGroupName(obj, groupName)
            if isempty(obj.analogData)
                idx = [];
            else
                idx = find(strcmp({obj.analogData.groupName}, groupName));
            end
        end

        function idx = findParamByName(obj, groupName, name)
            if isempty(obj.paramData)
                idx = [];
            else
                idx = find(strcmp({obj.paramData.groupName}, groupName) & ...
                    strcmp({obj.paramData.name}, name));
            end
        end

        function idx = findEventByName(obj, groupName, name)
            if isempty(obj.eventData)
                idx = [];
            else
                idx = find(strcmp({obj.eventData.groupName}, groupName) & ...
                    strcmp({obj.eventData.name}, name));
            end
        end
        
        function idx = findAnalogByName(obj, groupName, name)
            if isempty(obj.analogData)
                idx = [];
            else
                idx = find(strcmp({obj.analogData.groupName}, groupName) & ...
                    strcmp({obj.analogData.name}, name));
            end
        end

    end

    methods % add data methods

        % These add methods add data to this object which will later be included
        % when serialize() is called
        function addParam(obj, groupName, name, value, units)
            obj.assertGroupTypeMatches(groupName, 'param');

            idx = obj.findParamByName(groupName, name);
            if ~isempty(idx)
                warning('Overwriting parameter %s.%s\n', groupName, name);
            else
                idx = length(obj.paramData)+1;
            end

            obj.paramData(idx).groupName = obj.safeGroupName(groupName);
            obj.paramData(idx).name = obj.safeName(name);
            obj.paramData(idx).value = value;
            obj.paramData(idx).units = units;
        end

        function addEvent(obj, groupName, name, timestamp, tag) 
            obj.assertGroupTypeMatches(groupName, 'event');

            if isempty(obj.tsStart)
                error('Set .tsStart before adding events');
            end
            idx = obj.findEventByName(groupName, name);
            timeRelative = timestamp - obj.tsStart;

            if ~isempty(idx)
                % this event has already been added, simply append the timestamp
                % but maintain the timestamps in sorted order
                [times sortIdx] = sort([obj.eventData(idx).times timeRelative]);

                % apply the same sorting order to the metadata cell
                tags = [obj.eventData(idx).tags {tag}];
                tags = tags(sortIdx);
            else
                % append a new event
                idx = length(obj.eventData)+1;
                times = timeRelative;
                
                % eventData(idx).tags should always be a cell array 
                % to maintain consistency when the event can have 1 or more occurrences
                tags = {tag};
            end

            obj.eventData(idx).groupName = obj.safeGroupName(groupName);
            obj.eventData(idx).name = obj.safeName(name);
            obj.eventData(idx).times = times;
            obj.eventData(idx).tags = tags; 
        end

        function addAnalog(obj, groupName, name, timestamps, values, units, scaleFn)
            obj.assertGroupTypeMatches(groupName, 'analog');

            if isempty(obj.tsStart)
                error('Set .tsStart before adding analog data');
            end
            idx = obj.findAnalogByName(groupName, name);
            times = timestamps - obj.tsStart;

            if ~isempty(idx)
                % sort these new timestamps into the old, sort values accordingly
                [times sortIdx] = sort([obj.analogData(idx).times times]);
                values = [obj.analogData(idx).values values];
                values = values(sortIdx);
            else
                idx = length(obj.analogData)+1;
               
                % sort the timestamps and values
                [times sortIdx] = sort(times);
                values = values(sortIdx);
            end

            obj.analogData(idx).groupName = obj.safeGroupName(groupName);
            obj.analogData(idx).name = obj.safeName(name);
            obj.analogData(idx).times = times; 
            obj.analogData(idx).values = values;
            obj.analogData(idx).units = units;
            obj.analogData(idx).scaleFn = scaleFn;
        end

        function name = safeGroupName(obj, name)
            name = genvarname(name, obj.reservedGroupNames);
        end

        function name = safeName(obj, name)
            name = genvarname(name, obj.reservedNames);   
        end

    end

    methods % serialization methods

        function r = serialize(obj)
            if isempty(obj.protocol) || isempty(obj.tsStart) || isempty(obj.tsEnd)
                error('Set values of .protocol, .tsStart, and .tsEnd before serializing');
            end

            r = [];
         
            % store meta serialization info
            r.meta.format = obj.FORMAT;
            r.meta.version = obj.VERSION;
            r.meta.protocol = obj.protocol;
            
            % store group names for each type, which makes this r struct self-describing
            r.meta.analog = obj.groupNamesAnalog;
            r.meta.event = obj.groupNamesEvent;
            r.meta.param = obj.groupNamesParam;

            % initialize extra info maps to hold descriptor data
            % the key will always be 'groupName.name'
            r.meta.unitsLookup = containers.Map('KeyType', 'char', 'ValueType', 'char');
            r.meta.scaleFnLookup = containers.Map('KeyType', 'char', 'ValueType', 'any');
            r.meta.timeVectorLookup = containers.Map('KeyType', 'char', 'ValueType', 'any');

            % store time info
            r.time.tsStart = obj.tsStart;
            r.time.tsEnd = obj.tsEnd;
            r.time.duration = obj.duration;
            r.time.vector = obj.timeVector; 
            r.time.tUnits = obj.tUnits;

            r = obj.serializeAnalogData(r);
            r = obj.serializeEventData(r);
            r = obj.serializeParamData(r);

            r = orderfields(r);
        end

        function key = buildLookupKey(obj, groupName, name)
            key = sprintf('%s.%s', groupName, name);
        end

        function r = serializeAnalogData(obj, r)
            defaultTrialTime = obj.timeVector; 

            for i = 1:length(obj.analogData)
                d = obj.analogData(i); 
                key = obj.buildLookupKey(d.groupName, d.name);
                r.(d.groupName).(d.name) = d.values; 

                % include timeVector only if doesn't match the default
                if ~isequal(defaultTrialTime, d.times)
                    r.meta.timeVectorLookup(key) = d.times;
                end

                if ~isempty(d.scaleFn)
                    r.meta.scaleFnLookup(key) = d.scaleFn;
                end

                if ~isempty(d.units)
                    r.meta.unitsLookup(key) = d.units;
                end
            end
        end

        function r = serializeEventData(obj, r)
            for i = 1:length(obj.eventData)
                d = obj.eventData(i); 
                key = obj.buildLookupKey(d.groupName, d.name);
                r.(d.groupName).(d.name) = d.times;

                if ~all(cellfun(@isempty, d.tags))
                    r.meta.tagsLookup(key) = d.tags;
                end
            end
        end

        function r = serializeParamData(obj, r)
            for i = 1:length(obj.paramData)
                d = obj.paramData(i); 
                key = obj.buildLookupKey(d.groupName, d.name);
                r.(d.groupName).(d.name) = d.value;

                if ~isempty(d.units) 
                    r.meta.unitsLookup(key) = d.units;
                end
            end
        end
    end

end
