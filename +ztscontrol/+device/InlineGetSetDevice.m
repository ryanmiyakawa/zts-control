classdef InlineGetSetDevice < mic.interface.device.GetSetNumber


    properties (Access = private)
        fhSetAction
        fhGetAction
        fhIsReadyAction = @()true
        fhIsInitializedAction = @()true
    end
    
    methods
        
        function this = InlineGetSetDevice(varargin)
            for k = 1 : 2: length(varargin)
                % this.msg(sprintf('passed in %s', varargin{k}));
                if this.hasProp(varargin{k})
                    this.msg(sprintf('settting %s', varargin{k}), 3);
                    this.(varargin{k}) = varargin{k + 1};
                else
                    switch varargin{k}
                        case 'get'
                            this.fhGetAction = varargin{k + 1};
                        case 'set'
                            this.fhSetAction = varargin{k + 1};
                    end
                    
                end
            end
        end
        
        function d = get(this)
            d = this.fhGetAction();
        end
        
        function set(this, dVal)
            this.fhSetAction(dVal);
        end
        
        function l = isReady(this)
            l = this.fhIsReadyAction();
        end
        
        function stop(this)
        end
        
        % This will home the stage
        function initialize(this)
            
        end
        
        function l = isInitialized(this)
           l = this.fhIsInitializedAction();
        end
        
        

        
    end
        
    
end

