classdef Aom < handle
    %:class:`Aom` models an acousto-optic modulator RF shift.
    %
    % Provides frequency shifts for single-pass (SP) and double-pass (DP) setups.
    % The RF frequency is specified in MHz (linear frequency).
    %
    % **Example:**
    %
    % .. code-block:: matlab
    %
    %    a = Aom(80);   % 80 MHz
    %    df = a.shiftSP(1);   % +80 MHz
    %    df2 = a.shiftDP(-1); % -160 MHz
    %
    properties
        RfFrequency %RF frequency in MHz
    end
    
    methods
        function obj = Aom(omegaRf)
            % Construct an :class:`Aom`.
            %
            % :param omegaRf: RF frequency in MHz
            % :type omegaRf: double
            obj.RfFrequency = omegaRf;
        end
        
        function shift = shiftSP(obj,order)
            % Single-pass AOM frequency shift.
            %
            % :param order: Diffraction order (+/-1, ...)
            % :type order: double
            % :return: Frequency shift in MHz
            % :rtype: double
            shift = order*obj.RfFrequency;
        end

        function shift = shiftDP(obj,order)
            % Double-pass AOM frequency shift.
            %
            % :param order: Diffraction order (+/-1, ...)
            % :type order: double
            % :return: Frequency shift in MHz
            % :rtype: double
            shift = 2*order*obj.RfFrequency;
        end
    end
end

