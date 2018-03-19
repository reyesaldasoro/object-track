function [dataIn,handles]=readObjects(dataInName)
%function [dataIn,handles]=readObjects()
%function [dataIn,handles]=readObjects(dataInName)
%
%--------------------------------------------------------------------------
% readObjects   displays menu for user to select data folder or read
%     data from path.
%       INPUT
%         dataInName:	path to folder containing tiff images, original mat
%                       data, reduced data or labelled data.
%
%       OUTPUT
%         dataIn:       3-D matrix data from the first frame.
%         handles:      handles struct containing number of time frames
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
% small objects observed through confocal or multiphoton
% microscopes.
% For a comprehensive manual, please visit:
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
% accuracy, completeness, or usefulness of any information, or method
% in the content, or for any taken in reliance thereon.
%
%--------------------------------------------------------------------------

%% Parse input

switch nargin
    case 0
        %----- no data received,
        %----- Open question dialog and pass to next section to analyse
        button = questdlg(...
            'Please specify the location of Object data sets',...
            'Select Input',...
            'Multiple Files',...
            'Single File',...
            'Cancel',...
            'Cancel');
        if strcmp(button(1),'C')
            % no data to read, exit
            dataIn=[];handles=[];
            return;
        else
            %----- MULTIPLE Options  -----------------------------
            %----- Can be: A) Folder with Folders,              (M)
            %-----         B) Folder with mat files             (M)
            %-----         C) Folder with Tiff files (2D/3D)    (M)
            %-----         D) Single AVI file                   (S)
            %-----         E) Single MAT file                   (S)
            % read the path to the folder with the data
            % pass the pathname to same function to process
            if strcmp(button(1),'M')
                [pathname] =  uigetdir('*.*',...
                    'Please select folder where the images/data are located');
                if pathname~=  0
                    
                    [dataIn,handles] = readObjects(pathname);
                else
                    % no data to read, exit
                    %disp('Folder not found');
                    dataIn=[];handles=[];
                    return;
                end
            elseif strcmp(button(1),'S')
                % A single file, capture the name and the path and then merge into a
                % single string
                [dataInName,pathname] = uigetfile('*.*',...
                    'Please select file where the images/data are located');
                if pathname~=  0
                    if (dataInName(1) ~= filesep)
                        dataInName = strcat(filesep,dataInName);
                    end
                    if (pathname(end) ~= filesep)
                        pathname = strcat(pathname,filesep);
                    end
                    
                    dataInName = strcat(pathname(1:end-1),dataInName);
                    [dataIn,handles] = readObjects(dataInName);
                else
                    % no data to read, exit
                    %disp('Folder not found');
                    dataIn=[];handles=[];
                    return;
                end
                
            end
        end
    case 1
        %----- one argument received,
        
        % Name to be used to save the files in order with a number of
        % zeros before the number identifier
        dataOutName0 = 'T0000';
        
        %-----   it should be a char of
        % a)matlab file,
        % b)avi file or
        % c)a folder with files
        %-----   ***OR*** a folder previously created by objectTrack i.e. _mat_****
        if isa(dataInName,'char')
            %------------------- test for a pre-existing objectTrack folder
            if ~isempty(strfind(dataInName,'_mat_'))
                dataOutFolder = dataInName;
                handles.numFrames =size(dir(strcat(dataInName,filesep,'*.mat')),1);
                %---------------- test for matlab file----------------------------------
            elseif (numel(dataInName)>4)&&(strcmp(dataInName(end-2:end),'mat'))...
                    |(strcmp(dataInName(end-2:end),'MAT'))
                try
                    %read the single matlab file
                    dataOutFolder = strcat(dataInName(1:end-4),'_mat_Or',filesep);
                    mkdir(dataOutFolder)
                    
                    dataFromFile = load(dataInName);
                    namesF = fieldnames(dataFromFile);
                    dataIn4D = getfield(dataFromFile,namesF{1});
                    
                    %determine the dimensions of the file
                    [rows,cols,levs,timeFrames] = size(dataIn4D);
                    if timeFrames>1
                        % time is saved in the 4th dimension
                        handles.numFrames = timeFrames;
                    elseif levs>1
                        % time is saved in the 3rd dimension and images are 2D
                        handles.numFrames = levs;
                        dataIn4D = reshape(dataIn4D,[rows,cols,1,levs]);
                    else
                        % there must be an error as the file is only
                        % 2D exit
                        s = strcat('The mat file should have more than',...
                            'one time point, please verify');
                        disp(s);
                        dataIn=[];handles=[];return;
                    end
                    s = strcat('Read single matlab file and save as matlab',...
                        ' data in folders');
                    disp(s)
                    
                    for counterFrames=1:handles.numFrames
                        % create the file name to be saved, use zeros according
                        % to the number of files
                        dataOutName = ...
                            strcat(dataOutName0(1:end-floor(log10(counterFrames))),...
                            num2str(counterFrames));
                        dataOutName1 = strcat(dataOutFolder,dataOutName);
                        dataIn = dataIn4D(:,:,:,counterFrames);
                        %----- the images read are saved to a file HERE ------
                        save(dataOutName1,'dataIn');
                        %-----------------------------------------------------
                    end
                catch
                    disp('Could not read MAT file');
                    dataIn=[];handles=[];
                    return;
                end
                
                
            elseif (numel(dataInName)>4)&&(strcmp(dataInName(end-2:end),'avi'))...
                    |(strcmp(dataInName(end-2:end),'AVI'))
                %------------- test for AVI file ------------------------------
                % if it is an AVI read directly
                try
                    dataOutFolder = strcat(dataInName(1:end-4),'_mat_Or',filesep);
                    mkdir(dataOutFolder)
                    dataOutName0  = 'T0000';
                    
                    avi_Props = mmreader(dataInName);
                    handles.numFrames = avi_Props.NumberOfFrames;
                    disp('Read AVI movie and save as matlab data in folders')
                    
                    for counterFrames=1:handles.numFrames
                        % create the file name to be saved, use zeros according to the
                        % number of files
                        dataOutName =...
                            strcat(dataOutName0(1:end-floor(log10(counterFrames))),...
                            num2str(counterFrames));
                        dataOutName1 = strcat(dataOutFolder,dataOutName);
                        
                        dataIn = read(avi_Props, counterFrames);
                        %----- the images read are saved to a file HERE ------
                        save(dataOutName1,'dataIn');
                        %-----------------------------------------------------
                    end
                catch
                    disp('Could not read AVI file');
                    dataIn=[];handles=[];
                    return;
                end
            elseif (numel(dataInName)>4)&&(strcmp(dataInName(end-2:end),'tif'))...
                    |(strcmp(dataInName(end-2:end),'TIF'))|(strcmp(dataInName(end-3:end),'TIFF'))|(strcmp(dataInName(end-3:end),'tiff'))
                %------------- test for TIF file ------------------------------
                % if it is an TIF read image information
                try
                    dataIn_info     = imfinfo(dataInName);
                    dataIn_1        = imread(dataInName,1);
                    [rows,cols,levs]= size(dataIn_1);

                    % look for an image description field as created by ImageJ
                    if isfield(dataIn_info,'ImageDescription')
                        % look for slices and frames in the description
                        q1          = strfind(dataIn_info(1).ImageDescription,'slices=');
                        q2          = strfind(dataIn_info(1).ImageDescription,'frames=');
                        q3          = strfind(dataIn_info(1).ImageDescription,'loop');
                        handles.levs       = str2num(dataIn_info(1).ImageDescription(q1+7:q2-1));
                        handles.numFrames  = str2num(dataIn_info(1).ImageDescription(q2+7:q3-1));
       
                    else
                        % If not, assume that each element of the TIF is one time
                        % frame
                        handles.numFrames  = size(dataIn_info,1);
                        handles.levs       = 1;
                        
                    end
