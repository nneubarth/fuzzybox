clear all;
close all;

%%%% user input
num_files = 10;
%%%%%%%%%%%%

for j = 1:num_files
    [avifilename, avipath] = uigetfile('*.avi','pick your file');
    eval(['fullfilename' num2str(j) ' = [avipath avifilename]']);
end

for kk = 1:num_files
    eval(['fullfilename=fullfilename' num2str(kk)]);
    vidObj = VideoReader(fullfilename);
    
    k = 1;
    while k < 2
        sampleFrame = readFrame(vidObj);
        k = k+1;
    end
    
    figure('units','normalized','outerposition',[0 0 1 1]);
    image(sampleFrame); axis image;
    
    a = text(100, 75, 'Pick cage 1 left object', 'Color', 'b');
    h = impoly;
    pos = getPosition(h);
    roi.bwLeftObj1 = poly2mask(pos(:,1),pos(:,2),size(sampleFrame,1),size(sampleFrame,2));
    x = regionprops(roi.bwLeftObj1,'Centroid');
    roi.bwLeftObj1Center = x.Centroid;
    delete(a);
   
    a = text(100, 75, 'Pick cage 1 right object', 'Color', 'r');
    h = impoly;
    pos = getPosition(h);
    roi.bwRightObj1 = poly2mask(pos(:,1),pos(:,2),size(sampleFrame,1),size(sampleFrame,2));
    x = regionprops(roi.bwRightObj1,'Centroid');
    roi.bwRightObj1Center = x.Centroid;
    delete(a);
    
    a = text(400, 75, 'Pick cage 2 left object', 'Color', 'b');
    h = impoly;
    pos = getPosition(h);
    roi.bwLeftObj2 = poly2mask(pos(:,1),pos(:,2),size(sampleFrame,1),size(sampleFrame,2));
    x = regionprops(roi.bwLeftObj2,'Centroid');
    roi.bwLeftObj2Center = x.Centroid;
    delete(a);
    
    a = text(400, 75, 'Pick cage 2 right object', 'Color', 'r');
    h = impoly;
    pos = getPosition(h);
    roi.bwRightObj2 = poly2mask(pos(:,1),pos(:,2),size(sampleFrame,1),size(sampleFrame,2));
    x = regionprops(roi.bwRightObj2,'Centroid');
    roi.bwRightObj2Center = x.Centroid;
    delete(a);
    
    a = text(400, 75, 'Pick two points between the cages', 'Color', 'g');
    [x,y] = ginput(2);
    roi.boundX = mean(x);
    delete(a);
    close all;
    
    save(strcat(fullfilename(1:end-4), '_roi.mat'),'roi');

end




