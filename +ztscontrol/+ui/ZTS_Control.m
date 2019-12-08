classdef ZTS_Control < mic.Base
    
    
    properties
        
        cAppPath        = fileparts(mfilename('fullpath'))
        cDataPath
        cConfigPath
        clock = {}
        vendorDevice
        
        % Colors:
        dAcquireColor   = [.97, 1, .9]
        dFocusColor     = [.93, .9, 1]
        dDisableColor   = [.9, .8, .8]
        dInactiveColor  = [.9, .9, .9]
        
        % Comm handles:
         % {mic.ui.device.GetSetLogical 1x1}
        
        uiCommSmarActSpaceFab
        uiCommPixisCamera
        
        uicommWaferDoseMonitor
        
        
        % Instruments handle
        hInstruments
        
        % Stages
        uiDeviceArrayHexapod
       
        
        
        % Bridges
        oHexapodBridges
        
        

        uibHomeHexapod
        uibHomeGoni
        
        % APIs:
        apiHexapod          = []
       
        apiCamera           = []
       
        
        % Camera
        uiDeviceCameraTemperature
        uiDeviceCameraExposureTime
        
        uiButtonAcquire
        uiButtonFocus
        uiButtonStop
        uiButtonSaveImage
        uiButtonSetBackground
        uipBinning
        
        uipbExposureProgress
        
        uieImageName
        
        dBackgroundImage = zeros(650)
        uicbSubtractBackground
        
        % Configuration
        uicHexapodConfigs
        
        uicTemperatureConfig
        uicExposureConfig

        
        uiSLHexapod
        
        
       
        
        hpStageControls
        hpCameraControls
        hpPositionRecall
        hpMainControls
        
        uiFileWatcher
              
        % axes:
        uitgAxes
        hsaAxes
        haScanMonitors = {}
        
        haScanOutput
        
        
       
        
        % Scans:
        uitgScan
        ceTabList = {'1D-scan', '2D-scan', '3D-scan', '1D Coupled', '2D Coupled'}
        
        
        % Scan setups
        scanHandler
        ss1D
        ss2D
        ss3D
        ssExp1
        ssExp2
        ssCurrentScanSetup %pointer to current scan setup
        lSaveImagesInScan = false
        dImageSeriesNumber = 0 %Used to keep track of the number of series 
        
        % Scan progress text elements
        uiTextStatus
        uiTextTimeElapsed
        uiTextTimeRemaining
        uiTextTimeComplete
        
        % Keep track of initial state of last scan
        stLastScanState
        
        lAutoSaveImage
        lIsScanAcquiring = false % whether we're currently in a "scan acquire"
        lIsScanning = false
        
        lIsConjugateLockEnabled = false
        dInitialHSSZValue = 0
        dInitialRetZValue = 0
        
        % Scan ouput:
        stLastScan
        
        dNumScanOutputAxes
        ceScanCoordinates
        dLinearScanOutput
        dScanOutput
        
        
        ceBinningOptions = {1, 2}
        
        hFigure
        
        
    end
    
    properties (Constant)
        dWidth  = 1750;
        dHeight =  1000;
        
        % Camera modes
        U8CAMERA_MODE_ACQUIRE = 0
        U8CAMERA_MODE_FOCUS = 1
        
        dMultiAxisSeparation = 30;
        
        cHexapodAxisLabels = {'X', 'Y', 'Z', 'Rx', 'Ry', 'Rz'};
        
        
        ceScanAxisLabels = {'Hexapod X', ...
                        'Hexapod Y', ...
                        'Hexapod Z', ...
                        'Hexapod Rx', ...
                        'Hexapod Rx', ...
                        'Hexapod Rz', ...
                        'Do Nothing'};
        ceScanOutputLabels = {'Image capture', 'Image intensity'};
    end
    
    properties (Access = private)
        cDirSave = fileparts(mfilename('fullpath'));
    end
    
    events
        eImageAcquired
        eImageSaved
    end
    
    methods
        
        function this = ZTS_Control(varargin)
            
            for k = 1:2:length(varargin)
                this.(varargin{k}) = varargin{k+1};
            end
            
            if isempty(this.clock)
                this.initClock();
            end
            
            
            this.initConfig();
            this.initUi();
            this.initComm();
            
            this.initDataPath();
           
            
            
        end
        
        function initDataPath(this)
             % Make data 
            [cDirThis, cName, cExt] = fileparts(mfilename('fullpath'));
            this.cDataPath = fullfile(cDirThis, '..', '..', '..', 'Data');
            
            sFils = dir(fullfile(cDirThis, '..', '..', '..'));
            lDataFolderExist = false;
            for k = 1:length(sFils)
                if strcmp(sFils(k).name, 'Data')
                    lDataFolderExist = true;
                end
            end
            if ~lDataFolderExist
                mkdir(this.cDataPath);
            end
                
            
        end
        
        function initComm(this)
             
            ceVararginCommandToggle = {...
                'cTextTrue', 'Disconnect', ...
                'cTextFalse', 'Connect' ...
            };

           
            this.uiCommSpaceFab = mic.ui.device.GetSetLogical(...
                'clock', this.clock, ...
                'ceVararginCommandToggle', ceVararginCommandToggle, ...
                'dWidthName', 130, ...
                'lShowLabels', false, ...
                'lShowDevice', false, ...
                'lShowInitButton', false, ...
                'cName', 'spaceFab', ...
                'cLabel', 'SpaceFab', ...
                'fhGet', @() isempty(this.apiHexapod), ...
                'fhSetTrue', @this.initAndConnectSpaceFab, ...
                'fhSetFalse', @this.destroyAndDisconnectSpaceFab ...
                );
        
            this.uiCommPixisCamera = mic.ui.device.GetSetLogical(...
                'clock', this.clock, ...
                'ceVararginCommandToggle', ceVararginCommandToggle, ...
                'dWidthName', 130, ...
                'lShowLabels', false, ...
                'lShowDevice', false, ...
                'lShowInitButton', false, ...
                'cName', 'pixisCamera', ...
                'cLabel', 'PIXIS Camera', ...
                'fhGet', @() isempty(this.apiCamera), ...
                'fhSetTrue', @this.initAndConnectPixis, ...
                'fhSetFalse', @this.destroyAndDisconnectPixis ...
                );
            
            
        end
        


   
        
        
        function letMeIn(this)
           1;
        end
        
        function initConfig(this)
            this.cConfigPath = fullfile(this.cAppPath, '+config');
            for k = 1:6
                this.uicHexapodConfigs{k} = mic.config.GetSetNumber(...
                    'cPath', fullfile(this.cConfigPath, sprintf('hex%d.json', k))...
                    );
            end
            
            
            this.uicTemperatureConfig = mic.config.GetSetNumber(...
                    'cPath', fullfile(this.cConfigPath, 'temp.json')...
                    );
            this.uicExposureConfig = mic.config.GetSetNumber(...
                    'cPath', fullfile(this.cConfigPath, 'exposure.json')...
                    );
            
        end
        
        function initUi(this)
            
            
            % Init scalable axes:
            this.hsaAxes = mic.ui.axes.ScalableAxes();
            
            % Init stage device UIs
            for k = 1:length(this.cHexapodAxisLabels)
                this.uiDeviceArrayHexapod{k} = mic.ui.device.GetSetNumber( ...
                    'cName', this.cHexapodAxisLabels{k}, ...
                    'clock', this.clock, ...
                    'cLabel', this.cHexapodAxisLabels{k}, ...
                    'lShowLabels', false, ...
                    'lShowStores', false, ...
                    'lValidateByConfigRange', true, ...
                    'config', this.uicHexapodConfigs{k} ...
                );
            end
            
           
            % Init UI for camera control:
            this.uiDeviceCameraTemperature = mic.ui.device.GetSetNumber( ...
                'cName', 'detector_temp', ...
                'clock', this.clock, ...
                'cLabel', 'Temperature', ...
                'lShowRel', false, ...
                'lShowZero', false, ...
                'lShowLabels', false, ...
                'config', this.uicTemperatureConfig...
            );
            this.uiDeviceCameraExposureTime = mic.ui.device.GetSetNumber( ...
                'cName', 'exposure_time', ...
                'clock', this.clock, ...
                'cLabel', 'Exposure time', ...
                'lShowRel', false, ...
                'lShowZero', false, ...
                'lShowLabels', false, ...
                'config', this.uicExposureConfig...
            );
        
        
            this.uiButtonAcquire = mic.ui.common.Button(...
                'cText', 'Acquire', ...
                'fhDirectCallback', @(~, ~) this.onStartCamera(this.U8CAMERA_MODE_ACQUIRE) ...
            );
            
            this.uiButtonFocus = mic.ui.common.Button(...
                'cText', 'Acquire', ...
                'fhDirectCallback', @(~, ~) this.onStartCamera(this.U8CAMERA_MODE_FOCUS) ...
            );
        
            this.uiButtonStop = mic.ui.common.Button(...
                'cText', 'Acquire', ...
                'fhDirectCallback', @(~, ~)this.onStopCamera ...
            );
        
            this.uipBinning = mic.ui.common.Popup(...
                'cLabel', 'Binning', ...
                'ceOptions', this.ceBinningOptions, ...
                'fhDirectCallback', @(src, evt) this.onBinningChange(src, evt), ...
                'lShowLabel', true ...
            );
             
            
            this.uiButtonSaveImage = mic.ui.common.Button(...
                'cText', 'Save image', ...
                'fhDirectCallback', @this.onSaveImage ...
            );
        
            this.uiButtonSetBackground = mic.ui.common.Button(...
                'cText', 'Set Bkg Image', ...
                'fhDirectCallback', @this.onSetBackground ...
            );
        
            this.uicbSubtractBackground = mic.ui.common.Checkbox('cLabel', 'Subtract background');        
        
        
           
            
            this.uieImageName = mic.ui.common.Edit(...
                'cLabel', 'Image name' ...
            );
        

            
            this.uibHomeHexapod = mic.ui.common.Button(...
                'cText', 'Home Hexapod' , 'fhDirectCallback', @(src,evt)this.homeHexapod ...
            );
            

            this.uiSLHexapod = mic.ui.common.PositionRecaller(...
                'cConfigPath', fullfile(this.cAppPath, '+config'), ...
                'cName', 'Hexapod', ...
                'hGetCallback', @this.getHexapodRaw, ...
                'hSetCallback', @this.setHexapodRaw);
            
           
            
            this.uipbExposureProgress = mic.ui.common.ProgressBar(...
                'dColorFill', [.4, .4, .8], ...
                'dColorBg', [1, 1, 1], ...
                'dHeight', 15, ...
                'dWidth', 455);
            
            
           
          
            % Scans:
            this.ss1D = mic.ui.common.ScanSetup( ...
                            'cLabel', 'Saved pos', ...
                            'ceOutputOptions', this.ceScanOutputLabels, ...
                            'ceScanAxisLabels', this.ceScanAxisLabels, ...
                            'dScanAxes', 1, ...
                            'cName', '1D-Scan', ...
                            'u8selectedDefaults', uint8(1),...
                            'cConfigPath', fullfile(this.cAppPath, '+config'), ...
                            'fhOnScanChangeParams', @(ceScanStates, u8ScanAxisIdx, lUseDeltas, cAxisNames)...
                                                this.updateScanMonitor(ceScanStates, u8ScanAxisIdx, lUseDeltas, cAxisNames, 0), ...
                            'fhOnStopScan', @()this.stopScan, ...
                            'fhOnScan', ...
                                    @(ceScanStates, u8ScanAxisIdx, lUseDeltas, u8ScanOutputDeviceIdx, cAxisNames)...
                                            this.onScan(this.ss1D, ceScanStates, u8ScanAxisIdx, lUseDeltas, u8ScanOutputDeviceIdx, cAxisNames) ...
                        );
                    
            this.ss2D = mic.ui.common.ScanSetup( ...
                            'cLabel', 'Saved pos', ...
                            'ceOutputOptions', this.ceScanOutputLabels, ...
                            'ceScanAxisLabels', this.ceScanAxisLabels, ...
                            'dScanAxes', 2, ...
                            'cName', '2D-Scan', ...
                            'u8selectedDefaults', uint8([1, 2]),...
                            'cConfigPath', fullfile(this.cAppPath, '+config'), ...
                            'fhOnScanChangeParams', @(ceScanStates, u8ScanAxisIdx, lUseDeltas, cAxisNames)...
                                                this.updateScanMonitor(ceScanStates, u8ScanAxisIdx, lUseDeltas, cAxisNames, 0), ...
                            'fhOnStopScan', @()this.stopScan, ...
                            'fhOnScan', ...
                                    @(ceScanStates, u8ScanAxisIdx, lUseDeltas, u8ScanOutputDeviceIdx, cAxisNames)...
                                            this.onScan(this.ss2D, ceScanStates, u8ScanAxisIdx, lUseDeltas, u8ScanOutputDeviceIdx, cAxisNames) ...
                        );
                    
            this.ss3D = mic.ui.common.ScanSetup( ...
                            'cLabel', 'Saved pos', ...
                            'ceOutputOptions', this.ceScanOutputLabels, ...
                            'ceScanAxisLabels', this.ceScanAxisLabels, ...
                            'dScanAxes', 3, ...
                            'cName', '3D-Scan', ...
                            'u8selectedDefaults', uint8([1, 2, 3]),...
                            'cConfigPath', fullfile(this.cAppPath, '+config'), ...
                            'fhOnScanChangeParams', @(ceScanStates, u8ScanAxisIdx, lUseDeltas, cAxisNames)...
                                                this.updateScanMonitor(ceScanStates, u8ScanAxisIdx, lUseDeltas, cAxisNames, 0), ...
                            'fhOnStopScan', @()this.stopScan, ...
                            'fhOnScan', ...
                                    @(ceScanStates, u8ScanAxisIdx, lUseDeltas, u8ScanOutputDeviceIdx, cAxisNames)...
                                            this.onScan(this.ss3D, ceScanStates, u8ScanAxisIdx, lUseDeltas, u8ScanOutputDeviceIdx, cAxisNames) ...
                        );
                    
            this.ssExp1 = ztscontrol.ui.ScanSetupLSI( ...
                            'cLabel', 'Saved pos', ...
                            'ceOutputOptions', this.ceScanOutputLabels, ...
                            'ceScanAxisLabels', this.ceScanAxisLabels, ...
                            'dScanAxes', 2, ...
                            'cName', 'Exp-Scan1', ...
                            'u8selectedDefaults', uint8([9, 10]),...
                            'cConfigPath',fullfile(this.cAppPath, '+config'), ...
                            'fhOnScanChangeParams', @(ceScanStates, u8ScanAxisIdx, lUseDeltas, cAxisNames)...
                                                this.updateScanMonitor(ceScanStates, u8ScanAxisIdx, lUseDeltas, cAxisNames, 0), ...
                            'fhOnStopScan', @()this.stopScan, ...
                            'fhOnScan', ...
                                   @(ceScanStates, u8ScanAxisIdx, lUseDeltas, u8ScanOutputDeviceIdx, cAxisNames)...
                                            this.onScan(this.ssExp1, ceScanStates, u8ScanAxisIdx, lUseDeltas, u8ScanOutputDeviceIdx, cAxisNames) ...
                        );
            
            this.ssExp2 = ztscontrol.ui.ScanSetupLSI( ...
                            'cLabel', 'Saved pos', ...
                            'ceOutputOptions', this.ceScanOutputLabels, ...
                            'ceScanAxisLabels', this.ceScanAxisLabels, ...
                            'dScanAxes', 4, ...
                            'cName', 'Exp-Scan2', ...
                            'u8selectedDefaults', uint8([9, 10, 10, 9]),...
                            'cConfigPath',fullfile(this.cAppPath, '+config'), ...
                            'fhOnScanChangeParams', @(ceScanStates, u8ScanAxisIdx, lUseDeltas, cAxisNames)...
                                                this.updateScanMonitor(ceScanStates, u8ScanAxisIdx, lUseDeltas, cAxisNames, 0), ...
                            'fhOnStopScan', @()this.stopScan, ...
                            'fhOnScan', ...
                                   @(ceScanStates, u8ScanAxisIdx, lUseDeltas, u8ScanOutputDeviceIdx, cAxisNames)...
                                            this.onScan(this.ssExp2, ceScanStates, u8ScanAxisIdx, lUseDeltas, u8ScanOutputDeviceIdx, cAxisNames) ...
                        );
                    
            % Scan setup callback triggers.  Used when tabgroup changes tab
            % focus
            ceScanCallbackTriggers = ...
                {@()this.ss1D.triggerCallback(), ...
                 @()this.ss2D.triggerCallback(), ...
                 @()this.ss3D.triggerCallback(), ...
                 @()this.ssExp1.triggerCallback(), ...
                 @()this.ssExp2.triggerCallback()};
             
            % Scan tab group:
            this.uitgScan = mic.ui.common.Tabgroup('ceTabNames', this.ceTabList, ...
                                                    'fhDirectCallback', ceScanCallbackTriggers);
            % Axes tab group:
            this.uitgAxes = mic.ui.common.Tabgroup('ceTabNames', ...
                {'Camera', 'Scan monitor', 'Scan output', 'Fiducialized moves'});
           
            
            % Scan progress text elements:
            dStatusFontSize = 14;
            this.uiTextStatus = mic.ui.common.Text(...
                'cLabel', 'Status', ...
                'lShowLabel', true, ...
                'dFontSize', dStatusFontSize, ... 
                'cFontWeight', 'bold', ...
                'cVal', ' ' ...
                );
            this.uiTextTimeElapsed = mic.ui.common.Text(...
                'cLabel', 'Elapsed', ...
                'lShowLabel', true, ...
                'dFontSize', dStatusFontSize, ... 
                'cFontWeight', 'bold', ...
                'cVal', ' ' ...
                );
            this.uiTextTimeRemaining = mic.ui.common.Text(...
                'cLabel', 'Remaining', ...
                'lShowLabel', true, ...
                'dFontSize', dStatusFontSize, ... 
                'cFontWeight', 'bold', ...
                'cVal', ' ' ...
                );
            this.uiTextTimeComplete = mic.ui.common.Text(...
                'cLabel', 'Complete', ...
                'lShowLabel', true, ...
                'cFontWeight', 'bold', ...
                'cVal', ' ' ...
                );
            this.uiTextTimeComplete.setFontSize(dStatusFontSize);
            this.uiTextTimeElapsed.setFontSize(dStatusFontSize);
            this.uiTextTimeRemaining.setFontSize(dStatusFontSize);
            this.uiTextStatus.setFontSize(dStatusFontSize);
            
            
           
            
            
        end
        

