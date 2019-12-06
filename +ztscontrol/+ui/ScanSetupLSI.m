%{
ScanSetup is a ui element used to set up scan states for use in the
mic.scan class.  ScanSetup is implemented by instantiating ScanAxisSetups
which control parameters for the individual axes.

Instantiate with at least parameter dScanAxes,  ceOutputOptions, and
ceScanAxisLabels, which control the dimensionality of the scan, the labels
for the output options, and the labels for the input axis options
respectively

Pass parameter 
    fhOnScanChangeParams = @(ceScanStates, u8ScanAxisIdx, lUseDeltas)
To initialize a callback that will be called any time a scan parameter is
changed, passing a cell array of scanstates, the axis numbers of the active
scans as defined in the uipopup, and the useDeltas boolean array to
determine whether scans will be about the current axis value


This overloaded version will create pairs of coupled axis motion

%}

classdef ScanSetupLSI < mic.ui.common.ScanSetup
    
    
    properties (Constant)
        
    end
    
    
    properties (SetAccess = private)
        
        
    end
    
    
    properties (Access = protected)


    end
    
    
    
    methods
        
        % constructor
        
        
        function this = ScanSetupLSI(varargin)
            this@mic.ui.common.ScanSetup(varargin{:});
           

            
        end
        
        
        % The primary difference with this specialized LSI is that we are
        % going to set up the states in serial, with linear motions in X
        % then linear motions in Y.
        %
        % Set up axes as pairs:
        
       function [ceScanStates, u8ScanAxisIdx, lUseDeltas] = buildScanStateArray(this)
            
            % Save the scan idx of each axis and whether to use deltas
            u8ScanAxisIdx = [];
            lUseDeltas = [];
            
            for k = 1:this.dScanAxes
                u8ScanAxisIdx(k) = this.saScanAxisSetups{k}.getScanAxisIndex();
                lUseDeltas(k) = this.saScanAxisSetups{k}.useDelta();
            end
            
            % Create a cell array of the scan ranges for each
            % scanAxisSetup:
            ceScanRanges = cell(1,this.dScanAxes);
            
            for k = 1:this.dScanAxes
                ceScanRanges{k} = this.saScanAxisSetups{k}.getScanRanges();
            end
            
            % Now need to build a list of states corresponding to the scan
            % ranges:
            ceScanStates = cell(0);
            
            switch this.dScanAxes/2
                
                case 1 % X-Y scan
                    % Axis 1
                    numScanStates = min([length(ceScanRanges{1}), length(ceScanRanges{2})]);
                    
                    for k = 1:numScanStates
                            ceScanStates{end + 1} = struct('indices', [k, k], ...
                                'axes', u8ScanAxisIdx(1:2), ...
                                'values',[ceScanRanges{1}(k), ceScanRanges{2}(k)]); %#ok<AGROW>
                    end
                    
                case 2 %Y-X scan with intermediate steps
                    numScanStates1 = min([length(ceScanRanges{1}), length(ceScanRanges{2})]);
                    numScanStates2 = min([length(ceScanRanges{3}), length(ceScanRanges{4})]);
                    
                     for k = 1:numScanStates1
                        for m = 1:numScanStates2
                            if ~this.uicbRaster.get() || isodd(k)
                                kidx = k;
                                midx = m;
                                
                            else % raster direction
                                kidx = k;
                                midx = length(ceScanRanges{2}) - m + 1;
                            end
                            ceScanStates{end + 1} = struct('indices', [kidx, kidx, midx, midx], 'axes', u8ScanAxisIdx, 'values',...
                                    [ceScanRanges{1}(kidx), ceScanRanges{2}(kidx), ceScanRanges{3}(midx), ceScanRanges{4}(midx)]); %#ok<AGROW>
                        end
                    end
                    
                   
                    
            end
       end
       
        % Builds scan states and passes them to the fhOnScan callback
        function routeScanInfoToCallback(this, ~, ~)
            
            [ceScanStates, u8ScanAxisIdx, lUseDeltas]  = this.buildScanStateArray();
            % Pass out scan axes and output for validation
            u8OutputIdx = this.uipOutput.getSelectedIndex();
            
            cAxisNames = this.ceScanAxisLabels(u8ScanAxisIdx);
            if ~isempty(ceScanStates)
                this.fhOnScan(ceScanStates, u8ScanAxisIdx, lUseDeltas, u8OutputIdx, cAxisNames);
            else
                msgbox('No states to scan, check scan parameters');
            end
            
            % scan "states" are structures with properties: axes, values
            % where axes is an array of the indices of axes as defined in
            % the scanAxisSetup uipopup, and values are the corresponding
            % values
        end
        
       function paramChangeCallback(this)
            % For testing just echo somethign:
            disp('param change callback');
            
            % Get current scan parameters and route to param change
            % callback:
            [ceScanStates, u8ScanAxisIdx, lUseDeltas] = this.buildScanStateArray();
            cAxisNames = this.ceScanAxisLabels(u8ScanAxisIdx);
            this.fhOnScanChangeParams(ceScanStates, u8ScanAxisIdx, lUseDeltas, cAxisNames);
       end
        
       
        
       
         % Builds the UI elements
        function build(this,  hParent,  dLeft,  dTop,  dWidth,  dHeight)
            
            this.hPanel = uipanel( ...
                'Parent', hParent, ...
                'Units', 'pixels', ...
                'Title', blanks(0), ...
                'Clipping', 'on', ...
                'BorderWidth',0, ... 
                'Position', ([dLeft dTop dWidth dHeight]));
            drawnow
            
            % First build scan axes:
            
            dLeft = 10;
            dPad = 6;
            dY = 45;
            dTop = 2;
            
            for k = 1:this.dScanAxes
                this.saScanAxisSetups{k}.build(this.hPanel, dLeft, ...
                    dTop);
                if mod(k,2) == 1 && this.dScanAxes > 2
                    dTop = dTop + dPad + dY*.75;
                else
                    dTop = dTop + dPad + dY*1.05;
                end
            end
            
            dTop = dTop + 3*dPad;
             
            % Build only if there is more than one axis
            this.uicbRaster.build(this.hPanel, 250, dTop + 2, 70, 25);
            this.uibStartScan.build(this.hPanel, 140, dTop - 10, 45, 30);
            this.uipOutput.build(this.hPanel, 10, dTop - 20, 120, 40);
            this.uibStopScan.build(this.hPanel, 195, dTop - 10, 45, 30);
            
            
            this.uiSLScanSetup.build(this.hPanel, 487, 10, 340, dHeight - 20);
            
            this.uibStartScan.setColor([.7, .75, .9]);
            this.uibStopScan.setColor([.9, .7, .7]);
            
        end
       
        
        
    end
    
    methods (Access = protected)
        
        
        
        
        
        
    end
end