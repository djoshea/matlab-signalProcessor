classdef TrialDataSerializer < handle
% This class takes trial signal data and constructs a 
    properties
        tsStart
        tsEnd
        tUnit = 'ms';

        % see flush() for the fields within these struct arrays
        analogData
        eventData
        paramData
    end

    properties(Constant)
        VERSION = 20120218; 
        TYPE_PARAM = 2;
        TYPE_ANALOG = 3;
        TYPE_EVENT = 4;
    end

    properties(Dependent, SetAccess=private)
        duration
        trialTime
    end

    methods
        function val = length(obj)
            val = obj.duration;
        end

        function val = get.duration(obj)
            val = tsEnd-tsStart+1; 
        end

        function tvec = get.trialTime(obj)
            tvec = 1:trialTime;
        end

    end

    methods
        
        function obj = TrialDataSerializer()
            obj.flush();
        end

        function flush(obj)
            % reset this object's state so that it can be used for the next trial
            obj.tsStart = [];
            obj.tsEnd = [];

            obj.analogData = struct('type', '', ...
                                    'groupname', '', ...
                                    'name', '', ...
                                    'timeRelative', [], ...
                                    'values', [], ...
                                    'metadata', [], ...
                                    'unit', [], ...
                                    'scalefn', [], ...
                                   );

            obj.eventData = struct('type', '', ...
                                   'groupname', '', ...
                                   'name', '', ...
                                   'timeRelative', [], ...
                                   'metadata', [], ...
                                  );

            obj.paramData = struct('type', '', ...
                                   'groupname', '', ...
                                   'name', '', ...
                                   'value', [], ...
                                   'unit', [], ...
                                   'metadata', [], ...
                                   );
        end

        function idx = findParamByName(obj, groupName, name)
            idx = find(strcmp({obj.paramData.groupName}, groupName) & ...
                strcmp({obj.paramData.name}, name));
        end

        function idx = findEventByName(obj, groupName, name)
            idx = find(strcmp({obj.eventData.groupName}, groupName) & ...
                strcmp({obj.eventData.name}, name));
        end
        
        function idx = findAnalogByName(obj, groupName, name)
            idx = find(strcmp({obj.analogData.groupName}, groupName) & ...
                strcmp({obj.analogData.name}, name));
        end

        function addParam(obj, groupName, name, value, units)
            if obj.findParamByName(groupName, name)
                warning('Duplicate setting for parameter %s.%s\n', groupName, name);
            end

            idx = length(obj.analogData)+1;
            obj.data(idx).type = type;
            obj.data(idx).groupName = groupName;
            obj.data(idx).name = name;
            obj.data(idx).value = value;
            obj.data(idx).metadata = metadata;
            obj.data(idx).units = units;
        end


        function addEvent(obj, groupName, name, timestamp, metadata)
            idx = obj.findEventByName(groupName, name);
            timeRelative = timestamp - obj.tsStart;

            if ~isempty(idx)
                % this event has already been added, simply append the timestamp
                % but maintain the timestamps in sorted order
                ev = obj.eventData(idx);
                [ev.timeRelative sortIdx] = sort([ev.timeRelative timeRelative]);

                % apply the same sorting order to the metadata cell
                metadata = [ev.metadata metadata];
                ev.metadata = metadata(sortIdx);
            else
                % append a new event
                idx = length(obj.eventData)+1;
                obj.data(idx).type = obj.TYPE_EVENT;
                obj.data(idx).groupName = groupName;
                obj.data(idx).name = name;
                obj.data(idx).timeRelative = timeRelative;

                % wrap metadata in a cell to maintain consistency when there are
                % multiple occurrences for this event
                obj.data(idx).metadata = {metadata};
            end

        end

        function addAnalog(obj, groupName, name, timestamps, values, metadata, unit, scaleFn)
            idx = obj.findAnalogByName(groupName, name);

            if ~isempty(idx)

            % sort the timestamps and values
            [timestamps sortIdx] = sort(timestamps);
            values = values(sortIdx);

            idx = length(obj.analogData)+1;
            obj.data(idx).type = type;
            obj.data(idx).groupName = groupName;
            obj.data(idx).name = name;
            obj.data(idx).timeRelative = timestamps - obj.tsStart;
            obj.data(idx).values = values;
            obj.data(idx).metadata = metadata;
            obj.data(idx).units = units;
            obj.data(idx).scaleFn = scaleFn;
        end

        function s = serialize(obj)
            trialTime = obj.trialTime;
            
            s = [];
            s.meta.version = obj.VERSION;
            s.meta.tsStart = obj.tsStart;
            s.meta.tsEnd = obj.tsEnd;
            s.meta.duration = obj.duration;
            s.meta.tUnit = obj.tUnit;

            % unpack obj.data into separate fields for space efficiency
            dataFields = fieldnames(obj.data)
            for ifld = 1:length(data)
                s.(dataFields{ifld}) = {obj.data.(dataFields{ifld})};
            end
        end

    end

end
