clearvars sp ts

subject = 'TestMonkey';
protocol = 'TestProtocol';

ts = TrialDataSaver(subject, protocol);
matFile = ts.matFile;

fprintf('Trials file : %s\n', matFile);

if exist(matFile, 'file')
    delete(matFile);
end

if ~exist('signals', 'var')
    signals = GenerateSampleSignals(subject, protocol);
end

sp = SignalProcessor();
sp.receiveNewSignals(signals);

data = load(ts.matFile);
