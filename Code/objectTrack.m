function [handles]= objectTrack(pathname)
%function [handles]= objectTrack()
%function [handles]= objectTrack(pathname)
%
%--------------------------------------------------------------------------
%  objectTrack is the opening file for the whole tracking package. It can do the
%  pre-processing of the data if necessary and leave in a format that can then be
%  analysed with trackingAnalysis.
%  Options of pre-processing:
%       1) remove shading
%       2) transform from an RGB image to a fluorescent-like image by subtracting the
%          average intensity projection along time
%       3) Mask regions to be removed from the analysis
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
% This m-file is part of the objectTrack package used to analyse small objects
% as observed through confocal or multiphoton microscopes.  For a comprehensive 
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


%% Start the reading process

close all;

%% Determine the pathname
if ~exist('pathname','var')
    button                                      = questdlg('Please specify the location of Folder with the data to track','Select Input','Select Folder','Cancel','Cancel');
    if strcmp(button(1),'C')
        % no data to read, exit
        handles=[];return;
    else
        %-----  Input should be a  Folder with Tiff files (2D/3D)    (S)
        %-----  In the future consider reading a Single AVI file
        
        % read the path to the folder with the data
        % pass the pathname to same function to process
        if strcmp(button(1),'S')
            [pathname]                          =  uigetdir('*.*','Please select folder where the images/data are located');
            if pathname==  0
                % no data to read, exit
                handles=[];return;
            end
        end
    end
else
    if ~isdir(pathname)
        disp('Folder not found');
        handles=[];return;
    end
end

