classdef PcoEdge5p5 < Pco
    %:class:`PcoEdge5p5` model configuration for PCO Edge 5.5 cameras.
    % Adds sensor-specific parameters including :attr:`CameraModel`, :attr:`PixelSize` [m],
    % :attr:`ImageSize` [pix], and :attr:`BitsPerSample`.
    methods
        function obj = PcoEdge5p5(acqName)
            % Construct a :class:`PcoEdge5p5`.
            %
            % :param acqName: Camera config name
            % :type acqName: string
            arguments
                acqName string
            end
            obj@Pco(acqName);
            obj.CameraModel = "Edge5p5";
            obj.PixelSize = 6.5e-06;
            obj.ImageSize = [2160,2560];
            obj.BitsPerSample = 16;
            obj.QuantumEfficiencyData = loadVar("quantumEfficiency.mat","pcoQE");
        end
    end
end

