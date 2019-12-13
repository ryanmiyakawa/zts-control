
% delete timers:
if exist('purge', 'file')
    purge;
end

mpm addpath

%grab hardware
hardware = ztscontrol.ztsHardware;




%% Test hexapod
comm = hardware.getHexapod();
comm.connect('COM3')

%%
comm.isReady()
comm.isInitialized()
comm.moveStageAbsolute([0, 0, -5, 0, 0, 0], false) % downstream
comm.moveStageAbsolute([0, -2, -5, 0, 0, 0], false) % down
comm.moveStageAbsolute([0, -2, -5, 0, 0, 0], false) % positive move is inboard
%% text pixis:

cam =  hardware.getCamera();
cam.initCamera(0);
cam.isInitialized()