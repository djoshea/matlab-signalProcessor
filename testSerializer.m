
clear td
td = TrialDataSerializer();

td.protocol = 'TestProtocol';

td.tsStart = 100;
td.tsEnd = 1000;
trialTime = 100:1000;

td.addParam('par', 'p1', 4, 'mm');
td.addParam('par', 'p2', 10, 'ms');
td.addParam('par2', 'p1', 15, 'ms');

td.addEvent('ev', 'ev1', 110, []);
td.addEvent('ev', 'ev2', 150, []);
td.addEvent('ev', 'ev1', 210, []);
td.addEvent('ev', 'ev2', 250, []);

td.addEvent('ev2', 'ev1', 210, []);
td.addEvent('ev2', 'ev1', 210, []);
td.addEvent('ev2', 'ev2', 350, []);
td.addEvent('ev2', 'ev2', 350, []);

td.addAnalog('lfp', 'ch1', trialTime, mod(trialTime,100), 'uV', []);
td.addAnalog('lfp', 'ch2', trialTime, mod(trialTime,200), 'uV', []);
td.addAnalog('lfp', 'ch3', trialTime, mod(trialTime,300), 'uV', []);

td.addAnalog('lfp', 'ch4', trialTime(301:end), mod(trialTime(301:end), 400), 'uV', []);
td.addAnalog('lfp', 'ch4', trialTime(1:300), mod(trialTime(1:300), 400), 'uV', []);

td

r = td.serialize()
