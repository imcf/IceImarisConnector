% IceImarisConnector constructor
%
% DESCRIPTION
%
%   IceImarisConnector is a simple commodity class that eases communication
%   between Imaris and MATLAB using the Imaris XT interface.
%
% SYNOPSIS
%
%   conn = IceImarisConnector(vImarisApplication, indexingStart)
%
% INPUT
%
%   vImarisApplication : (optional) if omitted (or set to []), an 
%                        IceImarisConnector object is created that is 
%                        not connected to any Imaris instance.
%
%                        Imaris can then be started (and connected) using
%                        the startImaris() method, i.e.
%
%                            conn.startImaris()
%
%                        Alternatively, vImarisApplication can be:
%
%                        - an Imaris Application ID as provided by Imaris
%                        - an IceImarisConnector reference
%                        - an Imaris Application ICE object.
%
%   indexingStart      : (optional, default is 0) either 0 or 1, depending
%                        on whether you prefer to index arrays in 
%                        IceImarisConnector starting at 0 or 1. 
%                        
%                        All indexing in ICE starts at 0; in contrast, 
%                        MATLAB indexing starts at 1.
%                        To keep consistentcy, indexing in IceImarisConnector
%                        is also 0-based (i.e. indexingStart defaults to 0).
%                        This means that to get the data volume for the 
%                        first channel and first time point of the dataset
%                        you will use conn.GetDataVolume(0, 0).
%                        It you are come confortable with 1-based indexing,
%                        i.e. you prefer using conn.GetDataVolume(1, 1), 
%                        you can set indexingStart to 1.
%
%                        Whatever you choose, be consistent!
%
% REMARK
%
%   The Imaris Application ICE object is stored in the read-only property
%   mImarisApplication. The mImarisApplication property gives access to
%   the entire Imaris ICE methods. Example:
%
%   conn.mImarisApplication.GetSurpassSelection()
%
%   returns the currently selected object in the Imaris surpass scene.
%
% OUTPUT
%
%   conn    :  an object of class IceImarisConnector

% AUTHORS
%
% Author: Aaron Ponti
% Contributor: Jonas Dorn