%
                     dataOutFolder = strcat(dataInName(1:end-4),'_mat_Or',filesep);
                     mkdir(dataOutFolder)
                     dataOutName0  = 'T0000';
                     disp('Read TIF file and save as matlab data in folders')                                 
                     for counterFrames=1:handles.numFrames
                         clear dataIn;
                         dataIn(rows,cols,handles.levs)=0;
                         for counterLevs = 1: handles.levs
                             currentFrame = (counterFrames-1)*handles.levs + counterLevs;
                             dataIn(:,:,counterLevs) = imread(dataInName, currentFrame);
                         end
                         % create the file name to be saved, use zeros according to the
                         % number of files
                         dataOutName =...
                             strcat(dataOutName0(1:end-floor(log10(counterFrames))),...
                             num2str(counterFrames));
                         disp(dataOutName)
                         dataOutName1 = strcat(dataOutFolder,dataOutName);

                         %----- the images read are saved to a file HERE ------
                         save(dataOutName1,'dataIn');
                         %-----------------------------------------------------                         
                     end

                catch
                    disp('Could not read TIF file');
                    dataIn=[];handles=[];
                    return;
                end
            else
                %------------ test for folders with files ------------------------
                % dataInName is neither MAT nor AVI file, should be a
                % folder with
                % a)matlab files
                % b)tiff files or
                % c) folders
                %To FIX Bug when path of tiff folder finish with
                %the file separator ('/' or '\')
                if (dataInName(end) ~= filesep)
                    dataInName = strcat(dataInName,filesep);
                end
                % The directory should read the files or folders
                % inside dataInName, check the last one, first ones
                % can be "." and ".." in mac and unix
                dir1 = dir(dataInName);
                if isempty(dir1)
                    % no files or folders exit
                    disp('The folder is empty');
                    dataIn=[];handles=[];
                    return;
                else
                    %
                    % remove the  unix directories "." and ".." and Mac ".DStore"
                    while strcmp(dir1(1).name(1),'.')
                        %if strcmp(dir1(2).name,'..')
                        %    dir1                    = dir1(3:end);
                        dir1 = dir1(2:end);
                    end
                    handles.numFrames = size(dir1,1);
                    
                    %
                    disp('Read data from folders and save as matlab data in folders')
                    dataOutName = strcat(dataInName(1:end-1),'_mat_Or');
                    dataOutFolder = strcat(dataInName(1:end-1),'_mat_Or',filesep);
                    mkdir(dataOutName)
                    for counterFrames=1:handles.numFrames
                        tempDir=dir1(counterFrames).name;
                        dataInName1 = strcat(dataInName,tempDir);
                        dataOutName =...
                            strcat(dataOutName0(1:end-floor(log10(counterFrames))),...
                            num2str(counterFrames));
                        dataOutName1 = strcat(dataOutFolder,dataOutName);
                        
                        %check if is folders in folders
                        if (dir1(end).isdir)
                            % a series of folders inside the original folder
                            
                            if (dataInName1(end) ~= filesep)
                                dataInName1 = strcat(dataInName1,filesep);
                            end
                            %%% CHECK THIS PART
                            % restrict to tiff files for the time being
                            % There must be several slices in the folder,
                            % each should be 2D
                            dir2 = dir(strcat(dataInName1,filesep,'T*.tif'));
                            numSlices = size(dir2,1);
                            for counterSlice=1:numSlices
                                tempDir2 = dir2(counterSlice).name;
                                dataInName2 = strcat(dataInName1,tempDir2);
                                
                                dataIn(:,:,counterSlice) = imread(dataInName2);
                            end
                            %----- the images read are saved to a file HERE ------
                            save(dataOutName1,'dataIn');
                            %-----------------------------------------------------
                            
                            %%%%% check if the name is something like
                            %%%%% TOOOO1C01Z001 to assign structure to the handles
                            
                        else
                            % a series of files inside the original folder
                            
                            if strcmp(tempDir(end-2:end),'mat')
                                dataIn = load(dataInName1);
                                
                            else
                                numImages = size(imfinfo(dataInName1),1);
                                if  numImages>1
                                    
                                    for counterImages =1:numImages
                                        dataIn(:,:,counterImages) = ...
                                            imread(dataInName1,counterImages);
                                    end
                                else
                                    dataIn = imread(dataInName1);
                                end
                            end
                            %----- the images read are saved to a file HERE ------
                            save(dataOutName1,'dataIn');
                            
                        end
                    end
                end
            end          
            dataIn = dataOutFolder;

        else
            %-- dataInName is not a char, return as the input should be always a file
            %-- or folders to read
            disp('The input should be a file or a folder to be read');
            dataIn=[];handles=[];
            return;
        end
end

