classdef CoupledAxisBridge < mic.interface.device.GetSetNumber


    properties (Access = private)
        stageAPI
        R
        dAxisNumber
        dNumAxes
    end
    
    methods
        
        function this = CoupledAxisBridge(stageAPI, axisNumber, totalAxes)
            this.dNumAxes = totalAxes;
            this.stageAPI = stageAPI;
            this.dAxisNumber = axisNumber;
            this.R = eye(totalAxes);
        end
        
        % Breaks abstraction a little, but we sometimes need to move all
        % axes simultaneously behind the rotation transformation
        function moveAllAxesRaw(this, dPosAr)
            % Set 6-vector in hexapod coordinates
            this.stageAPI.setAxesPosition(...
                        (this.R\dPosAr) ...
                        );
        end
        
        function setR(this, R)
            this.R = R;
        end
        
        function d = get(this)
            dPosAr = this.R*(this.stageAPI.getAxesPosition()); % Rotate from hexapod coordinates to GUI coordinates
            d = dPosAr(this.dAxisNumber);
            
        end
        
        function set(this, dVal)
            dPosAr = this.R*(this.stageAPI.getAxesPosition());% Rotate from hexapod coordinates to GUI coordinates
            dPosAr(this.dAxisNumber) = dVal; % Set value into GUI coordinates
            
            % Set 6-vector in hexapod coordinates
            this.stageAPI.setAxesPosition(...
                        (this.R\dPosAr) ...
                        );
        end
        
        function l = isReady(this)
            l = this.stageAPI.isReady();
        end
        
        function stop(this)
             this.stageAPI.stop();
        end
        
        % This will home the stage
        function initialize(this)
             this.stageAPI.home();
        end
        
        function l = isInitialized(this)
            l = this.stageAPI.isInitialized();
        end
        
        

        
    end
        
    
end

