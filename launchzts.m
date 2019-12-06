
% delete timers:
if exist('purge', 'file')
    purge;
end

mpm addpath


app = ztscontrol.ui.ZTS_Control();



%%
app.build()
