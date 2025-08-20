function wfID = saveWaveform(wf,wflID,p,wfID)
arguments
    wf
    wflID int64 = 0
    p = []
    wfID int64 = []
end
if isempty(p)
    p = WaveformLibrary;
end

t = wf.convert2Table;
t.WaveformListID = wflID;
if isempty(wfID)
    p.writeEntry(t)
    wfID = p.getLastID;
else
    t.ID = wfID;
    p.updateEntry(t)
end
end

