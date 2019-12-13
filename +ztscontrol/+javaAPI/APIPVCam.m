


classdef APIPVCam < mic.Base
  
    properties
        hDevice
        clock
        
        dPixels = [2048, 2048]
        
        dAcquisitionDelay = 1; % delay associated with returning an image
        dExposureTime = -1 % this is not stored on device so we have to handle it here
        dTemperature = 25 % also log this since we don't have access to it during an exposure
        dBinning = 1
        
        
        
        fhOnImageReady % Function to call when image is finished
        fhWhileAcquiring = @(elapsedTime)[]% Function to call on trigger
        
        
        
        nPixelsX = 2048
        nPixelsY = 2048
        
        dCurrentImage = []
        
        % Flags for keeping track of image status
        lIsFocusing     = false
        lIsAcquiring    = false
        lIsImageReady   = false
        
        
        dasAcquisition % deferred actions scheduler for acquire
        
        dTStart = 0 % keeping track of exposure times
        
    end

    methods 
        
        function this = APIPVCam(varargin)
            for k = 1:2:length(varargin)
                if this.hasProp(varargin{k})
                    this.msg(sprintf('settting %s', varargin{k}), 3);
                    this.(varargin{k}) = varargin{k + 1};
                end
            end
            
            this.init();
        end
        
        function init(this)
            if isempty(this.clock)
                this.initDefaultClock();
            end
            
            % Init exposure time, which calls cameraSettings, which needs
            % to be set before an acquisition can happen:
            this.setExposureTime(1);
        end
        
        function initDefaultClock(this)
             this.clock = mic.Clock('APIPVCam');
        end
       
        % Replace these with proper getter and setter functions:
        function setTemperature(this, dVal)
            this.hDevice.setTmpSetpoint(dVal);
        end
        function dT = getTemperature(this)
            if this.lIsAcquiring
                % Read most recent value when we are acquiring since T is
                % locked;
                dT = this.dTemperature;
            else
                try
                    dT = this.hDevice.getTmp();
                    this.dTemperature = dT; % store most recent temperature
                catch
                    fprintf('Camera temperature read failed!');
                    dT = -1000;
                end
                
            end
            
            if dT < -70 && dT > -1000 % overheated
                dT = 9999;
            end
        end
        
        function lVal = setBinning(this, dVal)
            this.dBinning = dVal;
            
            % Set exposure time via camera settings
            lVal = this.hDevice.cameraSettings(false, uint64(this.dExposureTime*1000),...
                0, this.dPixels(1) - 1, 0, this.dPixels(2) - 1, ...
                this.dBinning, this.dBinning);
            
            if ~lVal
                msgbox('CAMERA EXP TIME/ROI SET FAILED');
            end
        end
        
        function lVal = setExposureTime(this, dVal)
            this.dExposureTime = dVal;
            
            % Set exposure time via camera settings
            lVal = this.hDevice.cameraSettings(false, uint64(this.dExposureTime*1000),...
                0, this.dPixels(1) - 1, 0, this.dPixels(2) - 1, ...
                this.dBinning, this.dBinning);
            
            if ~lVal
                msgbox('CAMERA EXP TIME/ROI SET FAILED');
            end
            
        end
        
        function dS = getExposureTime(this)
             dS = this.dExposureTime;
        end
        
        function lVal = connect(this)
            lVal = this.hDevice.initCamera(0);
            if ~lVal
                msgbox('CAMERA INIT FAILED');
            end
            
        end
        
        function disconnect(this)
             % Tell camera to abort:
             this.hDevice.stopCapture();
             this.lIsAcquiring = false;
             this.lIsFocusing = false;
             
             
             lVal = this.hDevice.uninitCamera();
             if ~lVal
                msgbox('CAMERA UNINIT FAILED');
            end
        end
        
        function lVal = isConnected(this)
            lVal = this.hDevice.isInitialized();
        end
        
        % -------------
        
        function requestAcquisition(this)
            % Verify that camera settings have been set on each acquire:
            this.setExposureTime(this.dExposureTime);
            
            this.lIsAcquiring = true;
            if (this.dExposureTime <= 0)
                msgbox('Need positive exposure time setting');
                return
            end
            
            fprintf('APICamera:Requesting acquisition\n');
            this.lIsImageReady = false;
            
            if ~this.hDevice.startCapture()
                msgbox('CAMERA ACQUISITION FAILED TO START')
                return;
            end
            
            this.dTStart = tic;
            
            this.dasAcquisition = mic.DeferredActionScheduler(...
                'clock', this.clock, ...
                'fhAction', @()this.acquisitionHandler(),...
                'fhTrigger', @()this.checkImageStatus(),... 
                'cName', 'DASCameraAcquisition2', ...
                'dDelay', 0.05, ...
                'dExpiration', 100, ...
                'lShowExpirationMessage', true);
            this.dasAcquisition.dispatch();
        end
        
        function abortAcquisition(this)
            % Stop service that is waiting for an image
            this.dasAcquisition.abort();
            this.lIsAcquiring = false;
            
            fprintf('(APIPVCam) Aborting camera acquisition\n');
            
            % Tell camera to abort:
            this.hDevice.stopCapture();
        end
        
        function acquisitionHandler(this)
            
            
            dImg = typecast((this.hDevice.getImage()), 'uint16');
            
            % Once image is captured, stop camera:
            this.hDevice.stopCapture();
            
            this.dCurrentImage = reshape(dImg, 2048/this.dBinning, 2048/this.dBinning);
            [sr, sc] = size(this.dCurrentImage);
            this.dCurrentImage = crop2(this.dCurrentImage, ...
                min([sr, sc]), min([sr, sc]));
            
            fprintf('APICamera:Acquisition came back. Image is [%d X %d]\n', min([sr, sc]), min([sr, sc]));
            
            this.lIsImageReady = true;
            this.lIsAcquiring = false;
            this.fhOnImageReady(this.dCurrentImage);
        end
        
        % Start focus mode
        function startFocus(this)
            this.lIsFocusing = true;
            this.requestFocusAcquisition();
        end
        
        function stopFocus(this)
            this.lIsFocusing = false;
            this.abortAcquisition();
        end
        
        function requestFocusAcquisition(this)
            % Verify that camera settings have been set on each acquire:
            this.setExposureTime(this.dExposureTime);
            
            this.lIsAcquiring = true;
            if (this.dExposureTime <= 0)
                msgbox('Need positive exposure time setting');
                return
            end
            
            fprintf('APICamera:Requesting acquisition\n');
            this.lIsImageReady = false;
            
            if ~this.hDevice.startCapture()
                msgbox('CAMERA ACQUISITION FAILED TO START')
                return;
            end
            
            this.dTStart = tic;
            
            this.dasAcquisition = mic.DeferredActionScheduler(...
                'clock', this.clock, ...
                'fhAction', @()this.focusAcquisitionHandler(),...
                'fhTrigger', @()this.checkImageStatus(),... 
                'cName', 'DASCameraFocus', ...
                'dDelay', 0.05, ...
                'dExpiration', 100, ...
                'lShowExpirationMessage', true);
            this.dasAcquisition.dispatch();
        end
        
        function focusAcquisitionHandler(this)
            fprintf('APICamera:Focus acquisition came back\n');
            
            dImg = typecast((this.hDevice.getImage()), 'uint16');
            
            % Once image is captured, stop camera:
            this.hDevice.stopCapture();
            
            this.dCurrentImage = reshape(dImg, 2048/this.dBinning, 2048/this.dBinning);
            [sr, sc] = size(this.dCurrentImage);
            this.dCurrentImage = crop2(this.dCurrentImage, ...
                min([sr, sc]), min([sr, sc]));
            this.lIsImageReady = true;
            this.lIsAcquiring = false;
            this.fhOnImageReady(this.dCurrentImage);
            
            
            
            % if we're still focusing, call again:
            if this.lIsFocusing
                this.requestFocusAcquisition();
            end
            
        end
        
       
        
        
        % return true if acquisition is finished
        function lVal = checkImageStatus(this)
            lVal = this.hDevice.checkStatus();
            
            % Compute elapsed time
            this.fhWhileAcquiring(toc(this.dTStart));
        end
        
        

        % Accessors
        function lVal = isImageReady(this)
            lVal = this.lIsImageReady;
        end
        function dImg = getImage(this)
            dImg = this.dCurrentImage;
        end
        
    end
    
    methods (Access = protected)
        
    end
    
        

end