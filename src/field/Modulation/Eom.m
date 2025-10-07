classdef Eom < handle
    %:class:`Eom` models an electro-optic modulator RF-induced frequency shift.
    %
    % Provides sideband frequency offsets proportional to the RF frequency.
    %
    % **Example:**
    %
    % .. code-block:: matlab
    %
    %    e = Eom(40);  % 40 MHz
    %    df = e.shift(+1);  % +40 MHz first-order
    %
    properties
        RfFrequency % RF frequency [MHz]
    end
    
    methods
        function obj = Eom(omegaRf)
            % Construct an :class:`Eom`.
            %
            % :param omegaRf: RF frequency [MHz]
            % :type omegaRf: double
            obj.RfFrequency = omegaRf;
        end
        
        function shift = shift(obj,order)
            % EOM sideband frequency shift.
            %
            % :param order: Sideband order (+/-1, ...)
            % :type order: double
            % :return: Frequency shift [MHz]
            % :rtype: double
            shift = order*obj.RfFrequency;
        end
    end
end

