function obj = loadSim(serialNumber,simName,trialName)
%LOADSIM Summary of this function goes here
%   Detailed explanation goes here
arguments
    serialNumber
    simName string
    trialName string = "Test"
end
p = SimSetting;
databaseName = p.readValueTwoKey(simName,trialName,"DatabaseName","SimName","TrialName");
databaseTableName = p.readValueTwoKey(simName,trialName,"DatabaseTableName","SimName","TrialName");
conn = createReader(databaseName);
obj = loadTrial(conn,databaseTableName,serialNumber);

end

