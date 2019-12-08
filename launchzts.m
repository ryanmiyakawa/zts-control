
% delete timers:
if exist('purge', 'file')
    purge;
end

mpm addpath

clock = mic.Clock('ZTS-control');


app = ztscontrol.ui.ZTS_Control(hardware);



%%
app.build()
