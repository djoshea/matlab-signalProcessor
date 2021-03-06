classdef RingBuffer < handle
% Ring buffer data structure with the ability add and remove at both head and tail 

    properties (GetAccess=public, SetAccess=protected)
        buffer % pre-allocated data storage, will be one longer than capacity to prevent head==tail ambiguity
        capacity % maximum capacity for this buffer 
        useCellArray % whether or not a cell array is used for the buffer
        head % head points to the idx for the next data element yet to be added
        tail % tail points to the idx for the oldest data element already added

    end

    properties (Access=public)
        structAllowPartialFields  = false; % accept new structs with only a subset of fields specified
        structAllowAdditionalFields = false; % accept structs with fields that are not currently in the buffer
    end


    properties (Dependent, SetAccess=protected)
        dataClass
        count
        free
    end

    properties(Access=protected, Hidden=true)
        emptyElement 
        bufferLength
    end

    methods % Dependent property calculation
        function val = get.count(obj)
            % subtract 1 because obj.head is a placeholder for the next data added
            val = obj.getRangeLength(obj.tail, obj.head) - 1;
        end

        function val = get.free(obj)
            val = obj.capacity - obj.count;
        end

        function str = get.dataClass(obj)
            if obj.useCellArray
                str = 'cell';
            elseif isempty(obj.buffer)
                str = 'unknown';
            elseif isstruct(obj.buffer)
                str = 'struct with fields: ';
                flds = fieldnames(obj.buffer);
                for ifld = 1:length(flds)
                    str = sprintf('%s%s, ', str, flds{ifld});
                end
                str = str(1:end-2);
            else
                str = class(obj.buffer);
            end
        end
    end

    methods % public methods 
        function obj = RingBuffer(useCellArray, capacity)
            % obj = RingBuffer(useCellArray, capacity)
            if nargin < 2
                error('Usage: RingBuffer(useCellArray, capacity)');
            end

            assert(capacity > 0, 'Capacity must be > 0');

            obj.useCellArray = useCellArray;
            obj.capacity = capacity;
            obj.bufferLength = capacity + 1; % this eliminates empty or full ambiguity when head == tail
            obj.head = 1;
            obj.tail = 1;
            obj.buffer = [];
        end

        function addAtHead(obj, data)
            % addAtHead(data) - adds data in forward order at the head
            
            if isempty(data)
                return;
            end

            if isempty(obj.buffer)
                obj.initializeToMatchData(data);
            end

            % check data type, you should call this yourself!
            %[tf msg] = obj.isCompatibleWithData(data);
            %if ~tf
            %    error(msg);
            %end

            if ~obj.useCellArray && isstruct(data)
                % we're using a struct array, check field consistency
                if obj.structAllowPartialFields 
                    data = obj.addMissingFieldsToData(data);
                end
                
                if obj.structAllowAdditionalFields
                    obj.addMissingFieldsToBuffer(data);
                end

                assert(isequal(sort(fieldnames(data)), sort(fieldnames(obj.buffer))), ...
                    'New data fields incompatible with buffer. See structAllowPartialFields and structAllowAdditionalFields is specified');

                % reorder the fields in the same order as in the buffer
                data = orderfields(data, obj.buffer);
            end

            % only adding one item to a cell array? wrap it in a cell
            if obj.useCellArray & ~iscell(data)
                data = {data};
            end

            nNewData = length(data);

            % check capacity
            assert(length(data) <= obj.free, ...
                'This buffer is not big enough to accomodate %d new elements. \nTry calling: getExpandedCopy(%d)', ...
                nNewData, nNewData + obj.count);

            % store in the ring buffer
            idxStore = obj.getRelativeIdx(obj.head, 1:nNewData);
            obj.buffer(idxStore) = data; 

            % move the head forward
            obj.head = double(obj.getRelativeIdx(idxStore(end), 2));
        end

        function addBehindTail(obj, data)
            error('Not yet implemented!');
        end

        function flush(obj)
            % flush() - completely empty this buffer
            obj.buffer = [];
            obj.head = 1;
            obj.tail = 1;
        end

        function data = peekFromTail(obj, nElements)
            % data = peekFromTail(nElements)
            % returns nElements from the tail forwards in FIFO order
            if ~exist('nElements', 'var')
                nElements = [];
            end
            data = obj.peekFromIdx(obj.tail, nElements);
        end

        function data = removeFromTail(obj, nElements)
            % data = removeFromTail(nElements)
            % returns and removes nElements from the tail forwards in FIFO order
            if ~exist('nElements', 'var')
                % this allows cell values to be unwrapped
                data = obj.peekFromTail();
                nElements = 1;
            else
                data = obj.peekFromTail(nElements);
            end

            if nElements == 0
                return;
            end

            obj.wipeFromTail(nElements);
        end

        function wipeFromTail(obj, nElements)
            if ~exist('nElements', 'var')
                nElements = 1;
            end

            % wipe this region (no need for this, useful for debugging)
            % idx = obj.getRelativeIdx(obj.tail, 1:nElements);
            % obj.wipeRegion(idx);

            % advance the tail
            obj.tail = double(obj.getRelativeIdx(obj.tail, nElements + 1));
        end

        function data = peekBackwardsFromHead(obj, nElements)
            % data = peekBackwardsFromHead(nElements)
            % returns nElements from the head backwards in LIFO order
            if ~exist('nElements', 'var')
                nElements = [];
                startIdx = obj.head - 1;
            else
                startIdx = obj.head - nElements;
            end

            data = obj.peekFromIdx(startIdx, nElements);
            data = fliplr(data); 
        end

        function data = popBackwardsFromHead(obj, nElements)
            % data = popBackwardsFromHead(nElements)
            % returns and removes nElements from the head backwards in LIFO order
            if ~exist('nElements', 'var')
                % this allows cell values to be unwrapped
                data = obj.peekBackwardsFromHead();
                nElements = 1;
            else
                data = obj.peekBackwardsFromHead(nElements);
            end

            if nElements == 0
                return;
            end
           
            obj.wipeBackwardsFromHead(obj, nElements);

        end
        
        function wipeBackwardsFromHead(obj, nElements)
            % wipe that region if you like, though there's no need for this
            % idx = obj.getRelativeIdx(obj.head, 0:-1:-nElements+1);
            % obj.wipeRegion(idx);

            % rewind the head
            obj.head = double(obj.getRelativeIdx(obj.head, -nElements + 1));
        end

        function data = addMissingFieldsToData(obj, data)
            % for each field in buffer that's not in data, set data.field = []
            addFields = setdiff(fieldnames(obj.buffer), fieldnames(data));
            for i = 1:length(addFields)
                [data.(addFields{i})] = deal([]);
            end
            
        end

        function addMissingFieldsToBuffer(obj, s)
            % addFields = makeBufferCompatibleWithStruct(s)
            % When storing structs in a struct array, adds fields to the internal buffer
            % to allow the struct s to be stored.
            %
            % Specifically, for each field in s that is not in buffer, sets each
            % buffer(:).field = []
            
            assert(~obj.useCellArray && (isempty(obj.buffer) || isstruct(obj.buffer)), ...
                'This buffer does not use a struct array');
            
            oldFields = fieldnames(obj.buffer);
            newFields = fieldnames(s);

            % for each field in s that is not in buffer, set buffer.field = []
            addFields = setdiff(newFields, oldFields);
            for iF = 1:length(addFields)
                [obj.buffer.(addFields{iF})] = deal([]);
            end
        end
    end

    methods % public utility methods
        function wipeRegion(obj, idx)
            assert(all(idx > 0 & idx <= obj.bufferLength), 'Index out of range');

            if obj.useCellArray
                [obj.buffer{idx}] = deal(obj.emptyElement);
            else
                obj.buffer(idx) = obj.emptyElement;
            end
        end

        function tf = hasCapacityFor(obj, data)
            % tf = hasCapacityFor(data)
            tf = length(data) <= obj.free;
        end

        function [tf msg] = isCompatibleWithData(obj, data)
            % [tf msg] = isCompatibleWithData(obj, data)
            if ~obj.useCellArray
                if iscell(data)
                    msg = 'This queue does not use a cell array';
                    tf = false;
                    return;
                end

                if ~isempty(obj.buffer)
                    if ~isequal(class(data), class(obj.buffer))
                        msg = sprintf('New data must match the class() of existing data [ %s ]', ...
                            obj.dataClass);
                        tf = false;
                        return;
                    end
                    if isstruct(obj.buffer)
                        if obj.structAllowPartialFields
                            if ~all(ismember(fieldnames(data), fieldnames(obj.buffer)))
                                msg = 'New data has fields which are not a subset of this buffer''s fields';
                                tf = false;
                                return
                            end
                        else
                            if ~isequal(fieldnames(obj.buffer), fieldnames(data))
                                msg = 'New data has a different set of fields than existing data';
                                tf = false;
                                return;
                            end
                        end
                    end
                end
            end

            tf = true;
            msg = '';
        end


        function tf = isRangeWithinData(obj, idx)
            % tf = isRangeWithinData(obj, idx)
            idxData = obj.getRelativeIdx(obj.tail, 1:obj.count);
            tf = all(ismember(idx, idxData));
        end

        function newBuffer = getExpandedCopy(obj, minSize, useRepeatedDoubling)
            if ~exist('useRepeatedDoubling', 'var')
                useRepeatedDoubling = true;
            end

            % only allow expansion
            minSize = max(minSize, obj.capacity);
            
            if useRepeatedDoubling
                % double the current size as many times as necessary to accomodate minSize 
                newSize = obj.capacity * 2^(ceil(log(minSize/obj.capacity) / log(2)));
            else
                % just provide the minimum
                newSize = minSize;
            end

            % create new ring buffer with new size
            newBuffer = RingBuffer(obj.useCellArray, newSize);

            % copy over the values of any parameters
            newBuffer.structAllowPartialFields  = obj.structAllowPartialFields;
            newBuffer.structAllowAdditionalFields = obj.structAllowAdditionalFields;
            
            % copy everything over
            data = obj.peekFromTail(obj.count);
            newBuffer.addAtHead(data);
        end

        function newBuffer = getExpandedCopyToHoldData(obj, data)
            % newBuffer = getExpandedCopyToHoldData(data)
            useRepeatedDoubling = true;
            minSize = obj.count + length(data);
            newBuffer = obj.getExpandedCopy(minSize, true); 
        end
    end

    methods (Access=protected) % private utility methods
        function idxRelative = getRelativeIdx(obj, refAtIdxEquals1, idx)
            % convert idx relative to ref==1 to idx into ringBuf, wrap around if necessary 
            % note that if idx == 1, idxRelative will equal refAtIdxEquals1

            % assert(~any(idx > obj.bufferLength | idx <= -obj.bufferLength), 'Index out of range');

            idxRelative = mod((idx+refAtIdxEquals1-1) - 1, obj.bufferLength) + 1;
        end

        function n = getRangeLength(obj, idxStart, idxEnd)
            % gets the number of indices between idxStart and idxEnd inclusive and with wrap around
            
            % assert(~any([idxStart idxEnd] < 0 | [idxStart idxEnd] > obj.bufferLength), 'Index out of range');

            if idxStart <= idxEnd
                n = idxEnd-idxStart+1;
            else
                n = idxEnd+obj.bufferLength-idxStart+1;
            end
        end

        function data = peekFromIdx(obj, ref, nElements)
            % if the user specifies nElements, return an array or cell array of
            % that size. If not specified return 1 element by default, and do not
            % wrap that element in a cell array.
            unwrapFromCell = false;
            if ~exist('nElements', 'var') || isempty(nElements)
                nElements = 1;
                unwrapFromCell = obj.useCellArray;
            end

            if nElements == 0
                data = [];
                return;
            end
            
            if obj.count == 0
                error('Buffer is empty');
            end

            idx = obj.getRelativeIdx(ref, 1:nElements);
            assert(nElements <= obj.count, 'Not enough elements in buffer'); 
            % assert(obj.isRangeWithinData(idx), 'Specified range does not lie entirely within stored data');

            data = obj.buffer(idx);
            if unwrapFromCell
                data = data{1};
            end
        end

        function data = popFromIdx(obj, ref, nElements)
            if ~exist('nElements', 'var') || isempty(nElements)
                data = peekFromIdx(obj, ref);
                nElements = length(data);
            else
                data = peekFromIdx(obj, ref, nElements);
            end

        end

        function e = getEmptyElementForData(obj, data)
            if iscell(data)
                e = [];

            elseif isnumeric(data)
                e = zeros(1, class(data(1)));

            elseif isstruct(data)
                e = data(1);
                flds = fieldnames(data);
                for ifld = 1:length(flds)
                    e.(flds{ifld}) = [];
                end

            elseif isobject(data)
                e = data.empty; 

            else
                error('Unknown data type. Cannot create empty element to initialize buffer');
            end
        end

        function initializeToMatchData(obj, data)
            % buffer will be one length longer than the capacity, to eliminate
            % ambiguity when head == tail
            %
            % assign firstData to last element of buffer 
            % this will initialize buffer to be the correct size
            assert(~isempty(data), 'Cannot initialize to match empty data');

            obj.emptyElement = obj.getEmptyElementForData(data);

            if obj.useCellArray
                obj.buffer = cell(obj.capacity+1, 1);
            else
                obj.buffer = data(1);
                obj.buffer(obj.capacity+1) = data(1);

                % now replace that last element with something empty
                obj.buffer(1) = obj.emptyElement;
                obj.buffer(obj.capacity+1) = obj.emptyElement;
            end
        end

    end

end

