
classdef SignalProcessor < handle

    properties
        signalDir 
        indexFile
    end

    properties(Dependent)
        signalsPending
    end
    
    properties(Hidden=true)
        loader
        signalQueue 
    end
    
    methods
        function val = get.signalsPending(obj)
            val = obj.signalQueue.count;
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
        end

        function poll(obj) 
            obj.receiveNewSignals(obj.loader.poll(50));
        end

        function hasSignals = receiveNewSignals(obj, newData)
            % check that all newData.data have a .signals variable within
            hasSignals = arrayfun(@(d) isfield(d.data, 'signals'), newData); 

            assert(all(hasSignals), 'Unexpectedly received data without signals within');

            % concatenate all of the signals from all of the files
            data = [newData.data];
            signalsCell = {data.signals}';
            signals = cell2mat(signalsCell);
            
            % add to the queue
            obj.signalQueue.add(signals);
        end

        function group = nextGroup(obj, newData)
            sigV = obj.signalQueue.peek();
            assert(strcmp(sigV.name, 'v'));
            assert(isequal(sigV.data, 1));

            sigName = obj.signalQueue.peek();
            assert(strcmp(sigName.name, 'name');

            sigType = obj.signalQueue.peek();
            assert(strcmp(sigName.
            group.timestamp =  
        end
    end
end

