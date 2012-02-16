classdef Queue < handle

    properties(Access=protected)
        % ring buffer (either array or cell array) for storing incoming data
        ringBuffer 
    end

    properties(Dependent, SetAccess=protected)
        dataClass
        count
        currentCapacity
    end

    methods
        function str = get.dataClass(obj)
            str = obj.ringBuffer.dataClass;
        end

        function val = get.count(obj)
            val = obj.ringBuffer.count;
        end
        
        function val = get.currentCapacity(obj)
            val = obj.ringBuffer.capacity;
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
            [compatible msg] = obj.ringBuffer.isCompatibleWithData(data);
            if ~compatible
                error(msg);
            end
            
            % expand to hold new data if necessary
            if ~obj.ringBuffer.hasCapacityFor(data);
                obj.ringBuffer = obj.ringBuffer.getExpandedCopyToHoldData(data);
            end

            obj.ringBuffer.addAtHead(data);
        end

        function data = peek(obj, nElements)
            if ~exist('nElements', 'var')
                data = obj.ringBuffer.peekFromTail();
            else
                data = obj.ringBuffer.peekFromTail(nElements);
            end
        end

        function data = remove(obj, nElements)
            if ~exist('nElements', 'var')
                data = obj.ringBuffer.removeFromTail();
            else
                data = obj.ringBuffer.removeFromTail(nElements);
            end
        end
    end

end
