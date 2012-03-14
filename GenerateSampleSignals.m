function signals = GenerateSampleSignals(subject, protocol) 

if ~exist('subject', 'var')
    subject = 'TestSubject';
end
if ~exist('protocol', 'var')
    protocol = 'TestProtocol';
end

%% Parameters and generator functions 
nTrials = 15;

nEvents = [5 5 10];
nEventGroups = length(nEvents);

nAnalog = [3 3 3];
nAnalogGroups = length(nAnalog);

nParams = [10 3];
nParamGroups = length(nParams);

trialLengthRange = [300 800];

paramNameFn = @(groupIdx, idx) sprintf('param%d', idx);
paramGroupNameFn = @(groupIdx) sprintf('paramGroup%d', groupIdx);
paramGeneratorFn = @(groupIdx, idx, trialNum, ts, trialTime) 100*trialNum + 10*groupIdx + idx; 

eventNameFn = @(group, idx) sprintf('event%d', idx);
eventGroupNameFn = @(groupIdx) sprintf('eventGroup%d', groupIdx);

analogSamplePeriod = 10;
analogNameFn = @(group, idx) sprintf('channel%d',idx);
analogGroupNameFn = @(groupIdx) sprintf('analog%d', groupIdx);
analogGeneratorFn = @(groupIdx, idx, trialNum, ts, timeWithinTrial) sin(2*pi*8*(ts+10*idx));

%% Build signals

sigQ = Queue(false);

% Generate info control packet

ts = 1;
ctrl = struct('command', 'SetInfo', 'protocol', protocol, 'subject', subject);
sigQ.add(buildGroup(ts, SignalProcessor.GROUPTYPE_CONTROL, 'control', ctrl));

% Generate trial data

fprintf('Generating sample signal data\n');

for iTrial = 1:nTrials
    textprogressbar(sprintf('Building trial %d', iTrial));
    trialStart = ts;

    trialLength = randi(trialLengthRange);

    % generate some event times
    for iEG = 1:nEventGroups
        eventTimes{iEG} = randi(trialLengthRange, nEvents(iEG), 1);
    end

    % send out the parameters
    for iPG = 1:nParamGroups
        data = [];
        for iP = 1:nParams(iPG)
            data.(paramNameFn(iPG, iP)) = paramGeneratorFn(iPG, iP, iTrial, ts, 1); 
        end
        groupName = paramGroupNameFn(iPG);
        sigQ.add(buildGroup(ts, SignalProcessor.GROUPTYPE_PARAM, groupName, data));
    end

    for timeWithinTrial = 1:trialLength
        
        if mod(timeWithinTrial-1, analogSamplePeriod) == 0
            textprogressbar(timeWithinTrial / trialLength);
            % generate the analog packets
            for iAG = 1:nAnalogGroups
                data = [];
                for iA = 1:nAnalog(iAG)
                    data.(analogNameFn(iAG, iA)) = analogGeneratorFn(iAG, iA, iTrial, ts, timeWithinTrial);
                end
                groupName = analogGroupNameFn(iAG);
                sigQ.add(buildGroup(ts, SignalProcessor.GROUPTYPE_ANALOG, groupName, data));
            end
        end
        
        % check each event, send if it's now
        for iEG = 1:nEventGroups
            if ~any(eventTimes{iEG} == timeWithinTrial)
                continue;
            end
            for iE = 1:nEvents(iEG)
                if eventTimes{iEG}(iE) == timeWithinTrial
                    data = [];
                    data.name = eventNameFn(iEG, iE);
                    groupName = eventGroupNameFn(iEG);
                    sigQ.add(buildGroup(ts, SignalProcessor.GROUPTYPE_EVENT, groupName, data));
                end
            end
        end
    
        ts = ts + 1;
    end

    % send trial advance control group
    ctrl = struct('command', 'NextTrial');
    sigQ.add(buildGroup(ts, SignalProcessor.GROUPTYPE_CONTROL, 'control', ctrl));

    textprogressbar('done', true);
end

signals = sigQ.removeAll();
end

function signals = buildGroup(ts, typeId, name, data)
    GROUP_VERSION = 2;
    sigNames = fieldnames(data);
    nSig = length(sigNames);
    nHeaderSignals = 4;

    % add the header signals
    signals(1) = buildSignal(ts, 'v', GROUP_VERSION);
    signals(nSig+nHeaderSignals) = signals(1);
    signals(2) = buildSignal(ts, 'type', typeId);
    signals(3) = buildSignal(ts, 'name', name);
    signals(4) = buildSignal(ts, 'n', nSig);

    % add the data signals
    for iSig = 1:nSig
        signals(iSig+nHeaderSignals) = buildSignal(ts, sigNames{iSig}, data.(sigNames{iSig}));
    end
end

function signal = buildSignal(ts, name, data)
    signal.timestamp = ts;
    signal.name = name;
    signal.data = data;
end

