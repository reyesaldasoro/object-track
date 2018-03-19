function plotObjectMovie (handlesDir,plotOption,tracksToPlot,framesToPlot)
%function plotObjectMovie (handlesDir,plotOption)
%function plotObjectMovie (handlesDir,plotOption,tracksToPlot)
%function plotObjectMovie (handlesDir,plotOption,tracksToPlot,framesToPlot)
%
%--------------------------------------------------------------------------
% plotObjectMovie  generates a matlab movie that can later be saved as 
%     an AVI
%
%       INPUT
%         handlesDir:       path to where the handles are saved, it also 
%                           requires the dataR to be stored somewhere close by
%         
%         plotOption:       it can plot in many ways:
%                             1 Object intensity in green
%                             2 Object intensity in green plus a slice of DIC
%                             3 Object intensity in JET2
%                             4 Object intensity in JET2 plus a slice of DIC
%                             5 Object Labels in JET2
%                             6 Object Labels in JET2 plus a slice of DIC
%                             7 Object Intensity in green without tracks or DIC
%                             8 Object Intensity in green plus DIC without tracks
%                             9 Object intensity in green SHORT TRACKS
%                             10 Object intensity in green plus
%                             a slice of DICSHORT TRACKS
%
%         tracksToPlot:     subset of tracks to plot
%
%         framesToplot:     subset of frames to plot
%
%
%
%       OUTPUT
%         F:                a struct with the frames of a movie.
%
%--------------------------------------------------------------------------
%
%     Copyright (C) 2012  Constantino Carlos Reyes-Aldasoro
%
%     This file is part of the objectTrack package.
%
%     The objectTrack package is free software: you can redistribute it and/or modify
%     it under the terms of the GNU General Public License as published by
%     the Free Software Foundation, version 3 of the License.
%
%     The objectTrack package is distributed in the hope that it will be useful,
%     but WITHOUT ANY WARRANTY; without even the implied warranty of
%     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%     GNU General Public License for more details.
%
%     You should have received a copy of the GNU General Public License
%     along with the objectTrack package.  If not, see <http://www.gnu.org/licenses/>.
%
%--------------------------------------------------------------------------
%
% This m-file is part of the objectTrack package used to analyse
% small objects as observed through confocal or
% multiphoton microscopes.  For a comprehensive 
% user manual, please visit:
%
%           http://www.objectTrack.org.uk
%
% Please feel welcome to use, adapt or modify the files. If you can improve
% the performance of any other algorithm please contact us so that we can
% update the package accordingly.
%
%--------------------------------------------------------------------------
%
% The authors shall not be liable for any errors or responsibility for the 
% accuracy, completeness, or usefulness of any information, or method in the content, or for any 
% actions taken in reliance thereon.
%
%--------------------------------------------------------------------------
    
