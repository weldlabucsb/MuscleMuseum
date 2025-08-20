function saveWaveformList(wfl,p,p2)
arguments
    wfl
    p = []
    p2 = []
end
if isempty(p)
    p = WaveformListLibrary;
end
if isempty(p2)
    p2 = WaveformLibrary;
end
t = wfl.convert2Table;
p.updateEntry(t,"Name")
wflID = p.readValue(t.Name,"ID","Name");
wfo = p.readValue(wflID,"WaveformOrigin");
nwf = numel(wfl.WaveformOrigin);
if nwf == 0
    p.updateValue(wflID,"WaveformOrigin",{[]})
    return
end
if ~isempty(wfo)
    p2.deleteEntry(wfo)
end
id = zeros(1,nwf);
for ii = 1:numel(wfl.WaveformOrigin)
    id(ii) = saveWaveform(wfl.WaveformOrigin{ii},wflID,p2); 
end
p.updateValue(wflID,"WaveformOrigin",{id});
end

