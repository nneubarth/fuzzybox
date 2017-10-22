%% Modified from Ginty Lab code written by Chris Harvey
%Used to track animal position during NORT assay and object contact time.
%This version is for use with very dim light.  

%files should be in format c1_animal1_c2_animal2_side or 
%c1_animal1_c2_animal2_test_side depending on if exploration or testing
%trial. animal1, animal2 = IDs of mice, side = R or L indicating side of
%novel object.

%Must run nort_selectobjects.m first to get roi files.

%saves a .mat file with all data.

clear all;
close all;

%%%% user input
num_files =10;
endTime = 0*60*.17; % end time in seconds; to use the entire movie, set to 0; to use 5 minutes set to 5*60*0.9 (0.9 for compression factor)
%%%%%%%%%%%%e

nTest = 0;
nExplore = 0;

novelRatio = struct('file',{},'exploretime',[],'novelratio',[]);
size_nR = 0;
for j = 1:num_files
    [avifilename, avipath] = uigetfile('*.avi','pick your file');
    eval(['fullfilename' num2str(j) ' = [avipath avifilename]']);
    filename{j} = avifilename;
    rightname = '_R.avi';
    leftname = '_L.avi';
    if ~isempty(regexp(avifilename,rightname))
        novelside{j} = 'R';
    else if ~isempty(regexp(avifilename,leftname))
        novelside{j} = 'L'; 
        else
            'Check input file names'
            break
        end
    end
    
        
end

for kk = 1:num_files
    eval(['fullfilename=fullfilename' num2str(kk)]);
    load(strcat(fullfilename(1:end-4), '_roi.mat'));
    
    obj(kk).bwLeftObj1 = roi.bwLeftObj1;
    obj(kk).bwLeftObj1Center = roi.bwLeftObj1Center;
    
    obj(kk).bwRightObj1 = roi.bwRightObj1;
    obj(kk).bwRightObj1Center = roi.bwRightObj1Center;
    
    obj(kk).bwLeftObj2 = roi.bwLeftObj2;
    obj(kk).bwLeftObj2Center = roi.bwLeftObj2Center;
    
    obj(kk).bwRightObj2 = roi.bwRightObj2;
    obj(kk).bwRightObj2Center = roi.bwRightObj2Center;
    
    boundX = roi.boundX;
    
    clear roi;
end