%% Parsing the input data
    if (nargin==0)
    %----- no data received, Open question dialog and pass to next section to analyse
    button = questdlg('No data received','Select Handles Folder',...
                      'Select Folder','Cancel','Cancel');
    if strcmp(button(1),'S')
        %------ a single folder
        [handlesDir] =  uigetdir('*.*',...
                                 'Select the folder that contains the handles');
    else
        handlesDir = 0;
    end
    else
        if ~isa('handles','char')
            STR = strcat('Input must be the name of the folder that contains',...
                         'the handles, please try again');
            disp(STR);
            F=[];
            return;
        end
    end
    
    %verify that the last character of the string is not a slash
    if (strcmp(handlesDir(end),'/'))||(strcmp(handlesDir(end),'\'))
        handlesDir=handlesDir(1:end-1);
    end
    
    %If the handles cannot be loaded, exit routine
    try
        % first try loading handlesJoined.mat, else load handles.mat
        try
            load (strcat(handlesDir,'/handlesJoined.mat'));
        catch
            load (strcat(handlesDir,'/handles.mat'));
        end
    catch
        STR = strcat('Handles could not be loaded, may be an incorrect folder ',...
                     'or it is not in the path. Please try again');
        disp(STR);
        F=[];
        return;
    end
    
    
    % The root directory for the handles is passed as a string, load the handles
    %
    
    if isfield(handles,'finalNetwork')
	    currentTrack = 1:size(...
                handles.finalNetwork(:,handles.distanceNetwork.numHops>0),2);
    else
	    disp(' Handles does not contain finalNetwork');
	    disp(' Please make sure that the tracking process was finalised');
	    F=[];
	    return;
    end
    if isfield(handles,'distanceNetwork')
	    numTracks = size(handles.distanceNetwork.avPerTrack,2);
    else
	    disp(' Handles does not contain distanceNetwork');
	    disp(' Please make sure that the tracking process was finalised');
	    F=[];
	    return;
    end
    if ~isfield(handles,'ChannelDistribution')   
	    disp(' Handles does not contain ChannelDistribution');
	    disp(' will process top half as Fluorescence bottom half as DIC');
	    handles.ChannelDistribution = [1 floor(handles.levs/2) ...
                                ceil(0.1+handles.levs/2) handles.levs 0 0 ]';
    end

    %There are several plotOptions (green, jet, etc.) default is green
    if (~exist('plotOption','var'))
	    plotOption = 2;
    elseif (plotOption>10)||(plotOption<1)
	    disp('PlotOption not valid, Please try again');
	    F=[];
	    return;
    end


    %the original data is in _mat_Re, verify that the other folders are
    %readable
    dataDirRe = (strcat(handlesDir(1:end-2),'Re'));
    dataDirLa = (strcat(handlesDir(1:end-2),'La'));

    if (~isdir(dataDirRe))||(~isdir(dataDirLa))
	    disp(' Could not locate the folders _mat_Re or _mat_La.');
	    disp(' Please make sure that both folders have the same path as the handles');
	    F=[];
	    return;
    end

    %Generate the dir where the data, Intensity or Labels, are located there is
    %no option to work with images, only with mat files
    original_dataDirLa = dir (strcat(dataDirLa,'/*.mat'));
    original_dataDirRe = dir (strcat(dataDirRe,'/*.mat'));

    if (isempty(original_dataDirRe))||(isempty(original_dataDirLa))
	    disp([' Could not locate *.mat files inside the __mat_Re ' ...
                  'or _mat_La folders']);
	    disp(' Please make sure that both folders contain the correct files');
	    F=[];
	    return;
    end

    %% Begin the processing
    clear XX YY ZZ counterF dataInCell dataR  qq* stats* button
    
    %Use figure(25) to display the movie
    try
        close(25)
    catch end

    figure(25)
    clf;
    set(gca,'position',[0 0 1 1 ]);axis off

    %Determine track colours according to the average velocity of tracks
    jet2=jet;
    colorID6 = interp1(jet2,linspace(1,64,numTracks));
    [m1,m2] = sort(handles.distanceNetwork.avPerTrack);
    %Define labels to be used
    uniqueLabels = (unique(handles.nodeNetwork(:,14)));
    numLabels = numel(uniqueLabels);

    nodesUsed = handles.finalNetwork(:,currentTrack);
    nodesUsedS = sort(nodesUsed(:));
    nodesUsedS(nodesUsedS==0) = [];
    initFrame = handles.nodeNetwork(nodesUsedS(1),5);
    stopFrame = handles.nodeNetwork(nodesUsedS(end),5);
    numTracks = size(currentTrack,2);

    % there is the possibility of plotting a subset of tracks, the default is to plot all
    if (~exist('tracksToPlot','var'))
	    tracksToPlot = 1:numTracks;
    end
    if isempty(tracksToPlot)
	    tracksToPlot = 1:numTracks;
    end

    % there is the possibility of plotting a subset of frames, the default is to plot all
    if exist('framesToPlot','var')
	    %framesToPlot should have two values [initFrameToPlot finFrameToPlot]
	    % stopFrame>initFrameToPlot>1
	    % stopFrame>finFrameToPlot>1
	    % finFrameToPlot>initFrameToPlot
	    if (min(framesToPlot)>stopFrame)||(max(framesToPlot)<initFrame)
	        disp(strcat('The data contains frames [',num2str(initFrame),...
                            ', ',num2str(stopFrame),'. '));
	        disp(' Please verify values');
	        F=[];
	        return;
	    end
	    initFrame = max(initFrame, min(framesToPlot));
	    stopFrame = min(stopFrame, max(framesToPlot));
	
    end


    %% Determine the appropriate plotOption
    % 1 Object intensity in green / red
    % 2 Object intensity in green / red plus a slice of DIC
    % 3 Object intensity in JET2
    % 4 Object intensity in JET2 plus a slice of DIC
    % 5 Object Labels in JET2
    % 6 Object Labels in JET2 plus a slice of DIC
    % 7 Object intensity in green plus a slice of DIC WITHOUT TRACKS

    % options 2,4,6 are only possible if there is DIC on top of the
    % fluorescence

    if (handles.ChannelDistribution(3)==0)
	    switch plotOption
	        case 1
	            plotOption =1;
	        case 2
	            plotOption =1;
	        case 3
	            plotOption =3;
	        case 4
	            plotOption =3;
	        case 5
	            plotOption =5;
	        case 6
	            plotOption =5;
	        case 7
	            plotOption =7;
                
	    end
    end



    if handles.ChannelDistribution(1)~=0
	    gFluorescentSlices = handles.ChannelDistribution(1):...
                handles.ChannelDistribution(2);
    else
	    gFluorescentSlices = 0;
    end
    if handles.ChannelDistribution(5)~=0
	    rFluorescentSlices = handles.ChannelDistribution(5):...
                handles.ChannelDistribution(6);
    else
	    rFluorescentSlices = 0;
    end


    % FILE WITH the objects and the DIC
    currentData = load(strcat(dataDirRe,'/',original_dataDirRe(1).name));
    [rows,cols,levs] = size (currentData.dataR);
    % This is to plot the   objects LABELS only!
    currentDataL = load(strcat(dataDirLa,'/',original_dataDirLa(1).name));

    switch plotOption
	    case 1
	        % The objects to display are the maximum intensity projection
	        currFish = zeros (rows,cols,3);
	        if (gFluorescentSlices(1)~=0)
	            currNeutrops = (max(...
                        currentData.dataR(:,:,gFluorescentSlices),[],3));
	            % To display them as an image, they are scaled 0-150
	            currNeutrops =(currNeutrops/max(currNeutrops(:)));
	            currFish(:,:,2) = round(255*currNeutrops);
	        end
	        if (rFluorescentSlices(1)~=0)
	            currNeutrops = (max(...
                        currentData.dataR(:,:,rFluorescentSlices),[],3));
	            % To display them as an image, they are scaled 0-150
	            currNeutrops = (currNeutrops/max(currNeutrops(:)));
	            currFish(:,:,1) = round(255*currNeutrops);
	        end
	        hSurf = imagesc(currFish/255);

	    case 2
	        levelP=150;
	        
	        topSlice = max(...
                    currentData.dataR(:,:,handles.ChannelDistribution(3)),[],3);
	        currFish0 = repmat(255*topSlice/(max(topSlice(:))),[1 1 3]);

	        % To display them as an image, they are scaled 0-150
	        if (gFluorescentSlices(1)~=0)
	            currNeutrops = (max(...
                        currentData.dataR(:,:,gFluorescentSlices),[],3));
	            % To display them as an image, they are scaled 0-150
	            currNeutrops = (currNeutrops/max(currNeutrops(:)));
	            currFish0(:,:,2) = currFish0(:,:,2)+round(255*currNeutrops);
	        end
	        if (rFluorescentSlices(1)~=0)
	            currNeutrops = (max(...
                        currentData.dataR(:,:,rFluorescentSlices),[],3));
	            % To display them as an image, they are scaled 0-150
	            currNeutrops = (currNeutrops/max(currNeutrops(:)));
	            currFish0(:,:,1) = currFish0(:,:,1)+round(255*currNeutrops);
	        end
	        
	        currFish = currFish0-min(currFish0(:));
	        currFish = round(255*currFish/max(currFish(:)));
	        hSurf = imagesc(currFish/255);

	    case 3
	        levelP = 64;

	        % The objects to display are the maximum intensity projection
	        if(gFluorescentSlices(1)~=0)&&(rFluorescentSlices(1)~=0)
	            currNeutrops = (max(...
                        currentData.dataR(:,:,[gFluorescentSlices ...
                                        rFluorescentSlices]),[],3));
                    
	        elseif (gFluorescentSlices(1)~=0)&&(rFluorescentSlices(1)==0)
	            currNeutrops = (max(...
                        currentData.dataR(:,:,[gFluorescentSlices]),[],3));
	        elseif (gFluorescentSlices(1)==0)&&(rFluorescentSlices(1)~=0)
	             currNeutrops = (max(...
                         currentData.dataR(:,:,[rFluorescentSlices]),[],3));
	        end
	        currNeutrops = (currNeutrops/max(currNeutrops(:)));
	        % To display them as an image, they are scaled 0-64
	        currNeutrops = round(255*(currNeutrops/max(currNeutrops(:))));
	        currFish = currNeutrops;
	        hSurf = imagesc(currFish/255);
	        jet2=jet;
	        jet2(1:3,:)=0;
	        colormap(jet2)        
	    case 4
	        levelP = 64;

	        topSlice = max(...
                    currentData.dataR(:,:,handles.ChannelDistribution(3)),[],3);
	        
	        % The objects to display are the maximum intensity projection
	        if(gFluorescentSlices(1)~=0)&&(rFluorescentSlices(1)~=0)
	            currNeutrops = (max(...
                        currentData.dataR(:,:,[gFluorescentSlices ...
                                        rFluorescentSlices]),[],3));
	        elseif (gFluorescentSlices(1)~=0)&&(rFluorescentSlices(1)==0)
	            currNeutrops = (max(...
                        currentData.dataR(:,:,gFluorescentSlices),[],3));
	        elseif (gFluorescentSlices(1)==0)&&(rFluorescentSlices(1)~=0)
	             currNeutrops = (max(...
                         currentData.dataR(:,:,rFluorescentSlices),[],3));
	        end
	        % To display them as an image, they are scaled 0-64
	        currNeutrops = round(levelP*(currNeutrops/max(currNeutrops(:))));
	        
	        currNeutropsJ = zeros(rows,cols,3);
	        jet2=jet;
	        jet2(1:3,:) = 0;
	        for k=1:64
	            currNeutropsJ(:,:,1) = currNeutropsJ(:,:,1)+...
                        jet2(k,1)*(currNeutrops==k);
	            currNeutropsJ(:,:,2) = currNeutropsJ(:,:,2)+...
                        jet2(k,2)*(currNeutrops==k);
	            currNeutropsJ(:,:,3) = currNeutropsJ(:,:,3)+...
                        jet2(k,3)*(currNeutrops==k);
	        end
	        currFish0 = repmat(255*topSlice/(max(topSlice(:))),[1 1 3]);
	        currFish = 255*currNeutropsJ+currFish0;
	        currFish(currFish>255) = 255;
	        currFish(currFish<0) = 0;
	        hSurf = imagesc(currFish/255);
	        
	    case 5
	        
	        % The objects to display are the maximum intensity projection
	        currNeutrops = (max(currentDataL.dataL,[],3));
	        % To display them as an image, they are scaled 0-150
	        currNeutrops =round(255*(currNeutrops/max(currNeutrops(:))));
	       
	        jet4 = jet;
	        jet4(1,:) = [ 0 0 0];
	        currFish = currNeutrops;
	        
	        hSurf = imagesc(currFish/255);

	        colormap(jet4)
	        
	    case 6
	        
	        levelP = 64;
	        % The objects to display are the maximum intensity projection
	        currNeutrops = (max(currentDataL.dataL,[],3));
	        % To display them as an image, they are scaled 0-150
	        currNeutrops = round(levelP*(currNeutrops/max(currNeutrops(:))));
	        
	        jet3 = jet;
	        [qqqq1,qqqq2] = sort(rand(64,1));
	        jet3 = (jet3(qqqq2,:)).^(1.0);
	        jet3(1,:) = [ 0 0 0];
	        currNeutropsJ = zeros(rows,cols,3);
	        for k=1:64
	            currNeutropsJ(:,:,1) = currNeutropsJ(:,:,1)+...
                        jet3(k,1)*(currNeutrops==k);
	            currNeutropsJ(:,:,2) = currNeutropsJ(:,:,2)+...
                        jet3(k,2)*(currNeutrops==k);
	            currNeutropsJ(:,:,3) = currNeutropsJ(:,:,3)+...
                        jet3(k,3)*(currNeutrops==k);
	        end
	        
	        topSlice = currentData.dataR(:,:,handles.ChannelDistribution(3));
	        currFish0 = repmat(255*topSlice/(max(topSlice(:))),[1 1 3]);
	        currFish = currFish0.*(currNeutropsJ==0)+255*currNeutropsJ;
	        
	        hSurf = imagesc(currFish/255);
	        
	    case 7
	        
	        % This is to plot the objects only plus a slice without DIC 
	        
	        % The objects to display are the maximum intensity projection
	            currFish0 = zeros(rows,cols,3);
	        
	        
	        % To display them as an image, they are scaled 0-150
	        if(gFluorescentSlices(1)~=0)
	            currNeutrops = (max(...
                        currentData.dataR(:,:,gFluorescentSlices),[],3));
	            % To display them as an image, they are scaled 0-150
	            currNeutrops = (currNeutrops/max(currNeutrops(:)));
	            currFish0(:,:,2) = currFish0(:,:,2)+round(255*currNeutrops);
	        end
	        if (rFluorescentSlices(1)~=0)
	            currNeutrops = (max(...
                        currentData.dataR(:,:,rFluorescentSlices),[],3));
	            % To display them as an image, they are scaled 0-150
	            currNeutrops = (currNeutrops/max(currNeutrops(:)));
	            currFish0(:,:,1) = currFish0(:,:,1)+round(255*currNeutrops);
	        end
	        
	        currFish = currFish0-min(currFish0(:));
	        currFish = round(255*currFish/max(currFish(:)));
	        hSurf = imagesc(currFish/255);        

	    case 8
	        
	      % This is to plot the objects only plus a slice of DIC if available
	        
	        levelP = 150;
	        
	        if handles.ChannelDistribution(3)~=0
	            topGreySlice = handles.ChannelDistribution(3); 
	            topSlice = max(currentData.dataR(:,:,topGreySlice),[],3);
	            currFish0 = repmat(255*topSlice/(max(topSlice(:))),[1 1 3]);
	        else
	            currFish0 = zeros(rows,cols,3);
	        end
	        
	        
	        % To display them as an image, they are scaled 0-150
	        if (gFluorescentSlices(1)~=0)
	            currNeutrops = (max(...
                        currentData.dataR(:,:,gFluorescentSlices),[],3));
	            % To display them as an image, they are scaled 0-150
	            currNeutrops = (currNeutrops/max(currNeutrops(:)));
	            currFish0(:,:,2) = currFish0(:,:,2)+round(255*currNeutrops);
	        end
	        if (rFluorescentSlices(1)~=0)
	            currNeutrops = (max(...
                        currentData.dataR(:,:,rFluorescentSlices),[],3));
	            % To display them as an image, they are scaled 0-150
	            currNeutrops = (currNeutrops/max(currNeutrops(:)));
	            currFish0(:,:,1) = currFish0(:,:,1)+round(255*currNeutrops);
	        end
	        
	        currFish = currFish0-min(currFish0(:));
	        currFish = round(255*currFish/max(currFish(:)));
	        hSurf = imagesc(currFish/255);        


        case 9
	        % The objects to display are the maximum intensity projection
	        currFish = zeros (rows,cols,3);
	        if (gFluorescentSlices(1)~=0)
	            currNeutrops = (max(...
                        currentData.dataR(:,:,gFluorescentSlices),[],3));
	            % To display them as an image, they are scaled 0-150
	            currNeutrops = (currNeutrops/max(currNeutrops(:)));
	            currFish(:,:,2) = round(255*currNeutrops);
	        end
	        if (rFluorescentSlices(1)~=0)
	            currNeutrops = (max(...
                        currentData.dataR(:,:,rFluorescentSlices),[],3));
	            % To display them as an image, they are scaled 0-150
	            currNeutrops = (currNeutrops/max(currNeutrops(:)));
	            currFish(:,:,1) = round(255*currNeutrops);
	        end
	        hSurf = imagesc(currFish/255);

	    case 10
	        levelP = 150;
	        
	        topSlice = max(...
                    currentData.dataR(:,:,handles.ChannelDistribution(3)),[],3);
	        currFish0 = repmat(255*topSlice/(max(topSlice(:))),[1 1 3]);

	        % To display them as an image, they are scaled 0-150
	        if (gFluorescentSlices(1)~=0)
	            currNeutrops = (max(...
                        currentData.dataR(:,:,gFluorescentSlices),[],3));
	            % To display them as an image, they are scaled 0-150
	            currNeutrops = (currNeutrops/max(currNeutrops(:)));
	            currFish0(:,:,2) = currFish0(:,:,2)+round(255*currNeutrops);
	        end
	        if (rFluorescentSlices(1)~=0)
	            currNeutrops = (max(...
                        currentData.dataR(:,:,rFluorescentSlices),[],3));
	            % To display them as an image, they are scaled 0-150
	            currNeutrops = (currNeutrops/max(currNeutrops(:)));
	            currFish0(:,:,1) = currFish0(:,:,1)+round(255*currNeutrops);
	        end

	        currFish = currFish0-min(currFish0(:));
	        currFish = round(255*currFish/max(currFish(:)));
	        hSurf = imagesc(currFish/255);
    end 

    %%
    hold on;

    for counterTrack=tracksToPlot
	    currTrack = currentTrack(counterTrack);
	    plottingPoints = handles.finalNetwork(:,currTrack);
	    plottingPoints(plottingPoints==0) = [];
	    XX{counterTrack} = handles.nodeNetwork(plottingPoints,1);
	    YY{counterTrack} = handles.nodeNetwork(plottingPoints,2);
	    trackFrames{counterTrack} = handles.nodeNetwork(plottingPoints,5);
	    %--This line plots the lines with colour proportional to the speed of the track
	    hLine(counterTrack) = line(YY{counterTrack},XX{counterTrack},'color',...
                                       colorID6(find(m2==counterTrack),:),'marker',...
                                       'x','markersize',1,'visible','on');
        initTracks(counterTrack) = handles.nodeNetwork(...
            handles.finalNetwork(1,counterTrack),5);
        finTracks(counterTrack) = handles.nodeNetwork(...
            handles.finalNetwork(handles.distanceNetwork.numHops(...
                counterTrack),counterTrack),5);
    end
    %%

    F(stopFrame-initFrame+1) = getframe;
    movieData{stopFrame-initFrame+1}(rows,cols,3) = 0;
    for counterF=initFrame:stopFrame
	    if plotOption < 7
	        for counterTrack=tracksToPlot
                %check that the track has not finished (keep linked tracks)
                if ((initTracks(counterTrack)<=counterF) &...
                    (finTracks(counterTrack)>=counterF ))
                    set(hLine(counterTrack),'visible','on');
                else
                    set(hLine(counterTrack),'visible','off');
                end
%                 %check that the track is present in the current frame (i.e. remove
%                 %if there was a manual link)
% 	            [nodeInFrame,locNode]=ismember(counterF,trackFrames{counterTrack});
% 	            if sum(nodeInFrame>0)
% 	                set(hLine(counterTrack),'visible','on');
% 	            else
% 	                set(hLine(counterTrack),'visible','off');
%                 end
            end
        elseif plotOption>8
            %minFrame = max(initFrame,counterF-10);
            %maxFrame = min(stopFrame,counterF+10);
            for counterTrack=tracksToPlot
                %minFrame = max(initFrame,trackFrames{counterTrack}(counterF)-10);
                %maxFrame = min(stopFrame,trackFrames{counterTrack}(counterF)+10);
                currentTrackFrames = trackFrames{counterTrack};
                
                %pivotFrame = find(currentTrackFrames<counterF,1,'last');
                % in order to have shorter tracks, determine 20 points before and 20 points after the current position and only display those
                minFrame1 = find(currentTrackFrames<(counterF-20),1,'last');
                maxFrame1 = find(currentTrackFrames<(counterF+20),1,'last');
                %if isempty(minFrame1); minFrame1=initFrame; end
                %if isempty(maxFrame1); maxFrame1=stopFrame; end
                % When the option is empty, it means that the track is not
                % present within the range of plots, it should not be
                % displayed.
                if isempty(minFrame1); minFrame1=counterF; end
                if isempty(maxFrame1); maxFrame1=counterF; end
                
                minFrame = max(initFrame,minFrame1);
                maxFrame = min(stopFrame,maxFrame1);
               
                %currentTrackFrames(currentTrackFrames<minFrame) =[];
                %currentTrackFrames(currentTrackFrames>maxFrame) =[];
                %framesOfTrackToPlot = (currentTrackFrames);
                framesOfTrackToPlot = (minFrame:maxFrame);
                if maxFrame>minFrame
                    try
                        set(hLine(counterTrack),'Xdata',...
                            YY{counterTrack}(framesOfTrackToPlot),'Ydata',...
                            XX{counterTrack}(framesOfTrackToPlot),'visible','on');
                    catch
                        tttt=1;
                    end
                else
                    set(hLine(counterTrack),'visible','off')
                end
%                 if counterF==22
%                     qq=1;
%                 end
            end
            
        else
	        for counterTrack=tracksToPlot        
	            set(hLine(counterTrack),'visible','off');
	        end
	        
	    end
	
	    currentData = load(strcat(dataDirRe,'/',original_dataDirRe(counterF).name));
	    currentDataL = load(strcat(dataDirLa,'/',original_dataDirLa(counterF).name));
	    switch plotOption
	        case 1
	            currFish = zeros (rows,cols,3);
	            if (gFluorescentSlices(1)~=0)
	                currNeutrops = (max(currentData.dataR(:,:,gFluorescentSlices),[],3));
	                % To display them as an image, they are scaled 0-150
	                currNeutrops = (currNeutrops/max(currNeutrops(:)));
	                currFish(:,:,2) = round(255*currNeutrops);
	            end
	            if (rFluorescentSlices(1)~=0)
	                currNeutrops = (max(currentData.dataR(:,:,rFluorescentSlices),[],3));
	                % To display them as an image, they are scaled 0-150
	                currNeutrops = (currNeutrops/max(currNeutrops(:)));
	                currFish(:,:,1) = round(255*currNeutrops);
	            end
	            
	        case 2
	            topSlice = max(currentData.dataR(:,:,handles.ChannelDistribution(3)),...
                                   [],3);
	            currFish0 = repmat(255*topSlice/(max(topSlice(:))),[1 1 3]);
	            
	            % To display them as an image, they are scaled 0-150
	            if (gFluorescentSlices(1)~=0)
	                currNeutrops = (max(currentData.dataR(:,:,gFluorescentSlices),[],3));
	                % To display them as an image, they are scaled 0-150
	                currNeutrops = (currNeutrops/max(currNeutrops(:)));
	                currFish0(:,:,2) = currFish0(:,:,2)+round(255*currNeutrops);
	            end
	            if (rFluorescentSlices(1)~=0)
	                currNeutrops = (max(currentData.dataR(:,:,rFluorescentSlices),[],3));
	                % To display them as an image, they are scaled 0-150
	                currNeutrops = (currNeutrops/max(currNeutrops(:)));
	                currFish0(:,:,1) = currFish0(:,:,1)+round(255*currNeutrops);
	            end
	            
	            currFish = currFish0-min(currFish0(:));
	            currFish = round(255*currFish/max(currFish(:)));
	        case 3
	            
	            % The objects to display are the maximum intensity projection
	            if(gFluorescentSlices(1)~=0)&&(rFluorescentSlices(1)~=0)
	                currNeutrops = (max(...
                            currentData.dataR(:,:,...
                                              [gFluorescentSlices rFluorescentSlices]),[],3));
	            elseif (gFluorescentSlices(1)~=0)&&(rFluorescentSlices(1)==0)
	                currNeutrops = (max(...
                            currentData.dataR(:,:,[gFluorescentSlices]),[],3));
	            elseif (gFluorescentSlices(1)==0)&&(rFluorescentSlices(1)~=0)
	                currNeutrops = (max(...
                            currentData.dataR(:,:,[rFluorescentSlices]),[],3));
	            end
	            
	            % To display them as an image, they are scaled 0-64
	            currNeutrops = round(255*(currNeutrops/max(currNeutrops(:))));
	            currFish = currNeutrops;
	        case 4
	            topSlice = max(...
                        currentData.dataR(:,:,handles.ChannelDistribution(3)),[],3);
	            % The objects to display are the maximum intensity projection
	            if(gFluorescentSlices(1)~=0)&&(rFluorescentSlices(1)~=0)
	                currNeutrops = (max(...
                            currentData.dataR(:,:,...
                                              [gFluorescentSlices rFluorescentSlices]),[],3));
	            elseif (gFluorescentSlices(1)~=0)&&(rFluorescentSlices(1)==0)
	                currNeutrops = (max(currentData.dataR(:,:,gFluorescentSlices),[],3));
	            elseif (gFluorescentSlices(1)==0)&&(rFluorescentSlices(1)~=0)
	                currNeutrops = (max(currentData.dataR(:,:,rFluorescentSlices),[],3));
	            end
	            
	            % To display them as an image, they are scaled 0-64
	            currNeutrops = round(levelP*(currNeutrops/max(currNeutrops(:))));
	            currNeutropsJ = zeros(rows,cols,3);
	            for k=1:64
	                currNeutropsJ(:,:,1) = currNeutropsJ(:,:,1)+...
                            jet2(k,1)*(currNeutrops==k);
	                currNeutropsJ(:,:,2) = currNeutropsJ(:,:,2)+...
                            jet2(k,2)*(currNeutrops==k);
	                currNeutropsJ(:,:,3) = currNeutropsJ(:,:,3)+...
                            jet2(k,3)*(currNeutrops==k);
	            end
	            currFish0 = repmat(255*topSlice/(max(topSlice(:))),[1 1 3]);
	            currFish = 255*currNeutropsJ+currFish0;
	            currFish(currFish>255) = 255;
	            currFish(currFish<0) = 0;
	        case 5
	            % This is to plot the objects LABELS only!
	            % The objects to display are the maximum intensity projection
	            currNeutrops = (max(currentDataL.dataL,[],3));
	            currNeutrops2 = zeros(size(currNeutrops));
	            localLabelCode = handles.nodeNetwork(...
                        handles.nodeNetwork(:,5)==counterF,[11 14]);
	            for counterLocalLabel=1:size(localLabelCode,1)
	                currNeutrops2(currNeutrops==localLabelCode(counterLocalLabel,1)) = ...
                            localLabelCode(counterLocalLabel,2);
	            end
	                       
	            % To display them as an image, they are scaled 0-150
	            currNeutrops2 = round(255*(currNeutrops2/max(currNeutrops2(:))));
	            currFish = currNeutrops2;
	            
	        case 6
	            % This is to plot the grayscale fish with  objects LABELS
	            % The objects to display are the maximum intensity projection
	            currNeutrops = (max(currentDataL.dataL,[],3));
	            % To display them as an image, they are scaled 0-150
	            %currNeutrops = round(levelP*(currNeutrops/max(currNeutrops(:))));
	            currNeutrops2 = zeros(size(currNeutrops));
	            localLabelCode = handles.nodeNetwork(...
                        handles.nodeNetwork(:,5)==counterF,[11 14]);
	            for counterLocalLabel=1:size(localLabelCode,1)
	                currNeutrops2(currNeutrops==localLabelCode(counterLocalLabel,1)) =...
                            localLabelCode(counterLocalLabel,2);
	            end
	            
	            % To display them as an image, they are scaled 0-150
	            currNeutrops3 = round(64*(currNeutrops2/max(currNeutrops2(:))));
	            
	            currNeutropsJ = zeros(rows,cols,3);
	            for k=1:64
	                currNeutropsJ(:,:,1) = currNeutropsJ(:,:,1)+...
                            jet3(k,1)*(currNeutrops3==k);
	                currNeutropsJ(:,:,2) = currNeutropsJ(:,:,2)+...
                            jet3(k,2)*(currNeutrops3==k);
	                currNeutropsJ(:,:,3) = currNeutropsJ(:,:,3)+...
                            jet3(k,3)*(currNeutrops3==k);
	            end
	            topSlice = currentData.dataR(:,:,handles.ChannelDistribution(3));
	            currFish0 = repmat(255*(topSlice.*(currNeutrops3==0))/...
                                       (max(topSlice(:))),[1 1 3]);
	            currFish = currFish0+255*currNeutropsJ;
	        case 7	            
	            currFish0 = zeros(rows,cols,3);
	            
	            if (gFluorescentSlices(1)~=0)
	                currNeutrops = (max(...
                            currentData.dataR(:,:,gFluorescentSlices),[],3));
	                % To display them as an image, they are scaled 0-150
	                currNeutrops = (currNeutrops/max(currNeutrops(:)));
	                currFish0(:,:,2) = currFish0(:,:,2)+round(255*currNeutrops);
	            end
	            if (rFluorescentSlices(1)~=0)
	                currNeutrops = (max(...
                            currentData.dataR(:,:,rFluorescentSlices),[],3));
	                % To display them as an image, they are scaled 0-150
	                currNeutrops = (currNeutrops/max(currNeutrops(:)));
	                currFish0(:,:,1) = currFish0(:,:,1)+round(255*currNeutrops);
	            end
	            % To display them as an image, they are scaled 0-150
	            %currNeutrops = levelP*(currNeutrops/max(currNeutrops(:)));
	            currFish = currFish0-min(currFish0(:));
	            currFish = round(255*currFish/max(currFish(:)));      
	        case 8
	            
	            if handles.ChannelDistribution(3)~=0
	                topGreySlice = handles.ChannelDistribution(3);
	                topSlice = max(...
                            currentData.dataR(:,:,handles.ChannelDistribution(3)),...
                            [],3);
	                currFish0 = repmat(255*topSlice/(max(topSlice(:))),[1 1 3]);
	            else
	                currFish0 = zeros(rows,cols,3);
	            end
	            
	            if (gFluorescentSlices(1)~=0)
	                currNeutrops = (max(...
                            currentData.dataR(:,:,gFluorescentSlices),[],3));
	                % To display them as an image, they are scaled 0-150
	                currNeutrops = (currNeutrops/max(currNeutrops(:)));
	                currFish0(:,:,2) = currFish0(:,:,2)+round(255*currNeutrops);
	            end
	            if (rFluorescentSlices(1)~=0)
	                currNeutrops = (max(...
                            currentData.dataR(:,:,rFluorescentSlices),[],3));
	                % To display them as an image, they are scaled 0-150
	                currNeutrops = (currNeutrops/max(currNeutrops(:)));
	                currFish0(:,:,1) = currFish0(:,:,1)+round(255*currNeutrops);
	            end
	            

	            % To display them as an image, they are scaled 0-150
	            %currNeutrops = levelP*(currNeutrops/max(currNeutrops(:)));
	            currFish = currFish0-min(currFish0(:));
	            currFish = round(255*currFish/max(currFish(:)));      
	        case 9
	            currFish = zeros (rows,cols,3);
	            if (gFluorescentSlices(1)~=0)
	                currNeutrops = (max(...
                            currentData.dataR(:,:,gFluorescentSlices),[],3));
	                % To display them as an image, they are scaled 0-150
	                currNeutrops = (currNeutrops/max(currNeutrops(:)));
	                currFish(:,:,2) = round(255*currNeutrops);
	            end
	            if (rFluorescentSlices(1)~=0)
	                currNeutrops = (max(...
                            currentData.dataR(:,:,rFluorescentSlices),[],3));
	                % To display them as an image, they are scaled 0-150
	                currNeutrops = (currNeutrops/max(currNeutrops(:)));
	                currFish(:,:,1) = round(255*currNeutrops);
                end
              case 10                
                topSlice = max(...
                    currentData.dataR(:,:,handles.ChannelDistribution(3)),[],3);
                currFish0 = repmat(255*topSlice/(max(topSlice(:))),[1 1 3]);
                
                % To display them as an image, they are scaled 0-150
                if (gFluorescentSlices(1)~=0)
                    currNeutrops = (max(...
                        currentData.dataR(:,:,gFluorescentSlices),[],3));
                    % To display them as an image, they are scaled 0-150
                    currNeutrops = (currNeutrops/max(currNeutrops(:)));
                    currFish0(:,:,2) = currFish0(:,:,2)+round(255*currNeutrops);
                end
                if (rFluorescentSlices(1)~=0)
                    currNeutrops = (max(...
                        currentData.dataR(:,:,rFluorescentSlices),[],3));
                    % To display them as an image, they are scaled 0-150
                    currNeutrops = (currNeutrops/max(currNeutrops(:)));
                    currFish0(:,:,1) = currFish0(:,:,1)+round(255*currNeutrops);
                end
                currFish = currFish0-min(currFish0(:));
                currFish = round(255*currFish/max(currFish(:)));      	            
	            
	    end
	
	    set(hSurf,'CData',currFish/255);
	
	    axis image
	    axis off
	    drawnow;
	    F(counterF+1-initFrame) = getframe;
	
	    movieData{counterF+1-initFrame} = currFish;
	
    end

    %% Save the movie as AVI no compression
    mkdir(strcat(handlesDir(1:end-2),'VI'))
    movie2avi(F,strcat(handlesDir(1:end-2),'VI/video_1.avi'),'compression','none')

    %% save the movie as a GIF
    % the option 'nodither' produces better results for fluorescent cases,
    % but for options with DIC or light cases, there are some ring
    % artifacts, for those cases is better to remove it.
    [imGif,mapGif] = rgb2ind(F(1).cdata,256,'nodither'); 
    numFrames = size(F,2);

    imGif(1,1,1,numFrames) = 0;
    for k = 2:numFrames 
      imGif(:,:,1,k) = rgb2ind(F(k).cdata,mapGif,'nodither');
    end
    %%

    imwrite(imGif,mapGif,strcat(handlesDir(1:end-2),'VI/video_2.gif'),...
            'DelayTime',0,'LoopCount',inf) %g443800

   % movieFrames=F;
   % save(strcat(handlesDir(1:end-2),'VI/video_elements.mat'),'handles',...
   % 'movieFrames','movieData')