% LICENSE
%
% ImarisConnector is a simple commodity class that eases communication between
% Imaris and MATLAB using the Imaris XT interface.
% Copyright (C) 2011  Aaron Ponti
%
% This program is free software; you can redistribute it and/or
% modify it under the terms of the GNU General Public License
% as published by the Free Software Foundation; either version 2
% of the License, or (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this program; if not, write to the Free Software
% Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

classdef IceImarisConnector < handle
        
    properties (SetAccess = private, GetAccess = public)
        mImarisApplication = [];
    end
    
    properties (Access = private)
        mImarisPath;
        mImarisLib;
        mImarisExePath;
        mImarisServerExePath;
        mImarisLibPath;
        mImarisObjectID;
        mIndexingStart = 0; % default is zero-based
        mUserControl;
    end
    
    % Methods
    methods
        
        % Constructor
        function this = IceImarisConnector(vImarisApplication, indexingStart)

            % First, we prepare everything we need
            % Store the Imaris and ImarisLib path
            [success, errorMessage] = findImaris(this);
            if ~success
                error(errorMessage);
            end
            
            % Add the ImarisLib.jar package to the java class path
            % (if not there yet)
            if all(cellfun(...
                    @isempty, strfind(javaclasspath, 'ImarisLib.jar')))
                javaaddpath(this.mImarisLibPath);
            end
            
            % Create and store an ImarisLib instance
            this.mImarisLib = ImarisLib();

            % Assign a random id
            this.mImarisObjectID = randi(100000);

            % Now we check the (optional) input parameter.
            % We have three cases. If called without parameters, we just
            % create an IceImarisConnector object that does nothing.
            % If we get one input parameter, we have to distinguish between
            % three cases: 
            % - we get an Imaris Application ID as provided by Imaris and
            %      thus we query the Imaris Server for the application
            % - we get an IceImarisConnector reference and thus we just
            %      return it
            % - we get an Imaris Application ICE object (rare) and thus
            %      we simply assign it to the mImarisApplication property.
            
            if nargin == 0
                
                % We already did everything
                return
            end
                
            if nargin > 0 && ~isempty(vImarisApplication)
                
                if isa(vImarisApplication, 'IceImarisConnector')
                    
                    % If the input parameter is an IceImarisConnector
                    % object we return the reference. This way, an
                    % XTension class can take a reference to an 
                    % IceImarisConnector object as input parameter
                    this = vImarisApplication;
                    
                elseif isa(vImarisApplication, 'Imaris.IApplicationPrxHelper')
                    
                    % This is an Imaris application object - we store it
                    this.mImarisApplication = vImarisApplication;
                    
                elseif isscalar(vImarisApplication)

                    % Check if the application is registered
                    server = this.mImarisLib.GetServer();
                    nApps = server.GetNumberOfObjects();
                    if nApps == 0
                        error('There are no registered Imaris applications.');
                    end
                    
                    if server.GetObjectID(vImarisApplication) == -1
                        error('Invalid Imaris application ID.');
                    end

                    this.mImarisApplication = ...
                        this.mImarisLib.GetApplication(vImarisApplication);
                
                else
                
                    error(['The passed object is not a Imaris ', ...
                        'Application ID.']);
   
                end
            end
            
            if nargin > 1 && ~isempty(indexingStart)
                
                this.mIndexingStart = indexingStart;
                
            end
            
            if nargin > 2
                
                error('Wrong number of input arguments!');
                
            end
            
        end
       
        % Desctructor
        function delete(this)
        
            if this.mUserControl == 1
                if ~isempty(this.mImarisApplication)
                    this.closeImaris();
                end
            end

        end
        
    end
    
    % External public and static methods
    % =====================================================================
    
    methods (Access = public)
        
        % autocast
        castObject = autocast(this, obj)
                    
        % createAndSetSpots(this, coords, timeIndices, radii, name, color)
        createAndSetSpots(this, coords, timeIndices, radii, name, color)
        
        % close Imaris
        success = closeImaris(this, varargin)
        
        % display
        display(this)        

        % getAllSurpassChildren
        children = getAllSurpassChildren(this, recursive, filter)

        % getDataVolume
        stack = getDataVolume(this, channel, timepoint, iDataset)

        % getDataVolume
        stack = getDataVolumeRM(this, channel, timepoint, iDataset)
        
        % getExtends
        [minX maxX minY maxY minZ maxZ] = getExtends(this)

        % getImarisVersionAsInteger
        version = getImarisVersionAsInteger(this)
        
        % getMatlabDatatype
        type = getMatlabDatatype(this)
        
        % getSizes
        [sizeX sizeY sizeZ sizeC sizeT] = getSizes(this)
        
        % getSurpassScene
        vSurpassScene = getSurpassScene(this, varargin)

        % getVoxelSizes
        [voxelSizesX, voxelSizesY, voxelSizesZ] = getVoxelSizes(this)
        
        % getSurpassCameraRotationMatrix
        [R, isI] = getSurpassCameraRotationMatrix(this)
        
        % indexingStart
        n = indexingStart(this)
        
        % info
        info(this)

        % isAlive
        alive = isAlive(this)
        
        % mapPositionsUnitsToVoxels
        varargout = mapPositionsUnitsToVoxels(this, varargin)
        
        % mapPositionsVoxelsToUnits
        varargout = mapPositionsVoxelsToUnits(this, varargin)
        
        % setDataVolume
        setDataVolume(this, stack, channel, timepoint)
        
        % setSpots
        setSpots(this, spotStruct)
       
        % startImaris
        success = startImaris(this, userControl)

    end

    methods (Access = public, Static = true)
        
        % version
        v = version(this);

        % mapRgbaScalarToVector
        rgbaVector = mapRgbaScalarToVector(rgbaScalar)

        % mapRgbaVectorToScalar
        rgbaScalar = mapRgbaVectorToScalar(rgbaVector)
               
    end
    
    methods (Access = private)
        
        % findImaris
        [imarisPath, errorMessage] = findImaris(this)
        
        % isOfType
        b = isOfType(this, object, type)
        
        % startImarisServer
        [success, errorMessage] = startImarisServer(this)
        
    end
    
end
