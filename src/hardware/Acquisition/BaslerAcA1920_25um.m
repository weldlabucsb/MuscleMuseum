classdef BaslerAcA1920_25um < Basler
    %:class:`BaslerAcA1920_25um` model configuration for Basler acA1920-25um.
    %
    % Sets :attr:`CameraModel`, :attr:`PixelSize` [m], :attr:`ImageSize` [pix], and
    % :attr:`BitsPerSample` appropriate for this sensor.
    methods
        function obj = BaslerAcA1920_25um(acqName)
            % Construct a :class:`BaslerAcA1920_25um`.
            %
            % :param acqName: Camera config name
            % :type acqName: string
            arguments
                acqName string
            end
            obj@Basler(acqName);
            obj.CameraModel = "AcA1920_25um";
            obj.PixelSize = 2.2e-06;
            obj.ImageSize = [1080,1920];
            obj.BitsPerSample = 8;
        end
    end
end