%% INITIALIZE HARDWARE DEVICES

        
        
        
       
        
        function initClock(this)
            this.clock = mic.Clock('app');
        end
        
        function initAndConnectPixis(this, device)
            
            % Direct Java api:
            device = this.hardware.getCamera();
            
            % Translated API
            this.apiCamera = ztscontrol.javaAPI.APIPVCam( ...
                'hDevice', device, ...
                'fhWhileAcquiring', @(elapsedTime)this.whileAcquiring(elapsedTime), ...
                'fhOnImageReady', @(data)this.onCameraImageReady(data) ...
                );
            
            % connect to camera
            this.apiCamera.connect();
            
            % Link UI to devices, let's try to inline them:
            this.uiDeviceCameraTemperature.setDevice(...
                 ztscontrol.device.InlineGetSetDevice(...
                    'get', @()this.apiCamera.getTemperature(), ...
                    'set', @(dVal)this.apiCamera.setTemperature(dVal) ...
                 )...
            );
            this.uiDeviceCameraTemperature.turnOn();
            this.uiDeviceCameraTemperature.syncDestination()
            
            this.uiDeviceCameraExposureTime.setDevice(...
                 ztscontrol.device.InlineGetSetDevice(...
                    'get', @()this.apiCamera.getExposureTime(), ...
                    'set', @(dVal)this.apiCamera.setExposureTime(dVal) ...
                 )...
            );
            this.uiDeviceCameraExposureTime.turnOn();
            this.uiDeviceCameraExposureTime.syncDestination();
        
        end
        
        % Resets api, bridges, and disconnects hardware device.
        function destroyAndDisconnectPixis(this)
            
            this.uiDeviceCameraTemperature.turnOff();
            this.uiDeviceCameraTemperature.setDevice([]);
            
            this.uiDeviceCameraExposureTime.turnOff();
            this.uiDeviceCameraExposureTime.setDevice([]);
            
            % Disconnect the camera:
            this.apiCamera.disconnect();
            
            % Delete the Stage API
            this.apiCamera = [];
        end
        
        

        % Builds hexapod java api, connecting getSetNumber UI elements
        % to the appropriate API hooks.  Device is already connected
        function initAndConnectSpaceFab(this)
            
            % Direct Java api:
            device = this.hardware.getHexapod();
            
            % Instantiate javaStageAPIs for communicating with devices
            this.apiHexapod 	= ztscontrol.javaAPI.CXROJavaStageAPI(...
                                  'jStage', device);
           
            % Check if we need to index stage:
            if (~this.apiHexapod.isInitialized())
                if strcmp(questdlg('Hexapod is not referenced. Index now?'), 'Yes')
                    this.apiHexapod.home();
                     % Wait till hexapod has finished move:
                    dafHexapodHome = mic.DeferredActionScheduler(...
                        'clock', this.clock, ...
                        'fhAction', @()this.setHexapodDeviceAndEnable(device),...
                        'fhTrigger', @()this.apiHexapod.isInitialized(),...
                        'cName', 'DASHexapodIndexing', ...
                        'dDelay', 0.5, ...
                        'dExpiration', 10, ...
                        'lShowExpirationMessage', true);
                    dafHexapodHome.dispatch();
                
                end
                return % Return in either case, only proceed if initialized
            end
            
            % Use coupled-axis bridge to create single axis control
            dSubR = [0 -1 0 ; -1 0 0; 0 0 1];
            dHexapodR = [dSubR, zeros(3); zeros(3), dSubR];  
            for k = 1:6
                this.oHexapodBridges{k} = ztscontrol.device.CoupledAxisBridge(this.apiHexapod, k, 6);
                this.oHexapodBridges{k}.setR(dHexapodR);
                this.uiDeviceArrayHexapod{k}.setDevice(this.oHexapodBridges{k});
                this.uiDeviceArrayHexapod{k}.turnOn();
                this.uiDeviceArrayHexapod{k}.syncDestination();
            end
        end
        
        % Resets api, bridges, and disconnects hardware device.
        function destroyAndDisconnectSpaceFab(this)
            for k = 1:6
                this.oHexapodBridges{k} = [];
                this.uiDeviceArrayHexapod{k}.turnOff();
                this.uiDeviceArrayHexapod{k}.setDevice([]);
            end
            
            % Disconnect the stage:
            this.apiHexapod.disconnect();
            
            % Delete the Stage API
            this.apiHexapod = [];
        end
        
        
        
        
