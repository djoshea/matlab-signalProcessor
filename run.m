
signalDir = '/expdata/signals/20120216';
indexFile = fullfile(signalDir, 'index.txt');

fl = IndexedFileLoader(indexFile, signalDir, @load); 

update = @(data) fprintf('New signal files : %5d\n',length(data));
fl.start(update);


