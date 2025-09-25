classdef AndorIXon897 < Andor
    %:class:`AndorIXon897` model configuration for Andor iXon 897 cameras.
    %
    % Sets :attr:`CameraModel`, :attr:`PixelSize` [m], :attr:`ImageSize` [pix], and
    % :attr:`BitsPerSample` for this sensor.
    methods
        function obj = AndorIXon897(acqName)
            % Construct a :class:`AndorIXon897`.
            %
            % :param acqName: Camera config name
            % :type acqName: string
            arguments
                acqName string
            end
            obj@Andor(acqName);
            obj.CameraModel = "IXon897";
            obj.PixelSize = 16e-06;
            obj.ImageSize = [512,512];
            obj.BitsPerSample = 16;
        end
    end
end