%% IMAGE ACQUISITION
        

        % Callback for what to do when image is ready from camera
        function onCameraImageReady(this, data)
            
            if this.uicbSubtractBackground.get() && ...
                    size(data, 1) == size(this.dBackgroundImage, 1) && ...
                        size(data, 2) == size(this.dBackgroundImage, 2)
                this.hsaAxes.imagesc(data - this.dBackgroundImage);
            else
                this.hsaAxes.imagesc(data);
            end
            
            % If focusing, don't bother to reset buttons or save image:
            if this.apiCamera.lIsFocusing
                return
            end
            
            % If we're scanning and flagged to save series route to scan saver
            if (this.lIsScanning)
                if this.lSaveImagesInScan
                    this.saveImageInSeries();
                end
                
                % Either way, notify that we are done acquiring:
                 this.lIsScanAcquiring = false;
            end
            
            
            this.uiButtonAcquire.setText('Acquire');
            this.uiButtonAcquire.setColor(this.dAcquireColor);
            this.uiButtonFocus.setText('Focus');
            this.uiButtonFocus.setColor(this.dFocusColor);
            this.uiButtonStop.setColor(this.dInactiveColor);
            
            this.uipbExposureProgress.set(1);
            this.uipbExposureProgress.setColor([.2, .8, .2]);
            
            % update image name:
            [path, nPNGs] = this.getDataSubdirectoryPath();
            
            cFileName = fullfile(path, sprintf('%0.4d.png', nPNGs + 1));
            [~, name, ext] = fileparts(cFileName);
            
            this.uieImageName.set([name, ext]);
            this.uiButtonSaveImage.setColor([.1, .9, .3]);
        end
        
        
        % Callback for what to do while acquisition is happening
        function whileAcquiring(this, dElapsedTime)
            dProgress = dElapsedTime/(this.apiCamera.getExposureTime() + this.apiCamera.dAcquisitionDelay);
            if dProgress > 1
                dProgress = 1;
            end
            this.uipbExposureProgress.set(dProgress);
        end
        
        
        % Called to begin an acquisition or a focus start.  
        function onStartCamera(this, u8mode)
            if isempty(this.apiCamera)
                msgbox('No camera connected!');
                return
            end
            
            % If already busy, then do nothing
            if this.apiCamera.lIsAcquiring || this.apiCamera.lIsFocusing
                fprintf('(LSI-control) Not starting acquire because camera is already busy');
                return
            end
            
            this.uiButtonAcquire.setText('...')
            this.uiButtonAcquire.setColor(this.dInactiveColor);
            this.uiButtonFocus.setText('...')
            this.uiButtonFocus.setColor(this.dInactiveColor);
            this.uiButtonStop.setColor(this.dDisableColor);
            this.uipbExposureProgress.set(0);
            
           
            switch u8mode
                case this.U8CAMERA_MODE_ACQUIRE
                    this.uipbExposureProgress.setColor([.4, .4, .8]);
                    this.apiCamera.requestAcquisition();
                    
                case this.U8CAMERA_MODE_FOCUS
                    this.uipbExposureProgress.setColor([.9, .74, .9]);
                    this.apiCamera.startFocus();
            end
            
            % When image is ready, it will be handled by this.onCameraImageReady
        end
        
        % Call this to abort acquisition or focus gracefully.
        function onStopCamera(this)
            
            % Check if there's anything to stop:
            if (~this.apiCamera.lIsFocusing) && (~this.apiCamera.lIsAcquiring)
                fprintf('(LSI-control) Nothing to stop because camera is idle');
                return
            end
            % Abort acquisition:
            if this.apiCamera.lIsFocusing
                this.apiCamera.stopFocus();
            else
                this.apiCamera.abortAcquisition();
            end
            
            this.apiCamera.stopFocus();
            this.uiButtonFocus.setText('Focus');
            this.uiButtonFocus.setColor(this.dAcquireColor);
            this.uiButtonAcquire.setText('Acquire');
            this.uiButtonAcquire.setColor(this.dFocusColor);
            this.uiButtonStop.setColor(this.dInactiveColor);
            
            this.uipbExposureProgress.set(0);
            
            
            
        end
        
        
        % Callback for the save button
        function saveImageInSeries(this)
            dImg = this.apiCamera.dCurrentImage;
            dIdx = this.scanHandler.getCurrentStateIndex();
            
            % Path to the date folder:
            path = this.getDataSubdirectoryPath();
            
            seriesPath = fullfile(path, 'series');
            if exist(seriesPath, 'dir') ~= 7
                mkdir(seriesPath);
            end
            
            thisSeriesPath = fullfile(seriesPath, sprintf('series_%0.3d', this.dImageSeriesNumber));
            if exist(thisSeriesPath, 'dir') ~= 7
                mkdir(thisSeriesPath);
            end
            
            cFileName = sprintf('%s-%0.3d-%0.4d', datestr(now,'yyyymmdd'), this.dImageSeriesNumber, dIdx);
                        
            this.saveAndLogImage(thisSeriesPath, seriesPath, cFileName, dImg);
        end
            
            
        % Callback for the save button
        function onSaveImage(this, ~, ~)
            % Check if image is ready:
            if ~this.apiCamera.lIsImageReady || isempty(this.apiCamera.dCurrentImage)
                msgbox('No image available');
                return
            end
            dImg = this.apiCamera.dCurrentImage;
            
            cFileName = this.uieImageName.get();
            
            path = this.getDataSubdirectoryPath();
           
            this.saveAndLogImage(path, path, cFileName, dImg);
            
            % Change progress bar color to indicate image has been saved
            this.uipbExposureProgress.set(0);
            this.uipbExposureProgress.setColor([.95, .95, .95]);
            this.uiButtonSaveImage.setColor(this.dInactiveColor);
        end
        
        
        function onSetBackground(this, ~, ~)
            this.dBackgroundImage = this.apiCamera.dCurrentImage;
            this.uiButtonSetBackground.setColor([.6, .6, .7]);
        end
        
        % get data subdirectory
        function [path, nPNGs] = getDataSubdirectoryPath(this)
            % Today's date:
            cSubDirName = datestr(now, 29);
            
            sFils = dir(this.cDataPath);
            lDataFolderExist = false;
            for k = 1:length(sFils)
                if strcmp(sFils(k).name, cSubDirName)
                    lDataFolderExist = true;
                end
            end
            path = fullfile(this.cDataPath, cSubDirName);
            if ~lDataFolderExist
                mkdir(path);
            end
            
            nPNGs = length(dir(fullfile(path, '*.png')));
        end
        
        function stLog = getHardwareLogs(this)
            % Make log structure:
            stLog = struct();
            
            % Add timestamp
            stLog.timeStamp = datestr(now, 31);
            
            stLog.fileName = [];
            
            % Add Hexapod coordinates:
            if isempty(this.apiHexapod)
                stLog.hexapodX = 'off';
                stLog.hexapodY = 'off';
                stLog.hexapodZ = 'off';
                stLog.hexapodRx = 'off';
                stLog.hexapodRy = 'off';
                stLog.hexapodRz = 'off';
            else 
                dHexapodPositions = this.getHexapodRaw();
                stLog.hexapodX = sprintf('%0.6f', dHexapodPositions(1));
                stLog.hexapodY = sprintf('%0.6f', dHexapodPositions(2));
                stLog.hexapodZ = sprintf('%0.6f', dHexapodPositions(3));
                stLog.hexapodRx = sprintf('%0.6f', dHexapodPositions(4));
                stLog.hexapodRy = sprintf('%0.6f', dHexapodPositions(5));
                stLog.hexapodRz = sprintf('%0.6f', dHexapodPositions(6));
            end
            
           
            
            % Add temperature and exposure times:
            if isempty(this.apiCamera)
                stLog.cameraTemp = 'off';
                stLog.cameraExposureTime = 'off'; 
            else
                stLog.cameraTemp = sprintf('%0.1f', this.apiCamera.getTemperature());
                stLog.cameraExposureTime = sprintf('%0.4f', this.apiCamera.getExposureTime()); 
            end
            
           
           
            
        end
        
        
        function [fid, isCreated] = openOrCreateFile(this, fullFilePath)
            [d p e] = fileparts(fullFilePath);
            
            % Check if dir exists:
            saFls = dir(d);
            if isempty(saFls)
                % make the dir:
                mkdir(d);
            end
            
            % now check if a file exists:
            fid = fopen(fullFilePath, 'r');
            
            if (fid == -1)
                isCreated = true;
            else
                fclose(fid);
                isCreated = false;
            end
            fid = fopen(fullFilePath, 'a');
            
        end
        
        % When an image is saved, make sure to log it
        function saveAndLogImage(this, cSubDirPath, cLogPath, cFileName, dImg) %#ok<INUSD>
            
            % Poll hardware for current values
            stLog = this.getHardwareLogs();
            stLog.fileName = cFileName;
            if this.lIsScanning
                
                stLog.scanIndex = sprintf('%d', this.scanHandler.getCurrentStateIndex());
                stLog.seriesIndex = sprintf('%d', this.dImageSeriesNumber);
                stLog.scanAxes = strjoin(this.ssCurrentScanSetup.getScanAxisNames(), '-');
                stLog.scanOutput = this.ssCurrentScanSetup.getOutputName();
