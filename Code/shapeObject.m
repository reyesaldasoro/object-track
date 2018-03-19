function [centreLine,statsObject]=shapeObject(dataIn)
%function [centreLine,statsObject]=shapeObject(dataIn)
%
%--------------------------------------------------------------------------
% shapeObject  calculate the shape metrics from the objects 
%
%       INPUT
%         dataIn:           image from which shape will be analysed, it can be:
%                                   a 3D with a single Object
%                                   a 3D with a several Objects distinguished by a unique number
%                                   a 4D with a single Object that moves with time
%                                   a 4D [rows,cols,1,numFrames] with many objects but only 1 slice
%                                   a *Directory* where many individual time frames are stored, in that
%                                      case results are stored in a new directory
%
%       OUTPUT
%         centreLine:       a matrix with the same size as dataIn and either a
%                                   centreLine corresponding to each Object
%         statsObject:     a structure with the following parameters (for each object)
%                                   maxEndpoints    number of endpoints for whole object
%                                   avEndpoints     average number
%                                   tortuosity      numpixels / chessboard distance
%                                   areaCentreLine  numpixels centreline
%                                   areaObject     numpixels object
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



if isa(dataIn,'char')
    % --------------------------- dataInName is not mat file, should be a folder with a)matlab files
    disp('Read matlab files from folder, and plot them accordingly')
    dir1                                                    = dir(strcat(dataIn,'/*.mat'));
    dataOutName                                             = strcat(dataIn(1:end-2),'Sh');
    mkdir(dataOutName)
    
    numFrames                                               = size(dir1,1);
     for counterDir=1:numFrames
        tempDir                                             = dir1(counterDir).name;
        dataInName                                          = strcat(dataIn,'/',tempDir);
        dataOutName1                                        = strcat(dataOutName,'/',tempDir);

        disp(strcat('Processing folder: ',dataInName));
        dataFromFile                                        = load(dataInName);
        if isfield(dataFromFile,'dataIn')
            dataIn2                                         = dataFromFile.dataIn;
        else
            namesF                                          = fieldnames(dataFromFile);
            dataIn2                                         = getfield(dataFromFile,namesF{1}); %#ok<GFLD>
        end
        [centreLine,statsObject]                           = shapeObject(dataIn2);
        save(dataOutName1,'centreLine','statsObject');
        
     end

else

    % Regular dimension check and definition of time frames
    [rows,cols,levs,numFrames]                              = size(dataIn);
    if levs==1
        filtG                                               = gaussF(3,3,1);
    else
        filtG                                               = gaussF(3,3,3);
    end
    % Data can be either:   a 4D logical matrix (single object in time) or
    %                       a 3D logical/double matrix  (many objects in a single frame)
    
    if (numFrames>1)
        if (isa(dataIn,'logical'))
            statsObject(numFrames).maxEndpoints            = 0;
            statsObject(numFrames).avEndpoints             = 0;
            statsObject(numFrames).tortuosity              = 0;
            statsObject(numFrames).areaCentreLine          = 0;
            statsObject(numFrames).areaObject             = 0;
            statsObject(numFrames).volSurfRatio            = 0;
            statsObject(numFrames).roundness               = 0;
            centreLine(rows,cols,levs,numFrames)            = 0;
            % Begin the loop over the frames  (data has been segmented and tracked)
            for countFrames = 1 :numFrames
                %------- If data is filtered, the centreline will be smoother with less branching
                tempdata1                                  = (dataIn(:,:,:,countFrames));
                %------- morphologically THIN the image and remove a few spurious lines
                %------- only for relatively big objects
                [centreLine(:,:,:,countFrames),statsObject(countFrames)] = processShape(tempdata1);
            end
        else
            disp('Data format not supported');
            centreLine                                      = [];
            statsObject                                    = [];
            return;
        end
    else
        if (isa(dataIn,'logical'))
            tempdata1=imfilter(dataIn,filtG);
            [centreLine,statsObject]                       = processShape(tempdata1);
        else
            indivObjects                                = unique(dataIn);
            numObjects                                  = size(indivObjects,1)-1;
            statsObject(numObjects).maxEndpoints       = 0;

            statsObject(numObjects).avEndpoints        = 0;
            statsObject(numObjects).tortuosity         = 0;
            statsObject(numObjects).areaCentreLine     = 0;
            statsObject(numObjects).areaObject        = 0;
            statsObject(numFrames).volSurfRatio            = 0;
            statsObject(numFrames).sphericity              = 0;
            centreLine(rows,cols,levs)                      = 0;

            % Begin the loop over the objects
            for countFrames = 1:numObjects
                %------- If data is filtered, the centreline will be smoother with less branching
                tempdata1                                  = (dataIn==indivObjects(countFrames+1));                
                %------- morphologically THIN the image and remove a few spurious lines
                %------- only for relatively big objects
                [centreLineTemp,statsObject(countFrames)]  = processShape(tempdata1);
                centreLine                                  = centreLine+countFrames*centreLineTemp;
            end
        end
    end

