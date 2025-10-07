function updateImageData(img,xData,yData,cData)
img.CData = cData;
img.XData = xData;
img.YData = yData;
axis(img.Parent,'tight')
end