%             else
%                 stLog.scanIndex = 0;
%                 stLog.scanAxes = 'N/A';
%                 stLog.scanOutput = 'N/A';
            end
            
            % Get field names for log, create/open file and log
            ceFieldNames = fieldnames(stLog);
            
            cDateStr = datestr(now, 'yyyy-mm-dd-');
            if this.lIsScanning
                 [fid, isNewLogFile] = this.openOrCreateFile( fullfile(cLogPath, [cDateStr 'scanlog.csv']));
            else
                [fid, isNewLogFile] = this.openOrCreateFile( fullfile(cLogPath, [cDateStr 'log.csv']));
            end
            
            cWriteStr = '';
            % If new log, write headers:
            nl = java.lang.System.getProperty('line.separator').char;
            if isNewLogFile
                for k = 1:length(ceFieldNames)
                    cWriteStr = sprintf('%s%s,',cWriteStr, ceFieldNames{k});
                end
                cWriteStr(end) = [];
                cWriteStr = [cWriteStr nl];
            end
            
            % Write structure fields
            for k = 1:length(ceFieldNames)
                cWriteStr = sprintf('%s%s,', cWriteStr, stLog.(ceFieldNames{k}));
            end
            cWriteStr(end) = [];
            cWriteStr = [cWriteStr nl];
            fwrite(fid, cWriteStr);
            fclose(fid);

            % Prepare background subtracted image:
            if size(dImg,1) == size(this.dBackgroundImage,1) && size(dImg,2) == size(this.dBackgroundImage,2)
                dImgBk = dImg - this.dBackgroundImage;
            else
                dImgBk = dImg;
            end
            
            % Save .mat file
            [~, fl, ext] = fileparts(cFileName);
            save(fullfile(cSubDirPath, [fl '.mat']), 'stLog', 'dImg', 'dImgBk');
            
            % Scale dImg to 255 for png
            dImgSc = floor(dImg/256);
            imwrite(dImgSc, fullfile(cSubDirPath, cFileName), 'png');
        end
        
        function onBinningChange(this, src, ~)
            this.apiCamera.setBinning(src.getSelectedValue);
        end
        
 %% FIDUCIALIZED MOVES

       

 
 %% POSITION RECALL Stage direct access get/set

      
        
        function syncHexapodDestinations(this)
         % Sync edit boxes
            for k = 1:length(this.cHexapodAxisLabels)
                this.uiDeviceArrayHexapod{k}.syncDestination();
            end
        end
       
        
        
        % Sets the raw positions to hexapod.  Used as a handler for
        % PositionRecaller
        function setHexapodRaw(this, positions) 
            
            if ~isempty(this.apiHexapod)
                % Set hexapod positions to saved values
                this.apiHexapod.setAxesPosition(positions);

                % Wait till hexapod has finished move:
                dafHexapodMoving = mic.DeferredActionScheduler(...
                    'clock', this.clock, ...
                    'fhAction', @()this.syncHexapodDestinations(),...
                    'fhTrigger', @()this.apiHexapod.isReady(),...
                    'cName', 'DASHexapodMoving', ...
                    'dDelay', 1, ...
                    'dExpiration', 10, ...
                    'lShowExpirationMessage', true);
                dafHexapodMoving.dispatch();
            else
                % If Hexapod is not connected, set GetSetNumber UIs:
                for k = 1:length(positions)
                    this.uiDeviceArrayHexapod{k}.setDestRaw(positions(k));
                    this.uiDeviceArrayHexapod{k}.moveToDest();
                end
            end
        end
        
        % Gets the raw positions from hexapod.  Used as a handler for 
        % PositionRecaller
        function positions = getHexapodRaw(this)
             if ~isempty(this.apiHexapod)
                positions = this.apiHexapod.getAxesPosition();
             else % get virtual positions from GetSetNumber UIs:
                 for k = 1:length(this.uiDeviceArrayHexapod)
                     positions(k) = this.uiDeviceArrayHexapod{k}.getDestRaw(); %#ok<AGROW>
                 end
             end
        end
        



