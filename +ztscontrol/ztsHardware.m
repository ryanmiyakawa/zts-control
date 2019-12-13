% MET5 hardware class.  Contains getters for all hardware handles.
%
% Every hardware communication requires the addition of four things:
%
% 1) Corresponding "comm" property (e.g., commMfDriftMonitorMiddleware) represeting
% the stored handle to the hardware component
%
% 2) Getter function: should return the comm if it is already initialized,
% otherwise should initialize it and then return it
%
% 3) Delete function: disconnects device and unsets the comm property.
%
% 4) Modify the path variable structure to ensure your getter is properly
% scoped.
%

%%%

classdef ztsHardware < mic.Base
        
    properties (Constant)
        

        
        
    end
    
	properties
        clock
        
        % {cxro.Instruments 1x1}
        jInstruments
        
        % {cxro.common.device.motion.Stage 1x1}
        commSpaceFabHexapod
        
        % Temporarily:{lsicontrol.virtualDevice.virtualPVCam}
        commPIMTECamera
        
        cDirMet5InstrumentsDir = ...
            fullfile(fileparts(mfilename('fullpath')), '..', 'jar');
        
        cJarName = 'zts-instruments-1.1.0-all.jar';
    end
    

    
    properties (Access = private)
        
        
    end
    
        
    

    
    methods
        
        % Constructor
        function this = ztsHardware()
            this.init();
        end
    

        
        % Setters
        function setClock(this, clock)
            this.clock = clock;
        end
        

        
        
        %% Getters
        function comm = getInstruments(this)
            if isempty(this.jInstruments)
                this.jInstruments = cxro.zts2.Instruments(this.cDirMet5InstrumentsDir);
            end
            comm = this.jInstruments;
        end
        
        
        
        
        % Spacefab hexapod
        function comm = getHexapod(this)
            if isempty(this.jInstruments)
                this.getInstruments();
            end
            if isempty(this.commSpaceFabHexapod)
                this.commSpaceFabHexapod = this.jInstruments.getSpaceFab();
            end
            comm = this.commSpaceFabHexapod;
        end
        
        % Pixis camera
        function comm = getCamera(this)
            if isempty(this.jInstruments)
                this.getInstruments();
            end
            if isempty(this.commPIMTECamera)
                this.commPIMTECamera = this.jInstruments.getPixis();
            end
            comm = this.commPIMTECamera;
        end
        

    end
    
    methods (Access = private)
        
        
        
        
        
        
        
        %% Init  functions
        % Initializes directories and any helper classes 
        function init(this)

            % Java
            ceJavaPathLoad = { ...
                fullfile(this.cDirMet5InstrumentsDir, this.cJarName), ...
            };

            mic.Utils.map(...
                ceJavaPathLoad, ...
                @(cPath) this.addJavaPathIfNecessary(cPath), ...
                0);
        end
        
        
        function addJavaPathIfNecessary(this, cPath)
            cecPaths = javaclasspath('-dynamic');
            
            if ~isempty(cecPaths)
                ceMatches = mic.Utils.filter(cecPaths, @(cVal) strcmpi(cVal, cPath));
                if ~isempty(ceMatches)
                    return
                end
            end
            
            fprintf('zts.hardware.addJavaPathIfNecessary adding:\n%s\n', cPath);
            javaaddpath(cPath);
            
        end
        
        
                

    end % private
    
    
end