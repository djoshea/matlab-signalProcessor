classdef TrialDataSerializer < handle
% This class takes trial signal data and constructs a 
    properties
        tsStart
        tsEnd
        tUnit = 'ms';

        % this format must hold event, param, and analog data
        data
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

        function val = get.duration()
            val = tsEnd-tsStart+1; 
        end

        function tvec = get.trialTime()
            tvec = 1:trialTime;
        end
    end

    methods
        
        function obj = TrialData(tsStart, tsEnd)
            obj.tsStart = tsStart;
            obj.tsEnd = tsEnd;
            obj.flush();
        end

        function flush(obj)
            obj.data = struct(  'type', '', ...
                                'groupName', '', ...
                                'name', '', ...
                                'timeRelative', [], ...
                                'values', [], ...
                                'metadata', [], ...
                                'unit', [], ...
                                'scaleFn', [], ...
                            );
        end

        function addData(obj, type, groupName, name, timestamps, values, metadata, unit, scaleFn)
            idx = length(obj.data)+1;
            obj.data(idx).type = type;
            obj.data(idx).groupName = groupName;
            obj.data(idx).name = name;
            obj.data(idx).timeRelative = timestamps - obj.tsStart;
            obj.data(idx).values = values;
            obj.data(idx).metadata = metadata;
            obj.data(idx).units = units;
            obj.data(idx).scaleFn = scaleFn;
        end

        function addParam(obj, groupName, name, value, unit)
            obj.addData(obj.TYPE_PARAM, groupName, name, [], value, [], unit, []);
        end

        function addEvent(obj, groupName, name, timestamps, metadata)
            % sort the timestamps and metadata 
            [timestamps sortIdx] = sort(timestamps);
            metadata = metadata(sortIdx);

            obj.addData(obj.TYPE_EVENT, groupName, name, timestamps, [], metadata, [], []);
        end

        function addAnalog(obj, groupName, name, timestamps, values, metadata, unit, scaleFn)
            % sort the timestamps and values
            [timestamps sortIdx] = sort(timestamps);
            values = values(sortIdx);

            obj.addData(obj.TYPE_ANALOG, groupName, name, timestamps, values, metadata, unit, scaleFn); 
        end

        function s = serialize(obj)
            trialTime = obj.trialTime;
            
            s = [];
            s.version = obj.VERSION;
            s.tsStart = obj.tsStart;
            s.tsEnd = obj.tsEnd;
            s.duration = obj.duration;
            s.tUnit = obj.tUnit;

            % unpack obj.data into separate fields for space efficiency
            dataFields = fieldnames(obj.data)
            for ifld = 1:length(data)
                s.(dataFields{ifld}) = {obj.data.(dataFields{ifld})};
            end
        end

    end

end
