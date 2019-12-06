
% A virtual class mimicking the PVCAM device

classdef virtualPVCam < mic.Base
  
    properties
        hDevice
        clock
        
        lIsImageReady
        lIsConnected = false
        lCaptureMode = false
        dCurrentImage = []
        
        dExposureTime = 1
        dTemperature = 20
        
        dPicIndex = 1;
    end

    methods 
        
        function this = virtualPVCam(varargin)
            this.init();
        end
        
        function init(this)
            this.clock = mic.Clock('Virtual_PVCAM');
            this.lIsConnected = true;
        end
        
        function lVal = initCamera(this, index)
            this.lIsConnected = true;
            lVal = true;
        end
        
        function lVal = uninitCamera(this)
            this.lIsConnected = false;
            lVal = true;
        end
        
        function lVal = isInitialized(this)
            lVal = this.lIsConnected();
        end
       
        function setTmpSetpoint(this, dVal)
             this.dTemperature = dVal;
        end
        
        function dT = getTmp(this)
            dT = this.dTemperature;
        end
        
        function lVal = cameraSettings(this, lCaptureMode, dExposureTime,...
                dROI1, dROI2, dROI3, dROI4, xbin, ybin)
            this.lCaptureMode = lCaptureMode;
            this.dExposureTime = dExposureTime;
            
            lVal = true;
        end

        
        function lVal = startCapture(this)
            this.lIsImageReady = false;
            
            dTStart = tic;
            
            dasAcquisition = mic.DeferredActionScheduler(...
                'clock', this.clock, ...
                'fhAction', @()this.acquisitionHandler(),...
                'fhTrigger', @()toc(dTStart) > this.dExposureTime,...
                'cName', 'virtualAcquisition', ...
                'dDelay', 0.3, ...
                'dExpiration', 100, ...
                'lShowExpirationMessage', true);
            dasAcquisition.dispatch();
            
            lVal = true;
        end
        
        function acquisitionHandler(this)
            [cDir, cName, cExt] = fileparts(mfilename('fullpath'));
            switch(this.dPicIndex)
                case 0
                    img = imread([cDir '/+dummyImages/manny.png']);
                case 1
                    img = imread([cDir '/+dummyImages/brown_bear.png']);
                case 2
                    img = imread([cDir '/+dummyImages/manny_tophat.png']);
                case 3
                    img = imread([cDir '/+dummyImages/lena512.png']);
            end
            this.dCurrentImage = sum(img,3);
            this.dPicIndex = mod(this.dPicIndex + 1, 4);
            this.lIsImageReady = true;
            
        end

        
        % Used to both check if the image is ready and to get the image
        % when it is ready.  Return "null" if not ready yet
        function oData = getImage(this)
            if this.isImageReady()
                oData = this.dCurrentImage;
            else
                oData = [];
            end
            
            this.lIsImageReady = false;
        end
        
        % Accessors
        function lVal = isImageReady(this)
            lVal = this.lIsImageReady;
        end

        
    end
    
    methods (Access = protected)
        
    end
    
        

end