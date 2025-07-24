classdef PcoEdge5p5 < Pco
    % PCOEDGE5P5 Subclass of the Pco and Acquisition class
    % Adds additional parameters corresponding to the PcoEdge 5.5 camera.
    methods
        function obj = PcoEdge5p5(acqName)
            arguments
                acqName string
            end
            obj@Pco(acqName);
            obj.CameraModel = "Edge5p5";
            obj.PixelSize = 6.5e-06;
            obj.ImageSize = [2160,2560];
            obj.BitsPerSample = 16;
        end
    end
end