%% SCAN METHODS

% State array needs to be structure with property values
        function dInitialState = getInitialState(this, u8ScanAxisIdx)
             % grab initial state of values:
            dInitialState = struct;
            dInitialState.values = [];
            dInitialState.axes = u8ScanAxisIdx;
            
            % validate start conditions and get initial state
            for k = 1:length(u8ScanAxisIdx)
                dAxis = double(u8ScanAxisIdx(k));
                switch dAxis
                    case {1, 2, 3, 4, 5, 6} % Hexapod
                        if isempty(this.apiHexapod)
                            fprintf('Hexapod is not connected\n')
                            dInitialState.values(k) = 0;
                            continue
%                             return
                        end
                        
                        dUnit =  this.uiDeviceArrayHexapod{dAxis}.getUnit().name;
                        dInitialState.values(k) = this.uiDeviceArrayHexapod{dAxis}.getValCal(dUnit);
                        
                    case {7, 8} % Goni
                        if isempty(this.apiGoni)
                            fprintf('Goni is not connected\n')
                            dInitialState.values(k) = 0;
                            continue
%                             return
                        end
                        dUnit =  this.uiDeviceArrayGoni{dAxis}.getUnit().name;
                        dInitialState.values(k) = this.uiDeviceArrayGoni{dAxis - 6}.getValCal(dUnit);
                        
                    case {9, 10, 11, 12, 13, 14, 15} % Reticle
%                         if isempty(this.apiReticle)
%                             msgbox('Reticle is not connected\n')
%                             dInitialState.values(k) = 0;
%                             continue
%                             return
%                         end
                        
                        dUnit =  this.uiDeviceArrayReticle{dAxis - 8}.getUnit().name;
                        dInitialState.values(k) = this.uiDeviceArrayReticle{dAxis - 8}.getValCal(dUnit);
                        
                    case {16, 17, 18} % Wafer
                        dUnit =  this.uiDeviceArrayWafer{dAxis - 15}.getUnit().name;
                        dInitialState.values(k) = this.uiDeviceArrayWafer{dAxis - 15}.getValCal(dUnit);
                    case 19 % "do nothing"
                        dInitialState.values(k) = 1;
                        
                end
            end
            
        end
        
        function onScan(this, ssScanSetup, stateList, u8ScanAxisIdx, lUseDeltas, u8OutputIdx, cAxisNames)
            
            % If already scanning, then stop:
            if(this.lIsScanning)
                return
            end
                
            dInitialState = this.getInitialState(u8ScanAxisIdx);
            % Save this state:
            this.stLastScanState = dInitialState;

            
            % If using deltas, modify state to center around current
            % values:
            for m = 1:length(u8ScanAxisIdx)
                if lUseDeltas(m)
                    for k = 1:length(stateList)
                        stateList{k}.values(m) = stateList{k}.values(m) + dInitialState.values(m);
                    end
                end
            end
            
            % validate output conditions
            switch u8OutputIdx
                case {1, 2, 3, 4, 11} % Camera output
                   if isempty(this.apiCamera)
                       msgbox('No Camera available for image acquisition')
                       return
                   end
            end
            
   
            
            % Set series number:
            
            switch u8OutputIdx
                case {1, 4, 11} % Any time image series should be saved
                   if isempty(this.apiCamera)
                       msgbox('No Camera available for image acquisition')
                       return
                   end
                   this.dImageSeriesNumber = this.dImageSeriesNumber + 1;
                   this.lSaveImagesInScan = true;
                   
                otherwise
                   this.lSaveImagesInScan = false;
            end
            
            
            % Build "scan recipe" from scan states 
            stRecipe.values = stateList; % enumerable list of states that can be read by setState
            stRecipe.unit = struct('unit', 'unit'); % not sure if we need units really, but let's fix later
                        
            fhSetState      = @(stUnit, stState) this.setScanAxisDevicesToState(stState);
            fhIsAtState     = @(stUnit, stState) this.areScanAxisDevicesAtState(stState);
            fhAcquire       = @(stUnit, stState) this.scanAcquire(u8OutputIdx, stateList, u8ScanAxisIdx, lUseDeltas, cAxisNames);
            fhIsAcquired    = @(stUnit, stState) this.scanIsAcquired(stState, u8OutputIdx);
            fhOnComplete    = @(stUnit, stState) this.onScanComplete(dInitialState, fhSetState);
            fhOnAbort       = @(stUnit, stState) this.onScanAbort(dInitialState, fhSetState, fhIsAtState);
            dDelay          = 0.05;
            % Create a new scan:
            this.scanHandler = mic.Scan('LSI-control-scan', ...
                                        this.clock, ...
                                        stRecipe, ...
                                        fhSetState, ...
                                        fhIsAtState, ...
                                        fhAcquire, ...
                                        fhIsAcquired, ...
                                        fhOnComplete, ...
                                        fhOnAbort, ...
                                        dDelay...
                                        );
            
            % Start scanning
            this.setupScanOutput(stateList, u8ScanAxisIdx)
            this.lIsScanning = true;
            this.ssCurrentScanSetup = ssScanSetup;
            this.scanHandler.start();
        end
        
        function stopScan(this)
            
            this.scanHandler.stop();
            this.lIsScanning = false;
            this.lIsConjugateLockEnabled = false;
            this.dInitialHSSZValue = 0;
            this.dInitialRetZValue = 0;
        end
        
        function updateScanProgress(this)
            stScanProgress = this.scanHandler.getStatus();
            
            % Scan progress text elements:
            this.uiTextStatus.set(sprintf('%0.1f %%', stScanProgress.dProgress * 100) );
            this.uiTextTimeElapsed.set(sprintf('%s', stScanProgress.cTimeElapsed));
            this.uiTextTimeRemaining.set(sprintf('%s', stScanProgress.cTimeRemaining) );
            this.uiTextTimeComplete.set(sprintf('%s', stScanProgress.cTimeComplete) );
             
        end
        
        % Sets device to enumerated state
        function setScanAxisDevicesToState(this, stState)
            dAxes = stState.axes;
            dVals = stState.values;
            
            % For coupled-axis stages, we need to defer movement till at
            % the end to avoid multiple commands to same stage when
            % stage is not ready yet
            
            % find out if hexapod is moving
            lDeferredHexapodMove = false;
            lDeferredGoniMove = false;
            for k = 1:length(dAxes)
                switch dAxes(k)
                    case {1, 2, 3, 4, 5, 6} % Hexapod
                        lDeferredHexapodMove = true;
                    case {7, 8} % Goni
                        lDeferredGoniMove = true;
                end
            end
            
            if lDeferredHexapodMove
                dPosHexRaw = zeros(6,1);
                for k = 1:6
                    dPosHexRaw(k) = this.uiDeviceArrayHexapod{k}.getValRaw();  %#ok<AGROW>
                end
            end
            if lDeferredGoniMove
                dPosGoniRaw = zeros(2,1);
                for k = 1:2
                    dPosGoniRaw(k) = this.uiDeviceArrayGoni{k}.getValRaw(); %#ok<AGROW>
                end
            end
            
            
            for k = 1:length(dAxes)
                dVal = dVals(k);
                dAxis = dAxes(k);
                switch dAxis
                    case {1, 2, 3, 4, 5, 6} % Hexapod
                        this.uiDeviceArrayHexapod{dAxis}.setDestCal(dVal);
                        dPosHexRaw(dAxis) = this.uiDeviceArrayHexapod{dAxis}.getDestRaw();
                    case {7, 8} % Goni
                        this.uiDeviceArrayGoni{dAxis - 6}.setDestCal(dVal);
                        dPosHexRaw(dAxis - 6) = this.uiDeviceArrayHexapod{dAxis - 6}.getDestRaw();
                    case {9, 10, 11, 12, 13, 14, 15} % Reticle
                        this.uiDeviceArrayReticle{dAxis - 8}.setDestCal(dVal);
                        this.uiDeviceArrayReticle{dAxis - 8}.moveToDest();
                    case {16, 17, 18, 19} % "wafer"
                        this.uiDeviceArrayWafer{dAxis - 15}.setDestCal(dVal);
                        this.uiDeviceArrayWafer{dAxis - 15}.moveToDest();
                    case 20 % do nothing
                       
                end
            end
            
            if this.lIsConjugateLockEnabled
                % correct Reticle Z 
                dCurrentHSSZValue = this.hardware.getMfDriftMonitorMiddleware().getSimpleZ(200);
                dGratingOffset = dCurrentHSSZValue - this.dInitialHSSZValue;
                if (dGratingOffset > 1.5) %nm
                    dRetOffset = dGratingOffset * 25 * 1e-6; % nm
                    dNewRetConjugateLockedPos = this.dInitialRetZValue - dRetOffset;
                    this.uiDeviceArrayReticle{3}.setDestCal(dNewRetConjugateLockedPos);
                    this.uiDeviceArrayReticle{3}.moveToDest();
                end
            end
            
            if lDeferredHexapodMove
                this.uiDeviceArrayHexapod{1}.getDevice().moveAllAxesRaw(dPosHexRaw);
            end
            if lDeferredGoniMove
                this.uiDeviceArrayGoni{1}.getDevice().moveAllAxesRaw(dPosGoniRaw);
            end
            
        end
        
        % For isAtState, we assume that if the device is ready then it is
        % at state, since closed loop control is performed in device
        function isAtState = areScanAxisDevicesAtState(this, stState)
            
            dAxes = stState.axes;
            
            for k = 1:length(dAxes)
                dAxis = dAxes(k);
                switch dAxis
                    case {1, 2, 3, 4, 5, 6} % Hexapod
                        if ~this.apiHexapod.isReady()
                            isAtState = false;
                            return
                        end
                    case {7, 8} % Goni
                        if ~this.apiGoni.isReady()
                            isAtState = false;
                            return
                        end
                    case {9, 10, 11, 12, 13, 14, 15} % Reticle
                        
                        % Use isready: ------------------------
