clear sp

if ~exist('signals', 'var')
    signals = GenerateSampleSignals();
end

sp = SignalProcessor();
sp.receiveNewSignals(signals);


