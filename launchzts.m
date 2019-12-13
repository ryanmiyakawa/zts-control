
% delete timers:
if exist('purge', 'file')
    purge;
end

mpm addpath

clock = mic.Clock('ZTS-control');

hardware = ztscontrol.ztsHardware;

app = ztscontrol.ui.ZTS_Control('hardware', hardware);

app.build()