for kk = 1:num_files
    clear mov;
    eval(['fullfilename=fullfilename' num2str(kk)]);
    vidObj = VideoReader(fullfilename);

    %%%%% load movie
    k = 1;
    h = waitbar(0,['Loading movie ' num2str(kk) ' of ' num2str(num_files)]);
    while hasFrame(vidObj)
        temp = readFrame(vidObj);
        mov(k).cdata = temp(:,:,1);
        k = k+1;
        waitbar(k/(vidObj.Duration*vidObj.FrameRate))
    end
    close(h)
    
    if endTime > 0
        mov = mov(1:round(endTime*vidObj.FrameRate));
    end
    clear('vidObj');
    

    temp = zeros(size(mov(1).cdata));
    for n = 1:length(mov)
        temp = temp + double(mov(n).cdata);
    end
    avgFrame = uint8(temp/length(mov));
    
    for n = 1:length(mov)
        mov(n).diff = imabsdiff(mov(n).cdata,avgFrame);
    end
    mov = rmfield(mov,'cdata');
    
    diffWin = 300;
    for n = diffWin+1:length(mov)
        mov(n).diff2 = imsubtract(mov(n).diff, mov(n-diffWin).diff);
    end
    mov = mov(diffWin+1:length(mov));
    mov = rmfield(mov,'diff');
    
    for n = 1:length(mov)
        mov(n).diff3 = (mov(n).diff2 - mean2(mov(n).diff2)) / std2(mov(n).diff2);
    end
    mov = rmfield(mov,'diff2');
    

   
    %%%% track mouse
    stdThresh = 3;
    minSigPix = 10;
    hh = waitbar(0,['Tracking mouse in movie ' num2str(kk) ' of ' num2str(num_files)]);
    mLocL = zeros(length(mov),2);
    mLocR = zeros(length(mov),2);
    for n = 1:length(mov)
        temp1 = mov(n).diff3;
        temp1(:,round(boundX):end) = 0;
        temp1(temp1 < stdThresh) = 0;
        temp1(temp1 >= stdThresh) = 1;
        temp1 = bwlabel(temp1);
        props1 = regionprops(temp1);
        if length(props1) > 0
            areas = [props1.Area];
            [maxArea, maxind] = max(areas);
            temp1(temp1 ~= maxind) = 0;
            temp1(temp1 == maxind) = 1;
        end
        temp2 = mov(n).diff3;
        temp2(:,1:round(boundX)) = 0;
        temp2(temp2 < stdThresh) = 0;
        temp2(temp2 >= stdThresh) = 1;
        temp2 = bwlabel(temp2);
        props2 = regionprops(temp2);
        areas = [props2.Area];
        if length(props2) > 0
            [maxArea, maxind] = max(areas);
            temp2(temp2 ~= maxind) = 0;
            temp2(temp2 == maxind) = 1;
        end
        extrema = regionprops(temp1,'Extrema');
        if length(extrema)>0
        longestdist = 0;
        ecombs = combnk(1:size(extrema(1).Extrema,1),2);
        for e=1:size(extrema(1).Extrema,1)
            pt1 = extrema(1).Extrema(ecombs(e,1),:);
            pt2 = extrema(1).Extrema(ecombs(e,2),:);
            edist = norm(pt1-pt2);
            if edist > longestdist
                longestdist = edist;
                long_pt1 = pt1;
                long_pt2 = pt2;
            end
        end
        end
        x = regionprops(temp1,'Centroid');
        if n == 1
            mLocL(n,:) = [0,0];
        else
            if length(find(temp1 == 1)) >= minSigPix
                mLocL(n,:) = [x.Centroid(1),x.Centroid(2)];
            else
                mLocL(n,:) = mLocL(n-1,:);
            end
        end
        
        x = regionprops(temp2,'Centroid');
        if n == 1
            mLocR(n,:) = [0,0];
        else
            if length(find(temp2 == 1)) >= minSigPix
                mLocR(n,:) = [x.Centroid(1),x.Centroid(2)];
            else
                mLocR(n,:) = mLocR(n-1,:);
            end
        end
        waitbar(n/length(mov))
    end
    close(hh)
    
    data.cage1Loc = mLocL;
    data.cage2Loc = mLocR;

   
    
    %%%%%%%%%%%%%%%%%
    temp11 = [];
    stdThresh = 1;
    cage1LTouch = zeros(1,length(mov));
    cage1RTouch = zeros(1,length(mov));
    cage2LTouch = zeros(1,length(mov));
    cage2RTouch = zeros(1,length(mov));
    hh = waitbar(0,['Looking for touches in movie ' num2str(kk) ' of ' num2str(num_files)]);
    for n = 1:length(mov)
        
        temp1 = mov(n).diff3;
        temp1(:,round(boundX):end) = 0;
        temp1(temp1 < stdThresh) = 0;
        
        temp2 = mov(n).diff3;
        temp2(:,1:round(boundX)) = 0;
        temp2(temp2 < stdThresh) = 0;
        
        bw = double(temp1+temp2);
        %overlap of mice with objects
        temp = find(obj(kk).bwLeftObj1 == 1);
        mov(n).cage1L = bw(temp);
        
        temp = find(obj(kk).bwRightObj1 == 1);
        mov(n).cage1R = bw(temp);
        
        temp = find(obj(kk).bwLeftObj2 == 1);
        mov(n).cage2L = bw(temp);
        
        temp = find(obj(kk).bwRightObj2 == 1);
        mov(n).cage2R = bw(temp);
        
        waitbar(n/length(mov))
    end
    close(hh);
    
    
    data.cage1.left = zeros(1,length(mov));
    data.cage1.right = zeros(1,length(mov));
    data.cage2.left = zeros(1,length(mov));
    data.cage2.right = zeros(1,length(mov));
    
    minPix = 10;
    minStd = 3;
    for n = 1:length(mov)
        if length(find(mov(n).cage1L >= minStd)) > minPix && sqrt((data.cage1Loc(n,1)-obj(kk).bwLeftObj1Center(1))^2 + (data.cage1Loc(n,2)-obj(kk).bwLeftObj1Center(2))^2) < 100
            data.cage1.left(n) = 1;
        end
        if length(find(mov(n).cage1R >= minStd)) > minPix && sqrt((data.cage1Loc(n,1)-obj(kk).bwRightObj1Center(1))^2 + (data.cage1Loc(n,2)-obj(kk).bwRightObj1Center(2))^2) < 100
            data.cage1.right(n) = 1;
        end
        if data.cage1.left(n) == 1 && data.cage1.right(n) == 1
            if length(find(mov(n).cage1L >= minStd)) > length(find(mov(n).cage1R >= minStd))
                data.cage1.right(n) = 0;
            else
                data.cage1.left(n) = 0;
            end
        end          
                       
        if length(find(mov(n).cage2L >= minStd)) > minPix && sqrt((data.cage2Loc(n,1)-obj(kk).bwLeftObj2Center(1))^2 + (data.cage2Loc(n,2)-obj(kk).bwLeftObj2Center(2))^2) < 100
            data.cage2.left(n) = 1;
        end
        if length(find(mov(n).cage2R >= minStd)) > minPix && sqrt((data.cage2Loc(n,1)-obj(kk).bwRightObj2Center(1))^2 + (data.cage2Loc(n,2)-obj(kk).bwRightObj2Center(2))^2) < 100
            data.cage2.right(n) = 1;
        end
        if data.cage2.left(n) == 1 && data.cage2.right(n) == 1
            if length(find(mov(n).cage2L >= minStd)) > length(find(mov(n).cage2R >= minStd))
                data.cage2.right(n) = 0;
            else
                data.cage2.left(n) = 0;
            end
        end
    end
    
    left1 = 0;
    left2 = 0;
    right1 = 0;
    right2 = 0;
    novelRatio(size_nR+1).file = filename(kk);
    novelRatio(size_nR+2).file = filename(kk);
    for n = 1:length(mov)
        if data.cage1.left(n) == 1
            left1 = left1 + 1;
        end
        if data.cage1.right(n) == 1
            right1 = right1 + 1;
        end
        if data.cage2.left(n) == 1
            left2 = left2 + 1;
        end
        if data.cage2.right(n) == 1
            right2 = right2 + 1;
        end
        novelRatio(size_nR+1).exploretime(n) = (right1+left1);
        novelRatio(size_nR+2).exploretime(n) = (right2+left2);
        if novelside{kk} == 'R'
            novelRatio(size_nR+1).novelratio(n) = right1/(right1+left1+.01);
            novelRatio(size_nR+2).novelratio(n) = right2/(right2+left2+.01);
        else if novelside{kk} == 'L'
                novelRatio(size_nR+1).novelratio(n) = left1/(right1+left1+.01);
                novelRatio(size_nR+2).novelratio(n)= left2/(right2+left2+.01);
            end
        end
            
    end
size_nR = size_nR+2;
n_side = novelside{kk};
save(strcat(fullfilename(1:end-4), '.mat'),'data','obj','n_side');   


   
end