%% Pathname is a valid path to a dir
% If data has been already preprocessed (i.e. pathname has extension _mat_ skip this
% section and call directly trackingAnalysis

% Ensure the last character of the pathname is a "/"
if pathname(end)~=filesep
    pathname                = strcat(pathname,filesep);
end

if isempty(strfind(pathname,'_mat_'))
    pathname2               = strcat(pathname(1:end-1),'_mat_Or');
    % The data has not been previously processed. Open options to pre-process:
    
    dir1                   = dir(pathname);
    % Remove all the files that start with dot (hidden files)
    dir1                    = dir1(arrayfun(@(x) ~strcmp(x.name(1),'.'),dir1));
    
    %read first image and display
    dataIn                  = (imread((strcat(pathname,dir1(1).name))));
    if size(dataIn,3)>3     dataIn(:,:,4)=[]; end
    
    % select an area of interest
%    userROI                 = ones(size(dataIn));
%    imagesc(dataIn.*(uint8(userROI)))
    selectROI               = 'y';
    while (strcmp(selectROI,'y'))||(strcmp(selectROI,'Y'))
 
        selectROI               = input ('Do you want to select a Region of Interest? Y/N [n]: ','s');

        if (strcmp(selectROI,'y'))||(strcmp(selectROI,'Y'))
            imagesc(dataIn)
            userROI             = roipoly();
            imagesc(dataIn.*(repmat(uint8(userROI),[1 1 3])))
        end
    end
    
    selectPreProc               = input ('Do you want to pre-process colour images for moving objects (produce fluorescent-like data)? Y/N [n]: ','s');
    if (strcmp(selectPreProc,'y'))||(strcmp(selectPreProc,'Y'))
        readPreProcess(pathname);
    end
else
    pathname2 = pathname;
end


%% Call trackingAnalysis, with no reduction, and pre-defined channels, the levels and size needs to be determined by the user

[handles]   = trackingAnalysis(pathname2,0,[1 1 2 2 0 0]);

%% Post-processing join tracks
disp('Joining Tracks')
handles     = joinMultipleTracks(handles,[]);              % run the first joining of tracks
handles     = joinMultipleTracks(handles,[]);              % join a second time
handles     = joinMultipleTracks(handles,[],[],30);         % join indicating a the distance from which to link
%% remove small tracks that have not been linked so far
% The minimum size of the  tracks is determined by the number of frames or 30,
% whichever is smaller
handles     = deleteMultipleTracks(handles,[],min(30,ceil(handles.numFrames/10)));
% join last time allowing to chose between two children if they are separate from
% each other
try
    handles     = joinMultipleTracks(handles,[],[],[],30);
catch
    q=1;
end
%%

if (~exist('woundRegion','var'))|(isempty(woundRegion))
    woundRegion = zeros(handles.rows,handles.cols);
    woundRegion (:,ceil(handles.cols/4):handles.cols) = 1;
end
%


handles                                                             = effectiveTracks(handles,woundRegion);
handles                                                             = effectiveDistance(handles,woundRegion);
%%
if strcmp(pathname(end),filesep)
    pathname3 = strcat(pathname(1:end-1),'_mat_Ha/handlesJoined.mat');
else
    pathname3 = strcat(pathname(1:end),'_mat_Ha/handlesJoined.mat');
end
save(pathname3,'handles');
end

%%
function  readPreProcess(dir0)
%%
% if dir0(end)~=filesep
%     dir0 = strcat(dir0,filesep);
% end
%dir0                                = '10min/';
%dir0                                = '190min/';
%dir0                                = 'avoid/';
dir1                                = dir(strcat(dir0,'*.tif'));
numImages                           = size(dir1,1);

% Data will be read from tifs and saved as matlab in a new folder, test and create if
% necessary
dir2                                = strcat(dir0(1:end-1),'_mat_Or/');
if ~isdir(dir2)
    mkdir(dir2)
end
% consider that the files may be TIF, TIFF, tiff



%%
% First create a mean image to subtract to background
dataIn                              = double(imread((strcat(dir0,dir1(1).name))));
dataIn_mean                         = zeros (size(dataIn));
if numImages>1000
    step = 4;
elseif numImages>100
    step = 2;
else
    step = 1;
end
for k1 = 1:step:numImages
    filename                        = dir1(k1).name;
    %filename2   = strcat(dir2,filename(12:14));
    disp(filename)
    
    dataIn                          = double(imread(strcat(dir0,filename)));
    dataIn_mean                     = dataIn_mean+step*dataIn/numImages;
    %save(filename2,'dataIn');
end

disp('Pre-process tiff files and save as Matlab')
%save (strcat(dir0(1:end-1),'_mean'),'dataIn_mean')
%clear dataIn*
%% Next, remove background from current image, remove negatives and save as _mat_Or
% if ~exist('dataIn_mean','var')
%     load (strcat(dir0(1:end-1),'_mean'));
% end

%%


kernel = strel('disk',4);
filtG = gaussF(5,5,1);


%The data to be stored will have in the first level the pre-processed objects and on
%the second level the original image, only one as it is considered to be grayscale
for k1 = 1:numImages
    filename                        = dir1(k1).name;
    % filename2 is a T followed by the unique ID with zeros the zeros depend on the
    % current number k1:
    %    0-9     T00009
    %   10-99    T00099
    %  100-999   T00999
    % 1000-9999  T09999
    switch (floor(log10(k1)))
        case 0
            NameTag = 'T0000';
        case 1
            NameTag = 'T000';
        case 2
            NameTag = 'T00';
        case 3
            NameTag = 'T0';
    end
    filename2                       = strcat(dir2,NameTag,num2str(k1));
    %filename2                       = strcat(dir2,'T00',filename(7:9));
    %filename2                       = strcat(dir2,'T0',filename(8:11));
    disp(filename)
    dataIn2                         = double(imread(strcat(dir0,filename)));
    dataIn_mean1                    = dataIn_mean(:,:,1);
    dataIn                          = dataIn_mean1 - dataIn2(:,:,1);
    dataIn(dataIn<0)                = 0;
    %dataIn (610:655,890:940)       = 0; %Remove a bubble artefact in 10min
    %dataIn (204:224,36:55)         = 0; %Remove a bubble artefact in 190min
    
    max_dataInMean                  = max(dataIn_mean1(:));
    
    % Close the regions to fill in the objects when they cross a bubble
    dataIn3                         = (max_dataInMean- dataIn_mean(:,:,1)).*imclose(dataIn(:,:,1)>25,kernel);
    
    % Remove faint sections
    dataIn3 (dataIn3<(70) )         = 0;
    
    % smoothe the data
    dataIn4                         = max(dataIn,imfilter(dataIn3,filtG)/2);
    
    % prepare the data and save in the corresponding folder
    dataIn                          = dataIn4;
    dataIn(:,:,2)                   = dataIn2(:,:,1);
    save(filename2,'dataIn');
    
end

end
%%

%imagesc(max(dataIn,dataIn4/2))