end
end


%----------------
function  [centreLine,statsN] = processShape(tempdata1)

% Regular dimension check and definition of time frames
[rows,cols,levs]                                            = size(tempdata1);
% predefine some of the intermediate parameters
centreLine                                                  = zeros(rows,cols,levs);

numEndpoints2                                               = zeros(levs,1);
tortuosCoef                                                 = zeros(levs,1);
numBranchPoints                                             = zeros(levs,1);
torT(levs)                                                  = 0;

% find the position of the current object
indTemp                                                     = find(tempdata1);
[XX,YY,ZZ]                                                  = ind2sub([rows cols levs],indTemp);

minR                                                        = min(XX(:));
maxR                                                        = max(XX(:));
minC                                                        = min(YY(:));
maxC                                                        = max(YY(:));
minL                                                        = min(ZZ(:));
maxL                                                        = max(ZZ(:));
rowsCoor1                                                    = max(1,minR-1):min(rows,maxR+1);
colsCoor1                                                    = max(1,minC-1):min(cols,maxC+1);

for k = minL:maxL
    %obtain centreLine by thinning the blob
    centreLine(rowsCoor1,colsCoor1,k)                     = bwmorph(bwmorph(imfill(tempdata1(rowsCoor1,colsCoor1,k),'holes'),'clean'),'thin','inf');
    [r,c]                                               = find(centreLine(:,:,k));
    switch numel(r)
        case 0
            % nothing to be analysed, zero by definition
            numEndpoints2(k)                            = 0;
            tortuosCoef(k)                              = 0;
        case 1
            % a single point, could have been a perfect circle; one endpoint tortuosity 1
            numEndpoints2(k)                            = 1;
            tortuosCoef(k)                              = 1;
        case 2
            % two points forming a line
            numEndpoints2(k)                            = 2;
            tortuosCoef(k)                              = 1;
        otherwise
            %
            rowsCoor                                    = max(1,min(r)-1):min(rows,max(r)+1);
            colsCoor                                    = max(1,min(c)-1):min(cols,max(c)+1);
            currentCentreLine                           = centreLine(rowsCoor,colsCoor,k);
            %try labeling first and then find endpoints which will be used when tortuosity is calculated
            [BranchPoints1,BranchPoints2,numBranchPoints(k)]=BranchPoints(currentCentreLine);
            if numBranchPoints(k)>0
                %
                %before  analysing by segment, try analysing the WHOLE tortuosity
                currEndPoints                           = EndPoints(currentCentreLine);
                [rrr,ccc]                               = find(currEndPoints);
                try
                tortuosCoef(k)                          = (sum(sum((diff([rrr ccc;rrr(1) ccc(1)])).^2,2).^(1/2))) / (numel(r));
                catch
                   qqq=1; 
                end

            else
                %no branch points, just one segment or a ring like structure with no branch points or
                %end points
                [tempdata2,numSegments]                 = bwlabel(currentCentreLine);
                lengthSegments                          = regionprops(tempdata2,'area');
                [currEndPoints,currEndPointsDil,numEndpoints2(k)]                           = EndPoints(currentCentreLine);
                for countSeg=1:numSegments
                    [rr,cc]                             = find(currEndPoints&(tempdata2==countSeg));
                    if size(rr,1)==1
                        torT                            = 1;
                    elseif size(rr,1)==0
                        torT                            = 1;
                    else
                        try
                        torT(countSeg)                  = (lengthSegments(countSeg).Area)/(max(abs((diff([rr cc])))));
                        catch
                            qqq=1;
                        end
                    end
                end
                tortuosCoef(k)                          = mean(torT(logical(torT)));
            end
    end
end

surfObject                                                 = zerocross(double(tempdata1(rowsCoor1,colsCoor1,:))-0.5);
totSurfaceObject                                           = sum(surfObject(:));
[temp1]                                                     = find(numEndpoints2);
if isempty(temp1)
    statsN.maxEndpoints                                     = 0;
    statsN.avEndpoints                                      = 0;
    statsN.tortuosity                                       = 0;
else
    statsN.maxEndpoints                                     = max(numEndpoints2(temp1));
    statsN.avEndpoints                                      = mean(numEndpoints2(temp1));
    statsN.tortuosity                                       = mean(tortuosCoef(temp1));
end
statsN.areaCentreLine                                       = size(find(centreLine(:,:,:)),1);
statsN.areaObject                                          = size(find(tempdata1),1);
statsN.volSurfRatio                                         = statsN.areaObject/totSurfaceObject;
statsN.sphericity                                           = ((36*pi*(statsN.areaObject^2))^(1/3))/totSurfaceObject;

end
