function saveWaveform(wf,wflID)
%SAVEWAVEFORM Summary of this function goes here
%   Detailed explanation goes here
arguments
    wf
    wflID double
end
p = WaveformLibrary;
wfName = class(wf);
mc = metaclass(wf);
prop = mc.PropertyList;
prop = prop(~([prop.Dependent] | [prop.Constant] | [prop.Hidden]));
prop = string({prop.Name});
prop(ismember(prop,["SamplingRate","Scan"])) = [];
if isa(wf,"ConstantTop")
    prop(ismember(prop,["Frequency","Phase"]))=[];
end
% if ismember(wfName,app.ExceptionWaveform)
%     prop(ismember(prop,["Offset","Amplitude","RiseTime","FallTime"]))=[];
% end
val = zeros(numel(prop),1);
for ii = 1:numel(prop)
    val(ii) = wf.(prop(ii));
end
end

