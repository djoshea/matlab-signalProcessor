classdef Queue < handle
% A queue data structure built atop class RingBuffer

    properties(Access=protected)
        % ring buffer (either array or cell array) for storing incoming data
        ringBuffer 
    end

    properties(Dependent, SetAccess=protected)
        dataClass
        count
        currentCapacity
    end

    properties(Dependent, SetAccess=public)
        structAllowPartialFields; % accept new structs with only a subset of fields specified
        structAllowAdditionalFields; % accept structs with fields that are not currently in the buffer
    end

    methods
        function val = length(obj)
            val = obj.count;
        end

        function tf = isempty(obj)
            tf = obj.count == 0;
        end

        function str = get.dataClass(obj)
            str = obj.ringBuffer.dataClass;
        end

        function val = get.count(obj)
            val = obj.ringBuffer.count;
        end
        
        function val = get.currentCapacity(obj)
            val = obj.ringBuffer.capacity;
        end

        % these functions provide access to the field with the same name
        % inside the RingBuffer
        function val = get.structAllowPartialFields(obj)
            val = obj.ringBuffer.structAllowPartialFields;
        end

        function set.structAllowPartialFields(obj, val)
            obj.ringBuffer.structAllowPartialFields = val;
        end
        
        function val = get.structAllowAdditionalFields(obj)
            val = obj.ringBuffer.structAllowAdditionalFields;
        end

        function set.structAllowAdditionalFields(obj, val)
            obj.ringBuffer.structAllowAdditionalFields = val;
        end
    end

    methods
        function obj = Queue(useCellArray, initialCapacity)
            if ~exist('initialCapacity', 'var')
                initialCapacity = 100;
            end

            obj.ringBuffer = RingBuffer(useCellArray, initialCapacity);
        end

        function add(obj, data)
            %[compatible msg] = obj.ringBuffer.isCompatibleWithData(data);
            %if ~compatible
            %    error(msg);
            %end
            
            % expand to hold new data if necessary
            if ~obj.ringBuffer.hasCapacityFor(data);
                obj.ringBuffer = obj.ringBuffer.getExpandedCopyToHoldData(data);
            end

            obj.ringBuffer.addAtHead(data);
        end

        function data = peek(obj, nElements)
            % data = peek(nElements) - fetch nElements without removing them from the queue
            if ~exist('nElements', 'var')
                data = obj.ringBuffer.peekFromTail();
            else
                data = obj.ringBuffer.peekFromTail(nElements);
            end
        end

        function data = peekAhead(obj, nElementsSkip, nElements)
            % same as peek, except begins peeking nElementsSkip ahead of the tail
            data = obj.ringBuffer.peekFromTail(nElementsSkip+nElements);
            data = data(nElementsSkip+1:end);
        end

        function data = remove(obj, nElements)
            % data = remove(nElements) - remove elements and return them
            if ~exist('nElements', 'var')
                data = obj.ringBuffer.removeFromTail();
            else
                data = obj.ringBuffer.removeFromTail(nElements);
            end
        end

        function wipe(obj, nElements)
            % wipe(nElements) - remove elements without fetching them (faster than remove)
            if ~exist('nElements', 'var')
                nElements = 1;
            end
            obj.ringBuffer.wipeFromTail(nElements);
        end

        function data = removeAll(obj)
            data = obj.remove(obj.count);
        end

        function data = wipeAll(obj)
            obj.wipe(obj.count);
        end
    end

end
