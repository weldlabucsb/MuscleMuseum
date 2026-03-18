%% Siglent SDS2104X+ Test Script
clear; clc;

% =========================
% USER SETTINGS
% =========================
resourceName = "TCPIP0::172.16.0.6::inst0::INSTR"; 
scopeName = "SiglentTest";

NSAMPLE = 1e5;     % Number of points
DURATION = 1e-3;   % Total time window (1 ms)

% =========================
% CREATE SCOPE OBJECT
% =========================
scope = SiglentSDS2104XPlus(resourceName, scopeName);

% Configure properties (assuming your base class supports these)
scope.NSample = NSAMPLE;
scope.Duration = DURATION;

scope.NChannel = 1;
scope.IsEnabled = [true];

scope.VerticalRange = [2];     % Volts full scale
scope.VerticalOffset = [0];
scope.VerticalCoupling = ["DC"];

scope.TriggerMode = "EDGE";
scope.TriggerSource = "CH1";
scope.TriggerSlope = "POS";
scope.TriggerLevel = 0;

% =========================
% CONNECT + SETUP
% =========================
disp("Connecting to scope...");
scope.connect();

disp("Configuring scope...");
scope.set();

pause(0.5); % Let scope settle

% =========================
% ACQUIRE DATA + TIMING
% =========================
disp("Reading waveform...");

tStart = tic;
scope.read();
elapsedTime = toc(tStart);

fprintf("Total acquisition time: %.6f seconds\n", elapsedTime);

% =========================
% EXTRACT DATA
% =========================
data = scope.Sample(1, :);

% Create time axis
dt = scope.Duration / scope.NSample;
t = (0:length(data)-1) * dt;

% =========================
% PLOT
% =========================
figure;
plot(t, data);
xlabel("Time (s)");
ylabel("Voltage (V)");
title("Siglent SDS2104X+ Channel 1 Capture");
grid on;

% =========================
% CLEAN UP
% =========================
scope.close();
disp("Done.");