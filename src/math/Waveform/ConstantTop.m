classdef (Abstract) ConstantTop < handle
    %:class:`ConstantTop` abstract base class for constant-top waveform generation.
    %
    % Provides common functionality for waveforms that maintain a constant
    % amplitude level during their active period. Used as a base class for
    % pulse-like signals with flat tops. Inherits from :class:`handle`.
    %
    % **Example1:**
    %
    % .. code-block:: matlab
    %
    %     % Create a constant-top pulse
    %     pulse = TrapezoidalPulse(amplitude = 2.0, duration = 0.01);
    %     pulse.plot();
    %
    % **Example2:**
    %
    % .. code-block:: matlab
    %
    %     % Create a constant-top sine pulse
    %     pulse = SinePulse(amplitude = 1.0, frequency = 1000, duration = 0.01);
    %     pulse.plot();
    
    properties
        
    end
    
    methods
        function obj = ConstantTop()
            %Construct a ConstantTop object.
            %
            % Abstract base class constructor. Subclasses should implement
            % their own constructors with appropriate parameters.
        end
    end
end

