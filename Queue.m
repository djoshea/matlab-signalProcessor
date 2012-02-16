classdef Queue < handle

    properties(Access=hidden)
        % ring buffer (either array or cell array) for storing incoming data
        ringBuffer 
        ringBufSize 
        head 
        tail
    end

    properties(GetAccess=public, SetAccess=protected)
        useCellArray
    end

    properties(Dependent)
        length
        free
    end

    methods
        function obj = Queue(useCellArray, initialSize)
            obj.useCellArray = useCellArray
            obj.ringBufSize = initialSize;

            % we want to store the first piece of data at the end of the array
            % so that ringBuf only gets sized on the first call to add()
            obj.head = initialSize-1;
            obj.tail = initialSize-1;

            if useCellArray
                obj.ringBuf = cell(initialSize, 1);
            else
                % can't really initialize until we know whether it's a struct array or not
                obj.ringBuf = [];
            end
        end

        function add(obj, data)
            if isempty(data)
                return;
            end

            % check the data is compatible with this queue
            if useCellArray
                if ~iscell(data)
                    data = {data};
                end
            elseif ~isvector(data) || (~isstruct(data) && ~isnumeric(data))
                error('This queue only accepts struct / struct array or scalar / numeric array data');
            elseif ~isempty(ringBuf) & isstruct(data) & ~isstruct(ringBuf)
                error('This queue is currently storing structs and only accepts new struct data');
            elseif ~isempty(ringBuf) & isnumeric(data) & ~isnumeric(ringBuf)
                error('This queue is currently storing scalars and only accepts new numeric data');
            end

            nNewData = length(data);
          
            % expand to hold new data if necessary
            if nNewData > obj.free
                obj.expand(obj.length + nNewData);
            end

            % special case for initializing the ring buffer when it's empty 
            if isempty(obj.ringBuf)
                
            end

            % store in the ring buffer
            idxStore = obj.getIdxFromHead(1:nNewData);
            ringBuf(idxStore) = data; 

            % move the head forward
            obj.head = idxStore(end);
        end

        function val =  get.length(obj)
            val = obj.getCircularRangeLength(obj.head, obj.tail); 
        end

        function val =  get.free(obj)
            val = obj.ringBufSize - obj.length;
        end
    end

    methods(Access=protected)
        function expand(obj, minSize)
            if ringBufSize >= minSize
                % already big enough
                return;
            end

            % double the current size as many times as necessary to accomodate minSize 
            newSize = ringBufSize * 2^(ceil(log(minSize/ringBufSize) / log(2)));
        
            if useCellArray
                newRingBuf = cell(newSize, 1);
            else
                newRingBuf = intializedRingBuffer 

        end

        function initializeRingBuffer(obj, firstData)
            % assign firstData to last element of the ringBuf
            % this will initialize ringBuf to be the correct size
            assert(

            if isstruct(firstData)
                flds = fieldnames(data);
                for iFld = 1:length(flds)
                    obj.ringBuf(obj.ringBufSize).(flds{iFld}) = data(1).(flds{iFld});
                end
            else
                obj.ringBuf(obj.ringBufSize) = data(1);
            end
        end

        function idxFromHead = getIdxFromHead(obj, idx)
            assert(~any(idx > obj.ringBufSize || idx < 1), 'Index out of range');

            % convert idx relative to head==0 to idx into ringBuf, keeping the looping around
            idxFromHead = mod((idx+headIdx-1)-1, ringBufSize) + 1;
        end

        function n = getCircularRangeLength(idxStart, idxEnd)
            assert(~any([idxStart idxEnd] < 0 || [idxStart idxEnd] > ringBufSize), 'Index out of range');

            if idxStart <= idxEnd
                return idxEnd-idxStart+1;
            else
                return idxEnd+ringBufSize-idxStart+1;
            end
        end
    end

end