%                         retAxis = dAxis - 8;
%                         if this.uiDeviceArrayReticle{retAxis}.getDevice().isReady()
%                             fprintf('(LSI-control) scan: Reticle axis is ready\n');
%                             isAtState = true;
%                             return
%                         else
%                             isAtState = false;
%                             return
%                         end
                        
                        % Use eps tol ----------------------------
                        dUnit           = this.uiDeviceArrayReticle{dAxis - 8}.getUnit().name;
                        dCommandedDest  = this.uiDeviceArrayReticle{dAxis - 8}.getDestCal(dUnit);
                        dAxisPosition   = this.uiDeviceArrayReticle{dAxis - 8}.getValCal(dUnit);
                        dEps            = abs(dCommandedDest - dAxisPosition);
                        fprintf('Commanded destination: %0.3f, Actual pos: %0.3f, eps: %0.4f\n', ...
                            dCommandedDest, dAxisPosition, dEps);
                        dTolerance = 0.004; % scan unit assumed to be mm here
                        if dEps > dTolerance
                            fprintf('Reticle is not within tolerance\n');
                            isAtState = false;
                            return
                        end
    
                    case {16, 17, 18, 19}
                        
                         % Use isready: ------------------------
%                         wafAxis = dAxis - 15;
%                         if this.uiDeviceArrayReticle{wafAxis}.getDevice().isReady()
%                             fprintf('(LSI-control) scan: Wafer axis is ready\n');
%                             isAtState = true;
%                             return
%                         else
%                             isAtState = false;
%                             return
%                         end

                        % Use eps tol ----------------------------
                        dUnit           = this.uiDeviceArrayWafer{dAxis - 15}.getUnit().name;
                        dCommandedDest  = this.uiDeviceArrayWafer{dAxis - 15}.getDestCal(dUnit);
                        dAxisPosition   = this.uiDeviceArrayWafer{dAxis - 15}.getValCal(dUnit);
                        dEps            = abs(dCommandedDest - dAxisPosition);
                        fprintf('Commanded destination: %0.3f, Actual pos: %0.3f, eps: %0.4f\n', ...
                            dCommandedDest, dAxisPosition, dEps);
                        dTolerance = 0.004; % scan unit assumed to be mm here
                        if dEps > dTolerance
                            fprintf('Wafer is not within tolerance\n');
                            isAtState = false;
                            return
                        end
                  
                        
                    case 20 % "do nothing"
                        isAtState = true;
                            return
                end
            end
            
            isAtState = true;
        end
        
        function scanAcquire(this, outputIdx, stateList, u8ScanAxisIdx, lUseDeltas, cAxisNames)
           
            % Notify scan progress that we are at state idx: u8Idx:
            u8Idx = this.scanHandler.getCurrentStateIndex();
            this.updateScanMonitor(stateList, u8ScanAxisIdx, lUseDeltas, cAxisNames, u8Idx);
            
            % Notify progress monitor
            this.updateScanProgress();
                        

            
            % outputIdx: {'Image capture', 'Image intensity', 'Line Contrast', 'Line Pitch', 'Pause 2s'}
            switch outputIdx
                case {1, 2, 3, 4} % Image caputre
                    
                    % If this a 3D scan using image capture, assume new series 
                    % should be created with each move of top axis
                    if length(u8ScanAxisIdx) == 3 && double(u8Idx) ~= 1
                        % Check if axis 1 has changed:
                        if this.stLastScanState.values(1) ~= stateList{u8Idx}.values(1)
                            % update series number:
                            this.dImageSeriesNumber = this.dImageSeriesNumber + 1;
                            
                            
                        end
                        
                    end
                    
                     % flag that a "scan acquisition" has commenced:
                    this.lIsScanAcquiring = true;
            
                    this.onStartCamera(this.U8CAMERA_MODE_ACQUIRE);
                    % This will call image capture and then save
                    
                case 5 % pause
                    pause(2);
                    
                    % Flag that we are finished
                    this.lIsScanAcquiring = false;
            end
            
            % Set this state as the last scan state:
            this.stLastScanState = stateList{u8Idx};
            
        end
        
        function lAcquisitionFinished = scanIsAcquired(this, stState, outputIdx)
            % outputIdx: {'Image capture', 'Image intensity', 'Line Contrast', 'Line Pitch'}
            
            % Each output should have a value to plot
            dAcquiredValue = 1;
            
            switch outputIdx
                case {1, 2, 3, 4, 11} % Image caputre
                    % For getting image data, Scan is done acquiring when
                    % we set the lIsScanAcquiring boolean to false in
                    % 'onSaveImage'
                    
                    lAcquisitionFinished = ~this.lIsScanAcquiring;
                case 5 % pause
                    dAcquiredValue = rand(1);
                    lAcquisitionFinished = ~this.lIsScanAcquiring;
                case 6 % wafer dose diode
                    
