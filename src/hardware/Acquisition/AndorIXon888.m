classdef AndorIXon888 < Andor
    %:class:`AndorIXon888` model configuration for Andor iXon 888 cameras.
    %
    % Sets :attr:`CameraModel`, :attr:`PixelSize` [m], :attr:`ImageSize` [pix], and
    % :attr:`BitsPerSample` for this sensor.
    methods
        function obj = AndorIXon888(acqName)
            % Construct a :class:`AndorIXon888`.
            %
            % :param acqName: Camera config name
            % :type acqName: string
            arguments
                acqName string
            end
            obj@Andor(acqName);
            obj.CameraModel = "IXon888";
            obj.PixelSize = 13e-06;
            obj.ImageSize = [1024,1024];
            obj.BitsPerSample = 16;
        end
    end
end

