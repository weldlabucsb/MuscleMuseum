function wf = loadWaveform(wfID,p)
arguments
    wfID int64
    p = []
end
if isempty(p)
    p = WaveformLibrary;
end
s = p.readWaveform(wfID);

wf = eval(s.Type);
wf.SamplingRate = s.SamplingRate;
wf.Scan = s.Scan;
for ii = 1:height(s.Parameter)
    wf.(s.Parameter.Name(ii)) = s.Parameter.Value(ii);
end
if isa(wf,"ModulatedWaveform")
    modList = ["AmplitudeModulation","FrequencyModulation","PhaseModulation"];
    for ii = 1:numel(modList)
        if wfPara2.(modList(ii)) ~= 0
            wf.(modList(ii)) = loadWaveformList(s.(modList(ii)));
        end
    end
end
end

