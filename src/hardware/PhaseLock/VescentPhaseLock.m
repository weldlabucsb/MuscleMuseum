classdef (Abstract) VescentPhaseLock < PhaseLock
    %:class:`VescentPhaseLock` base for Vescent phase-lock modules.
    %
    % Manages a serial connection (:attr:`Serialport`) and provides methods to
    % :meth:`connect`, :meth:`check`, :meth:`lock`, and :meth:`unlock`.
    
    properties
        Serialport internal.Serialport
    end
    
    methods
        function obj = VescentPhaseLock(resourceName,name)
            % Construct a :class:`VescentPhaseLock`.
            %
            % :param resourceName: Serial resource (e.g., "COM3")
            % :type resourceName: string
            % :param name: Device nickname
            % :type name: string, optional
            arguments
                resourceName string
                name string = string.empty
            end
            obj@PhaseLock(resourceName,name);
            obj.Manufacturer = "Vescent";
        end
        
        function connect(obj)
            % Open serial connection using :attr:`ResourceName`.
            if ~isempty(obj.Serialport)
                if isvalid(obj.Serialport)
                    warning("PhaseLock box was already connected")
                    return
                end
            end
            obj.Serialport = serialport(obj.ResourceName,115200);
            configureTerminator(obj.Serialport,"CR");
        end

        function close(obj)
            % Close the serial session.
            delete(obj.Serialport);
        end

        function check(obj)
            % Query lock status and current frequency; update :attr:`Status` and :attr:`CurrentFrequency`.
            if isempty(obj.Serialport)
                error("PhaseLock box is not connected")
            elseif ~isvalid(obj.Serialport)
                error("PhaseLock box was deleted")
            end
            writeline(obj.Serialport,"SERVO?")
            s = strtrim(readline(obj.Serialport));
            if s == "Off"
                obj.Status = false;
            else
                obj.Status = true;
            end
            writeline(obj.Serialport,"BNTGT?")
            s = strtrim(readline(obj.Serialport));
            obj.CurrentFrequency = double(s) * 1e6;
        end

        function lock(obj)
            % Lock to the requested :attr:`Frequency`.
            if isempty(obj.Frequency)
                error("Must specify the lock frequency")
            end
            obj.unlock
            cm = "BNTGT " + num2str(obj.Frequency * 1e-6);
            writeline(obj.Serialport,cm);
            readline(obj.Serialport);
            writeline(obj.Serialport,"SERVO ON");
            readline(obj.Serialport);
        end

        function unlock(obj)
            % Unlock the phase lock (servo off) if currently locked.
            obj.check;
            if obj.Status
                writeline(obj.Serialport,"SERVO OFF");
                readline(obj.Serialport);
            end
        end
    end
end