%                     dAcquiredValue = this.apiWaferDoseMonitor.read(2);
                    dAcquiredValue = this.uiDoseMonitor.getValRaw();
                    lAcquisitionFinished = ~this.lIsScanAcquiring;
                    
                case 7 % HS Simple Z
                    dAcquiredValue = this.uiHSSimpleZ.getValRaw();
                    lAcquisitionFinished = ~this.lIsScanAcquiring;
                    
                case {8, 9, 10} % HS Cal Z, Rx, Ry
                    dHSChannel = 11 - outputIdx;
                    dAcquiredValue = this.hardware.getMfDriftMonitorMiddleware().getHSValue(dHSChannel);
                    lAcquisitionFinished = ~this.lIsScanAcquiring;
                    
            end
            
            % When scan is finished, process results:
            if lAcquisitionFinished
                u8Idx = this.scanHandler.getCurrentStateIndex();
                
                
                switch outputIdx
                    case 2 % Grab camera image and integrate intensity:
                        dImg = this.apiCamera.getImage();
                        dAcquiredValue = sum(dImg(:));
                        
                    case 3 % Integrated background diff
                        dImg = this.apiCamera.getImage();
                        
                        if this.uicbSubtractBackground.get() && ...
                                size(dImg, 1) == size(this.dBackgroundImage, 1) && ...
                                size(dImg, 2) == size(this.dBackgroundImage, 2)
                            dImg = dImg - this.dBackgroundImage;
                        end
                        
                        % Get contrast here:
                        dAcquiredValue = sum(abs(dImg(:)));
                    case 4 % Line pitch
                        dImg = this.apiCamera.getImage();
                        
                        % Get Pitch here:
                        dAcquiredValue = sum(dImg(:));
                end
                
                
                % Send plottable values to scanOutputHandler
                this.handleUpdateScanOutput(u8Idx, stState, dAcquiredValue)
            end
            
        end
        
        function onScanComplete(this, dInitialState, fhSetState)
            this.lIsScanning = false;
            this.lIsConjugateLockEnabled = false;
            this.dInitialHSSZValue = 0;
            this.dInitialRetZValue = 0;
            
            % Reset to initial state on complete
            fhSetState([], dInitialState);
            
            % Reset scan setup pointer:
            this.ssCurrentScanSetup = {};
        end
        
        function onScanAbort(this, dInitialState, fhSetState, fhIsAtState)
            this.lIsScanning = false;
            this.lIsConjugateLockEnabled = false;
            this.dInitialHSSZValue = 0;
            this.dInitialRetZValue = 0;
            
            % Reset to inital state on abort, but wait for scan to complete
            % current move before resetting:
            dafScanAbort = mic.DeferredActionScheduler(...
                        'clock', this.clock, ...
                        'fhAction', @()fhSetState([], dInitialState),...
                        'fhTrigger', @()fhIsAtState([], dInitialState),... % Just needs a dummy state here
                        'cName', 'DASScanAbortReset', ...
                        'dDelay', 0.5, ...
                        'dExpiration', 10, ...
                        'lShowExpirationMessage', true);
            dafScanAbort.dispatch();

            % Reset scan setup pointer:
            this.ssCurrentScanSetup = {};
        end
        
        % Sets up scan output axis to plot the results of a 1-dim or 2-dim
        % scan
        function setupScanOutput(this, stateList, u8ScanAxisIdx)
            this.dNumScanOutputAxes = length(u8ScanAxisIdx);
            this.dLinearScanOutput = zeros(1, length(stateList));
            
            dAxisValues = zeros(length(stateList), length(u8ScanAxisIdx));
            % Assemble all state values for each axis:
            for k = 1:length(stateList)
                dAxisValues(k,:) = stateList{k}.values;
            end
            % sort each column:
            dAxisValues = sort(dAxisValues);
            
            this.ceScanCoordinates = cell(1, length(u8ScanAxisIdx));
            
            for k = 1:length(u8ScanAxisIdx)
                this.ceScanCoordinates{k} = unique(dAxisValues(:,k)');
            end
            
            % make scan output for 1 or 2 axis cases
            switch length(u8ScanAxisIdx)
                case 1
                    this.dScanOutput = nan(1, length(this.ceScanCoordinates{1}));
                case 2
                    dXidx = this.ceScanCoordinates{1};
                    dYidx = this.ceScanCoordinates{2};
                    this.dScanOutput = nan(length(dYidx), length(dXidx));
                case 3
                    dXidx = this.ceScanCoordinates{1};
                    dYidx = this.ceScanCoordinates{2};
                    dZidx = this.ceScanCoordinates{3};
                    this.dScanOutput = zeros(size(meshgrid(dXidx, dYidx, dZidx)));
            end
            
        end
        
        function handleUpdateScanOutput(this, u8Idx, stStateElement, dAcquiredValue)
            % Log linear value:
            this.dLinearScanOutput(u8Idx) = dAcquiredValue;
            
            % make scan output for 1 or 2 axis cases
            switch length(this.ceScanCoordinates)
                case 1
                    dXidx = find(this.ceScanCoordinates{1} == stStateElement.values);
                    this.dScanOutput(dXidx) = dAcquiredValue; %#ok<FNDSB>
                    
                    h = plot(this.haScanOutput, this.ceScanCoordinates{1}, this.dScanOutput);
                    h.HitTest = 'off';
                    this.haScanOutput.ButtonDownFcn = @(src, evt) this.handleScanOutputClick(evt, 1);
                    
                case 2
                    dXidx = find(this.ceScanCoordinates{1} == stStateElement.values(1));
                    dYidx = find(this.ceScanCoordinates{2} == stStateElement.values(2));
                    this.dScanOutput(dYidx, dXidx) = dAcquiredValue; %#ok<FNDSB>
                    
                    h = imagesc(this.haScanOutput, this.ceScanCoordinates{1}, this.ceScanCoordinates{2}, (this.dScanOutput));
                    
                    try
                    dMn = min(this.dScanOutput(~isnan(this.dScanOutput(:))));
                    dMx = max(this.dScanOutput(~isnan(this.dScanOutput(:))));
                    if (~isempty(dMn) && ~isempty(dMx))
                        this.haScanOutput.CLim = [dMn, dMx];
                    else
                        this.haScanOutput.CLim = [0, 1];
                    end
                    
                    catch
                        fprintf(lasterr);
                    end
                    
                    this.haScanOutput.YDir = 'normal';
                    h.HitTest = 'off';
                    this.haScanOutput.ButtonDownFcn = @(src, evt) this.handleScanOutputClick(evt, 2);

                    
                    colorbar(this.haScanOutput);
                case 3
                    dXidx = find(this.ceScanCoordinates{1} == stStateElement.values(1));
                    dYidx = find(this.ceScanCoordinates{2} == stStateElement.values(2));
                    dZidx = find(this.ceScanCoordinates{3} == stStateElement.values(3));
                    this.dScanOutput(dXidx, dYidx, dZidx) = dAcquiredValue; %#ok<FNDSB>
                    
                    % don't do anything right now
            end
        end
        
        % Handles a click inside of the scan output axes
        function handleScanOutputClick(this, evt, nDim)
            % make a clone of last scan state but update the
                        % current value:
            stTargetState = this.stLastScanState;
            if evt.Button > 1 % right click
                switch nDim
                    case 1
                        fprintf('(LSI-control) Scan-output: Context click detected at x = %0.3f\n', ...
                            evt.IntersectionPoint(1));
                        
                        
                        stTargetState.values(1) = evt.IntersectionPoint(1);
                        cMsg = sprintf('Move %s to %0.3f?', ...
                                this.ceScanAxisLabels{stTargetState.axes(1)}, ...
                                evt.IntersectionPoint(1));
                            
                        choice = questdlg(cMsg, 'Move axes', 'Yes','No', 'No');
                        % Handle response
                        switch choice
                            case 'Yes'
                                this.setScanAxisDevicesToState(stTargetState);
                            case 'No'
                                fprintf('scan axis move aborted\n');
                        end
                            
                    case 2
                        fprintf('(LSI-control) Scan-output: Context click detected at [x, y] = [%0.3f, %0.3f]\n', ...
                            evt.IntersectionPoint(1), evt.IntersectionPoint(2));
                        stTargetState.values(1) = evt.IntersectionPoint(1);
                        stTargetState.values(2) = evt.IntersectionPoint(2);
                        
                        cMsg = sprintf('Move [%s, %s] to [%0.3f, %0.3f]?', ...
                                this.ceScanAxisLabels{stTargetState.axes(1)}, ...
                                this.ceScanAxisLabels{stTargetState.axes(2)}, ...
                                evt.IntersectionPoint(1),evt.IntersectionPoint(2));
                            
                        choice = questdlg(cMsg, 'Move axes', 'Yes','No', 'No');
                        % Handle response
                        switch choice
                            case 'Yes'
                                this.setScanAxisDevicesToState(stTargetState);
                            case 'No'
                                fprintf('scan axis move aborted\n');
                        end
                end
            else % button down was a left click, just display the event:
                switch nDim
                    case 1
                        cMsg = sprintf('(LSI-control) Scan-output:Axis %s value: %0.3f\n', ...
                                this.ceScanAxisLabels{stTargetState.axes(1)}, ...
                                evt.IntersectionPoint(1));
                        
                        
                    case 2
                        cMsg = sprintf('(LSI-control) Scan-output:Axes [%s, %s] values: [%0.3f, %0.3f]\n', ...
                                this.ceScanAxisLabels{stTargetState.axes(1)}, ...
                                this.ceScanAxisLabels{stTargetState.axes(2)}, ...
                                evt.IntersectionPoint(1),evt.IntersectionPoint(2));
                end
                fprintf(cMsg);
            end
        end
        
        % This will be called anytime scan parameters or the scan tab is
        % changed
        function updateScanMonitor(this, stateList, u8ScanAxisIdx, lUseDeltas, cAxisNames, u8Idx)
            
            
            shiftedStateList = stateList;
            if (u8Idx == 0) % We haven't started scanning yet so make a proper prieview of relative scan WRT initial state
                if (any(lUseDeltas))
                    dInitialState = this.getInitialState(u8ScanAxisIdx);
                else
                    dInitialState = [];
                end

                % If using deltas, modify state to center around current
                % values:
                
                for m = 1:length(u8ScanAxisIdx)
                    if lUseDeltas(m)
                        for k = 1:length(stateList)
                            shiftedStateList{k}.values(m) = stateList{k}.values(m) + dInitialState.values(m);
                        end
                    end
                end
            end
            
            % Plot states on scan monitor tabgroup:
            for k = 1:length(this.haScanMonitors)
                delete(this.haScanMonitors{k});
            end
            
            dNumAxes = length(u8ScanAxisIdx);
            dYPos = 0.05;
            dYHeight = (.75 - (dNumAxes - 1) * 0.05)/dNumAxes;
            for k = 1:dNumAxes
                kp = dNumAxes - k + 1;
                
                this.haScanMonitors{kp} = ...
                    axes('Parent', this.uitgAxes.getTabByName('Scan monitor'),...
                   'XTick', [0, 1], ...
                   'YTick', [0, 1], ...
                   'Position', [0.1, dYPos, .8, dYHeight], ... 
                    'FontSize', 12);
                dYPos = dYPos + 0.05 + dYHeight;
                ylabel(this.haScanMonitors{kp}, cAxisNames{kp});
            end
            
            % Don't need to update 
            if isempty(stateList)
                return
            end
            
            
            % unpack state into axes:
            stateData = [];
            for k = 1:length(shiftedStateList)
                state = shiftedStateList{k};
                for m = 1:dNumAxes
                    stateData(m, k) = state.values(m);
                end
                
            end
            for m = 1:dNumAxes
                plot(this.haScanMonitors{m}, 1:length(stateList), stateData(m, :), 'k');
                this.haScanMonitors{m}.NextPlot = 'add';
                if u8Idx > 0
                     plot(this.haScanMonitors{m}, double(u8Idx), stateData(m, double(u8Idx)),...
                         'ko', 'LineWidth', 1, 'MarkerFaceColor', [.3, 1, .3], 'MarkerSize', 5);
                end
                ylabel(this.haScanMonitors{m}, cAxisNames{m});
                this.haScanMonitors{m}.NextPlot = 'replace';
            end
            
           
        end
        
%% Build main figure
        function build(this)
            
            
            if ishghandle(this.hFigure)
                % Bring to front
                figure(this.hFigure);
                return
            end
            
            % Main figure
            this.hFigure = figure(...
                    'name', 'Interferometer control',...
                    'Units', 'pixels',...
                    'Position', [10 10 this.dWidth this.dHeight],...
                    'numberTitle','off',...
                    'Toolbar','none',...
                    'Menubar','none', ...
                    'Color', [0.7 0.73 0.73], ...
                    'Resize', 'off',...
                    'HandleVisibility', 'on',... % lets close all close the figure
                    'Visible', 'on',...
                    'CloseRequestFcn', @this.onCloseRequest ...
                    );
                
           % Axes:
           
           
           % Main Axes:
           this.uitgAxes.build(this.hFigure, 880, 50, 860, 885);
           this.hsaAxes.build(this.uitgAxes.getTabByName('Camera'), this.hFigure, 10, 10, 810, 720);
            
           
          
            % Stage panel:
            this.hpStageControls = uipanel(...
                'Parent', this.hFigure,...
                'Units', 'pixels',...
                'Title', 'Stage control',...
                'FontWeight', 'Bold',...
                'Clipping', 'on',...
                'BorderWidth',0, ... 
                'Position', [10 620 490 300] ...
            );
        
            % Scan control panel:
            this.hpPositionRecall = uipanel(...
                'Parent', this.hFigure,...
                'Units', 'pixels',...
                'Title', 'Position recall and coordinate transform',...
                'FontWeight', 'Bold',...
                'Clipping', 'on',...
                'BorderWidth',0, ... 
                'Position', [510 620 360 300] ...
                );
        
            drawnow
        
            % Scan controls:
            this.uitgScan.build(this.hFigure, 10, 400, 860, 300);

             % Scans:
            this.ss1D.build(this.uitgScan.getTabByIndex(1), 10, 10, 850, 230); 
            this.ss2D.build(this.uitgScan.getTabByIndex(2), 10, 10, 850, 230);
            this.ss3D.build(this.uitgScan.getTabByIndex(3), 10, 10, 850, 230);
            this.ssExp1.build(this.uitgScan.getTabByIndex(4), 10, 10, 850, 230);
            this.ssExp2.build(this.uitgScan.getTabByIndex(5), 10, 10, 850, 230);
            
            % Scan progress text elements:
            uitScanMonitor = this.uitgAxes.getTabByName('Scan monitor');
            hScanMonitorPanel = uipanel(uitScanMonitor, ...
                     'units', 'pixels', ...
                     'Position', [1 720 560 100] ...
                     );
            this.uiTextStatus.build(hScanMonitorPanel, 10, 10, 100, 30);
            this.uiTextTimeElapsed.build(hScanMonitorPanel, 250, 10, 100, 30);
            this.uiTextTimeRemaining.build(hScanMonitorPanel, 10, 50, 100, 30);
            this.uiTextTimeComplete.build(hScanMonitorPanel, 250, 50, 100, 30);
            
            % Scan output
            uitScanOutput = this.uitgAxes.getTabByName('Scan output');
            this.haScanOutput = axes('Parent', uitScanOutput, ...
                                 'Units', 'pixels', ...
                                 'Position', [50, 50, 750, 650], ...
                                 'XTick', [], 'YTick', []);     
            
            % Position recall:
            this.uiSLHexapod.build(this.hpPositionRecall, 10, 10, 340, 188);
            
            % Stage UI elements
            dAxisPos = 30;
            dLeft = 20;
           
             % Build comms and axes
            this.uiCommSmarActSpaceFab.build(this.hpStageControls, dLeft, dAxisPos - 7);
            this.uibHomeHexapod.build(this.hpStageControls, dLeft + 340, dAxisPos - 5, 95, 20);
            dAxisPos = dAxisPos + 20;
            for k = 1:length(this.cHexapodAxisLabels)
                this.uiDeviceArrayHexapod{k}.build(this.hpStageControls, ...
                    dLeft, dAxisPos);
                dAxisPos = dAxisPos + this.dMultiAxisSeparation;
            end
            dAxisPos = dAxisPos + 20;
            
           
            % Camera control panel:
            this.hpCameraControls = uipanel(...
                'Parent', this.hFigure,...
                'Units', 'pixels',...
                'Title', 'Camera control',...
                'FontWeight', 'Bold',...
                'Clipping', 'on',...
                'BorderWidth',0, ... 
                'Position', [10 20 860 200] ...
            );
            
            % Camera UI elements
            this.uiDeviceCameraTemperature.build(this.hpCameraControls, 10, 40);            
            this.uiDeviceCameraExposureTime.build(this.hpCameraControls, 10, 70);
            
            this.uiCommPixisCamera.build    (this.hpCameraControls, 10,  15);
            
            this.uipBinning.build           (this.hpCameraControls, 545, 40, 70, 25);
            this.uiButtonFocus.build        (this.hpCameraControls, 630, 50, 60,  25);
            this.uiButtonAcquire.build      (this.hpCameraControls, 710, 50, 60,  25);
            this.uiButtonStop.build         (this.hpCameraControls, 790, 50, 60,  25);
            
            this.uieImageName.build         (this.hpCameraControls, 180 + 370, 115, 200, 25);
            this.uiButtonSaveImage.build    (this.hpCameraControls, 400 + 370, 130, 80, 20);
           
            this.uiButtonSetBackground.build(this.hpCameraControls,  630, 90, 95, 25);
            this.uicbSubtractBackground.build(this.hpCameraControls, 730, 90, 120, 25);
            
            
            this.uipbExposureProgress.build(this.hpCameraControls, 10, 10, 10, 115);
                  
            % Button colors:
            this.uiButtonAcquire.setText('Acquire')
            this.uiButtonAcquire.setColor(this.dAcquireColor);
            this.uiButtonFocus.setText('Focus')
            this.uiButtonFocus.setColor(this.dFocusColor);
            this.uiButtonStop.setText('STOP');
            this.uiButtonStop.setColor(this.dInactiveColor);
            
        end
        
        function homeHexapod(this)
            if strcmp(questdlg('Would you like to home the Hexapod?'), 'Yes')
                this.apiHexapod.home();
            end
        end
        
  
        
        

        
    
    end
    
    
    methods (Access = protected)
        
        function onCloseRequest(this, src, evt)
            if ishandle(this.hFigure)
                delete(this.hFigure);
            end
        end
        
        function delete(this)
            
            % Clean up clock tasks
            if isvalid(this.clock) && ...
                    this.clock.has(this.id())
                % this.msg('Axis.delete() removing clock task');
                this.clock.remove(this.id());
            end
        end
      
        
        function onToggleAllChange(this, src, evt)
            
            if this.uiToggleAll.get()
                this.turnOnAllDeviceUi();
            else
                this.turnOffAllDeviceUi()
            end
            
        end
        
        
       
        
        function saveStateToDisk(this)
            st = this.save();
            save(this.file(), 'st');
            
        end
        
        function loadStateFromDisk(this)
            if exist(this.file(), 'file') == 2
                fprintf('loadStateFromDisk()\n');
                load(this.file()); % populates variable st in local workspace
                this.load(st);
            end
        end
        
        function c = file(this)
            mic.Utils.checkDir(this.cDirSave);
            c = fullfile(...
                this.cDirSave, ...
                ['saved-state', '.mat']...
            );
        end
        
    end
    
end

