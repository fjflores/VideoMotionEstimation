%
% video_motion_rt_estimation_v9b( deviceIndexList, strFilestem )
%
%	Real time video source motion detection and estimation. 
%   One camera, or two cameras simultaneously.
%
%   To Do: More documentation and cleanup.
%
%   USAGE: [ listAccMotion listnMotionRecent ] = video_motion_rt_estimation_v9b( 1, 'Motion_info_1' );
%                                           OR
%                                                video_motion_rt_estimation_v9b( [1 2], 'Motion_info_1' );
%               where [1 2] indicates two cameras, the first and second camera devices, are 
%               available and provide the resolution requested (see szAcquisition below).
%
%       Note: There is no built in initialization of the camera(s). Use MATLAB's 
%             Image Acquisition Tool to examine and test available camera devices.
%               >> imaqtool
%
%             There is also no attempt to find appropriate available cameras. 
%             It is hardcoded to accept common webcams:
%           
%                   videoinput( 'winvideo', deviceIndex, 'YUY2_640x480' );
%                   videoinput( 'winvideo', deviceIndex, 'YUY2_320x240' );
%                   videoinput( 'winvideo', deviceIndex, 'YUY2_160x120' );
%
%   ARGUMENTS:
%
%       deviceIndexList: 	Index (or indices) of an available to the system.
%                           e.g. 1 for the first camera device
%                           or   [1 3] for the first and third camera device.
%
%       strFilestem:        Output file stem of time series arrays (see return values).
%                           Postfix is hardcoded:
%                               -> [Motion_info_1]_listMotion.mat
%
%   RETURN VALUES:
% 
%       listAccMotion:	Motion estimates through time binned by time interval.
%                       listAccMotion( :, 1, 1:2):     Time in seconds from the initial time to the end of each recorded period, of cameras 1 and 2.
%                       listAccMotion( :, 2, 1:2):     Motion magnitude estimate in the previous interval, of cameras 1 and 2.
%
%       listnMotionRecent:	Motion estimates by frame number.
%                       listnMotionRecent( :, 1, 1:2 ):    Time, in seconds from first frame, of cameras 1 and 2.
%                       listnMotionRecent( :, 2, 1:2 ):    Motion magnitude estimate (number) in the previous interval, of cameras 1 and 2.
%                       listnMotionRecent( :, 3, 1:2 ):    Instantaneous center of motion estimate in vertical dimension, pixels, of cameras 1 and 2.
%                       listnMotionRecent( :, 4, 1:2 ):    Instantaneous center of motion estimate in horizontal dimension, pixels, of cameras 1 and 2.
%                       listnMotionRecent( :, 5, 1:2 ):    Motion magnitude estimate (number x super-threshold luminance) in the previous interval, of cameras 1 and 2.
%
%       tInitial:       Time at start (before any frames are acquired). 
%                       The format is in MATLAB's six element date vector containing the current
%                       time and date in decimal form (see >>help clock):
%                           [year month day hour minute seconds]
%
%   HARDCODED: The parameters below are copies of default hardcoded values below the function declaration.     
% 
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % Temboral binning and array sizes.
% dtAccumulation    =  1.0;   % Time interval for accumulated motion, in seconds. This controls 
%                             % sampling of the frame rate. The returned values in listAccMotion
%                             % are the mean values of frames in periods of this length.
%                             
% tAccumulationMax  =   99;   % Maximum time of motion monitoring, in hours.
%                             % Each timepoint requires 2 values x 8 bytes/value x nCameras.
%                             % With two cameras and dtAccumulation = 1 s, each hour requires 
%                             % ~58 KB of memory.
%                             
% nFramesRecent   =  10000;	% [ > dtAccumulation*32frames/s ] Stores information about this 
%                             % number of most recent frames. Must be larger than the number of 
%                             % frames that occur in an accumulation period (dtAccumulation). 
%                             % Each timepoint requires 5 values x 8 bytes/value x nCameras.
%                             % With two cameras at 15 fps, 10,000 frames takes 11 minutes 
%                             % and requires ~1.2 MB of memory.
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                             
% nLowThreshold      = 16;    % Default 8-bit interframe difference threshold. 
%                             % An absolute sequential frame difference, less averaged  
%                             % noise*flNoiseSubtractFactor, above this threshold is considered 
%                             % a motion candidate. If it has neighborhood support (see nNbrhood) 
%                             % OR the difference is >= 2*nLowThreshold, it is included in motion 
%                             % estimate.
% %%%%%%%%%%%%%%%%%%%%%                            
% % Save and show data.                            
% bSave           =  true;    % Write motion timecourse to file.
%     tAutoSave   =    10;    % Autosave period, in minutes. Only if bSave == true and > 0.
%     bSaveMAT    =  true;    % Write all to MATLAB native format (.mat).
%     bSaveXLS    = false;	% NOT FUNTIONAL YET. Write listAccMotion only to an Excel spreadsheet (.xls).
%     bSaveDLM    =  true;	% Write listAccMotion only to a space delimited text file (.txt).
%     
% bShowFramePlot	=  true;    % Plot frame-wise estimates (bar chart) on exit.
% bShowMotionPlot	=  true;    % Plot average sampled motion estimates (bar chart) on exit.
%     bShowMotionCentersToo   = false; % Scatter plot of motion centroid, only if showing motion bar chart.
% bShowMotionDFT	= false;    % Plot DFT of estimated motion time series on exit, both frame-wise
%                             % and average sampled motion.
% bShowFrameTimeDiffHistogram = false; % Show histogram of time periods between all most recent 
%                                      % frame acquisition on exit.
% bRecording = false;         % Default recording and writing to file of motion data.
% %%%%%%%%%%%%%%%%%%%%%                            
% 
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%                            
% % Video frame acquisition, size, scale(s).                            
% szAcquisition   = 1;    %  [0,2] Size of image to acquire from camera.
%                         %  0: 640x480
%                         %  1: 320x240
%                         %  2: 160x120
%                         
% log2ScaleMax    = 0;    % Largest block downsampling scale, as a power of 2.
%                         % For example, log2ScaleMax = 3 results in downsampling by a factor of 
%                         % 2^3 = 8. For an image acquired at 640 x 480, the largest scale will be 
%                         % 80 x 60.
%                         
%     tSpacing	= 1;    % Integer spacing between scale representations, log2.
%                       	% For example, tSpacing = 3 results in 8x8 (8 = 2^3) block averaging 
%                        	% between scales. Only used if log2ScaleMax > tSpacing.
%                         
% flDelayBetween = 0.01;         % [>0.0] Pause time between frames, in seconds.
%             % If the is set to 0, the effective frame rate will be marginally higher than if set 
%             % to a very value. But if there is not enough time between drawing to capture most 
%             % button clicks in the GUI, many clicks will be required before a GUI button will
%             % respond.
%             % Small values cause the program to run nearly at full speed, using a CPU at near
%             % full capacity. This can cause some machines (laptops) to run hot for extended
%             % periods of time. A delay of .05 or .1 second will limit the frame rate to about 
%             % 7.5 or 5 frames/second but will reduce CPU usage.
%             
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%                            
% 
% %%%%%%%%%%%%%%%%%%%
% % Noise adaptation. 
% 
% nFalsePositiveTarget = 10;	% Noise subtraction is adaptively adjusted such that the number
%                           	% of false positives is about this number.                         
% 
% flNoiseSubtractFactorInit       = 1.00; % Initial adaptive parameter based on average noise. 
%                                         % See nLowThreshold above, false positive target below.
% flNoiseSubtractFactorIncrement  =  .02;	% Rate, per frame, of noise accomodation.
% 
% nFramesNoiseAvg	= 20;   % Time window for noise estimation. Requires a large chunk of memory; 
%                         % this number of frames need to be stored, about 1 MB/frame 
%                         % for 640 x 480 images.
% %%%%%%%%%%%%%%%%%%%                         
% 
% % flFalsePositiveFactor = sqrt(2);    % Not currently used.
% flMotionToFalsePosThresh = .5;   % [>1.0] Motion object threshold: If there are enough pixel 
%         % differences above threshold, then motion of an object is considered to have occured
%         % -- only a few above threshold are likely to be false positives. Choose the motion 
%         % object threshold as a constant product of the pixel motion false
%         % positive value: nMotion > flMotionToFalsePosThresh*nFalsePositiveTarget
%         
% nNbrhood = 2;           % Support neighborhood for motion testing.
%                         %   Contiguity of n > 1 pixels with a neighborhood criterion.
%                         %   Every pixel difference that is alone in it's neighborhood AND
%                         %   below 2*nLowThreshold_t is considered a false positive.
%      
% nMotionSamples = 400;   % Number of motion pixel candidate samples, if number of 
%                         % super-threshold pixels > 2*nMotionSamples. Center
%                         % of motion extrapolated from this sample size.
%                         % Note: might make this prime to avoid scan line aliasing (factors of
%                         % scan line related to factors of sampling frequency?).
% 
% % filtTmp = [ 1 3 6 12 25 50 100 ];   % A filter vector that weights recent the most recent 
%                                     % frame information, with most recent at right. Used to 
%                                     % smooth the center of motion (position) estimates.
% filtTmp = 1:5;  % A triangular filter with center at 1/3 the length. The apparent lag 
%                 % induced will be about 1/3 of the filter length, in seconds.          
%                                     
%             
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % Motion and other image display.
% 
% nAmplifiedNoiseSlope = 7;   % Saturation and luminance of yellow superthreshold overlay.
% 
% sziconMotion = .05;         % Size of motion icon, as a fraction of raw image height.
% nAddCyan     =  96;         % Luminance of motion icon.
% 
% bShowMotionPixels	= true; % Default displaying of (yellow) super-threshold motion pixels.
% bShowMotionIcon     = true; % Default displaying of (cyan) center of motion icon.
% bShowBackground     = true; % Default display of video image background. 
% bShowImage          = true; % Default display of any image and, overlay(s) and caption. 
%                             % Currently there is no reason to turn this off.
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 
% %%%%%%%%%%%%%%%%%%%%                       
% % Bar chart display.
% flNotFramesInBin	=  .5;  % Accumulation array value that indicates no frame in recording bin.
%                             % The bar chart displays the log10 value, an indictor for no frame.
%                             % log10(.5) = -.3
% flNotRecordingValue = -.2;  % Bar chart display value (log10) for not recording periods.
% flDisplayOnesAs     =   1;  % Bar chart display value (log10) for values of 1. 
%                             % log10(1) == 0
% flDisplayZeroAs     = -.1;  % Bar chart display value (log10) for zero values and averages in the range [0,1). 
% %%%%%%%%%%%%%%%%%%%                       
%
%
%   CALLS: 
%
%       Requires MATLAB's Image Acquisition Toolbox for video access functions, which is not 
%       available on Mac operating systems.
%
%
% Mark Dow,             January  6, 2010
% Mark Dow, modified    January 10, 2010  (calibration, etc.)
% Mark Dow, modified    January 10, 2010  (fixing up)
% Mark Dow, modified    January 12, 2010  (rough real time calibration, stronger typing)
% Mark Dow, modified    January 16, 2010  (noise adaptation)
% Mark Dow, modified    January 21, 2010  (controls, red flag display)
% Mark Dow,             April   13, 2010  (video_real_time_test, derived from video_motion_real_time.m)
% Mark Dow, modified      April 13, 2010  (v1, backround displayed as image)
% Mark Dow, modified      April 15, 2010  (v2, started downsampling)
% Mark Dow, modified      April 15, 2010  (v3, started basic image pyramids)
% Mark Dow, modified      April 17, 2010  (v4, filtered center of motion)
% Mark Dow, modified      April 19, 2010  (v5, switch between scales)
% Mark Dow, modified      April 22, 2010  (v7, distinguishes motion/false positives)
% Mark Dow, modified      April 22, 2010  (v8, efficient image pyramid construction)
% Mark Dow, modified      April 24, 2010  (v9, experimental dynamic threshold adaptation)
% Mark Dow,           September 30, 2010  (video_real_time_test_dual, derived from , derived from video_real_time_test_v10.m)
% Mark Dow, modified  September 30, 2010  (v11, dual video sources test)
% Mark Dow, modified    October  2, 2010  (v12, refactoring and removal of obsolete test code)
% Mark Dow, modified    October  3, 2010  (v13, motion estimation binned through time)
% Mark Dow, modified    October  3, 2010  (video_motion_rt_estimation_v1, derived from , derived from video_real_time_test_v13.m)
% Mark Dow, modified    October  6, 2010  (v2, basic implementation of dual camera)
% Mark Dow, modified    October  7, 2010  (v4, center of motion and bug fixes)
% Mark Dow, modified    October  7, 2010  (v5, autosave partial data, device list as argument, 
% Mark Dow, modified    October 12, 2010  (v6, overwrite prevention, precice averaging across frames, log10 plots and plot details)
% Mark Dow, modified    October 13, 2010  (v7, fixed plotting bugs)
% Mark Dow, modified    October 15, 2010  (v8, plot options, write to text file)
% Mark Dow, modified    October 19, 2010  (v9, improved multi-scale representation and analysis, 2 camera recording bug fix)
% Mark Dow, modified    October 24, 2010  (v9b, two camera write and plot bug fix, three column space delimited text write)
%

%
%   To Do:
%
%       Filter high frequecy motion candidates by low frequency candidates.
%           Cluster blobs by low frequency neighborhood.
%               Divisive hierachical clustering based on a simple binary scale-space.
%
%       Start rough motion direction estimation.
%
%       Fast and fine adaptation of noise subtraction scalar, flNoiseSubtractFactor? 
%       When is this useful?
%
%       Sketch a more detailed flowchart of basic elements.
%
%       Optimize undersampling of motion when N is high.
%       
%       Accumulate old frames for slow motion detection when number of motion hits is 
%       negligible. This can be tested by simply increasing the delay between frames, but 
%       fast changes are missed.
%
%       Sanity check on log2ScaleMax, tSpacing such that size is always an even multiple.
%
%       Handle semi-global illumination and/or camera exposure changes.
%           Simply detect and ignore "bad frames"? This is comparable to
%           avoiding change blindness (http://en.wikipedia.org/wiki/Change_blindness).
%
%       Find and report on start memory used for long running times.
%
%       Try adding a third camera.
%

function listAccMotion = video_motion_rt_estimation_v9b( deviceIndexList, strFilestem )


global log2ScaleMax
global szAcquisition
global tSpacing

global bEnd
global nLowThreshold
global nLowThreshold_t % threshold at current scale

global bShowMotionPixels
global hSM
global niconMotion
global sziconMotion
global bShowMotionIcon
global hSI
global bShowBackground 
global hSB

global szFrame
global szFrameShow
global tShowscale

global nFalsePositiveTarget
global nFalsePositiveTarget_t

global bRecording
global hR

global tAccFirst
global nAccFrames
global nR

global hDRp
global hDRm

%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%
%   Hardcoded:

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Temboral binning and array sizes.
dtAccumulation    =  1.0;   % Time interval for accumulated motion, in seconds. This controls 
                            % sampling of the frame rate. The returned values in listAccMotion
                            % are the mean values of frames in periods of this length.
                            
tAccumulationMax  =   99;   % Maximum time of motion monitoring, in hours.
                            % Each timepoint requires 2 values x 8 bytes/value x nCameras.
                            % With two cameras and dtAccumulation = 1 s, each hour requires 
                            % ~58 KB of memory.
                            
nFramesRecent   =  10000;	% [ > dtAccumulation*32frames/s ] Stores information about this 
                            % number of most recent frames. Must be larger than the number of 
                            % frames that occur in an accumulation period (dtAccumulation). 
                            % Each timepoint requires 5 values x 8 bytes/value x nCameras.
                            % With two cameras at 15 fps, 10,000 frames takes 11 minutes 
                            % and requires ~1.2 MB of memory.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                            
nLowThreshold      = 16;    % Default 8-bit interframe difference threshold. 
                            % An absolute sequential frame difference, less averaged  
                            % noise*flNoiseSubtractFactor, above this threshold is considered 
                            % a motion candidate. If it has neighborhood support (see nNbrhood) 
                            % OR the difference is >= 2*nLowThreshold, it is included in motion 
                            % estimate.
%%%%%%%%%%%%%%%%%%%%%                            
% Save and show data.                            
bSave           =  true;    % Write motion timecourse to file.
    tAutoSave   =    10;    % Autosave period, in minutes. Only if bSave == true and > 0.
    bSaveMAT    =  true;    % Write all to MATLAB native format (.mat).
    bSaveXLS    = false;	% NOT FUNTIONAL YET. Write listAccMotion only to an Excel spreadsheet (.xls).
    bSaveDLM    =  true;	% Write listAccMotion only to a space delimited text file (.txt).
    
bShowFramePlot	=  true;    % Plot frame-wise estimates (bar chart) on exit.
bShowMotionPlot	=  true;    % Plot average sampled motion estimates (bar chart) on exit.
    bShowMotionCentersToo   = false; % Scatter plot of motion centroid, only if showing motion bar chart.
bShowMotionDFT	= false;    % Plot DFT of estimated motion time series on exit, both frame-wise
                            % and average sampled motion.
bShowFrameTimeDiffHistogram = false; % Show histogram of time periods between all most recent 
                                     % frame acquisition on exit.
bRecording = false;         % Default recording and writing to file of motion data.
%%%%%%%%%%%%%%%%%%%%%                            

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%                            
% Video frame acquisition, size, scale(s).                            
szAcquisition   = 1;    %  [0,2] Size of image to acquire from camera.
                        %  0: 640x480
                        %  1: 320x240
                        %  2: 160x120
                        
log2ScaleMax    = 0;    % Largest block downsampling scale, as a power of 2.
                        % For example, log2ScaleMax = 3 results in downsampling by a factor of 
                        % 2^3 = 8. For an image acquired at 640 x 480, the largest scale will be 
                        % 80 x 60.
                        
    tSpacing	= 1;    % Integer spacing between scale representations, log2.
                      	% For example, tSpacing = 3 results in 8x8 (8 = 2^3) block averaging 
                       	% between scales. Only used if log2ScaleMax > tSpacing.
                        
flDelayBetween = 0.01;         % [>0.0] Pause time between frames, in seconds.
            % If the is set to 0, the effective frame rate will be marginally higher than if set 
            % to a very value. But if there is not enough time between drawing to capture most 
            % button clicks in the GUI, many clicks will be required before a GUI button will
            % respond.
            % Small values cause the program to run nearly at full speed, using a CPU at near
            % full capacity. This can cause some machines (laptops) to run hot for extended
            % periods of time. A delay of .05 or .1 second will limit the frame rate to about 
            % 7.5 or 5 frames/second but will reduce CPU usage.
            
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%                            

%%%%%%%%%%%%%%%%%%%
% Noise adaptation. 

nFalsePositiveTarget = 10;	% Noise subtraction is adaptively adjusted such that the number
                          	% of false positives is about this number.                         

flNoiseSubtractFactorInit       = 1.00; % Initial adaptive parameter based on average noise. 
                                        % See nLowThreshold above, false positive target below.
flNoiseSubtractFactorIncrement  =  .02;	% Rate, per frame, of noise accomodation.

nFramesNoiseAvg	= 20;   % Time window for noise estimation. Requires a large chunk of memory; 
                        % this number of frames need to be stored, about 1 MB/frame 
                        % for 640 x 480 images.
%%%%%%%%%%%%%%%%%%%                         

% flFalsePositiveFactor = sqrt(2);    % Not currently used.
flMotionToFalsePosThresh = .5;   % [>1.0] Motion object threshold: If there are enough pixel 
        % differences above threshold, then motion of an object is considered to have occured
        % -- only a few above threshold are likely to be false positives. Choose the motion 
        % object threshold as a constant product of the pixel motion false
        % positive value: nMotion > flMotionToFalsePosThresh*nFalsePositiveTarget
        
nNbrhood = 2;           % Support neighborhood for motion testing.
                        %   Contiguity of n > 1 pixels with a neighborhood criterion.
                        %   Every pixel difference that is alone in it's neighborhood AND
                        %   below 2*nLowThreshold_t is considered a false positive.
     
nMotionSamples = 400;   % Number of motion pixel candidate samples, if number of 
                        % super-threshold pixels > 2*nMotionSamples. Center
                        % of motion extrapolated from this sample size.
                        % Note: might make this prime to avoid scan line aliasing (factors of
                        % scan line related to factors of sampling frequency?).

% filtTmp = [ 1 3 6 12 25 50 100 ];   % A filter vector that weights recent the most recent 
                                    % frame information, with most recent at right. Used to 
                                    % smooth the center of motion (position) estimates.
filtTmp = 1:5;  % A triangular filter with center at 1/3 the length. The apparent lag 
                % induced will be about 1/3 of the filter length, in seconds.          
                                    
            
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Motion and other image display.

nAmplifiedNoiseSlope = 7;   % Saturation and luminance of yellow superthreshold overlay.

sziconMotion = .05;         % Size of motion icon, as a fraction of raw image height.
nAddCyan     =  96;         % Luminance of motion icon.

bShowMotionPixels	= true; % Default displaying of (yellow) super-threshold motion pixels.
bShowMotionIcon     = true; % Default displaying of (cyan) center of motion icon.
bShowBackground     = true; % Default display of video image background. 
bShowImage          = true; % Default display of any image and, overlay(s) and caption. 
                            % Currently there is no reason to turn this off.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%                       
% Bar chart display.
flNotFramesInBin	=  .5;  % Accumulation array value that indicates no frame in recording bin.
                            % The bar chart displays the log10 value, an indictor for no frame.
                            % log10(.5) = -.3
flNotRecordingValue = -.2;  % Bar chart display value (log10) for not recording periods.
flDisplayOnesAs     =   1;  % Bar chart display value (log10) for values of 1. 
                            % log10(1) == 0
flDisplayZeroAs     = -.1;  % Bar chart display value (log10) for zero values and averages in the range [0,1). 
%%%%%%%%%%%%%%%%%%%                       

%   Hardcoded:
%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%
% Sanity checks:
if tSpacing < 1 || tSpacing > 3
    display( 'tSpacing, should be in the range [1,3]' )
    return
end

if flDelayBetween == 0
    display( 'WARNING: flDelayBetween == 0.0' );
    display( '         There is not enough time between drawing to capture most button clicks.' );    
end

% To Do: Display and store memory requirements 
% 16*(tAccumulationMax*3600)/dtAccumulation + recent frame array
% 

% Sanity checks:
%%%%%%%%%%%%%%%%

if mod( log2ScaleMax, tSpacing ) > 0
    log2ScaleMax = log2ScaleMax - mod( log2ScaleMax, tSpacing )
end

nCameras = length( deviceIndexList );
if nCameras == 1
    deviceIndex = deviceIndexList;
end
if nCameras == 2
    deviceIndex  = deviceIndexList(1);
    deviceIndex2 = deviceIndexList(2);
end

% % Get device info:
% imaqhwinfo
% dev_info = imaqhwinfo( 'winvideo', 2 )

% Remove any existing video input objects. If this program fails in the main loop, the video 
% objects don't get deleted and the program won't run again until they are deleted.
delete(imaqfind);

if szAcquisition == 0
    
	videoIn = videoinput( 'winvideo', deviceIndex, 'YUY2_640x480' );
    if nCameras == 2
        videoIn2 = videoinput( 'winvideo', deviceIndex2, 'YUY2_640x480' );
    end
    szFrame = [ 480 640 ];
end
if szAcquisition == 1

	videoIn = videoinput( 'winvideo', deviceIndex, 'YUY2_320x240' );
	if nCameras == 2
        videoIn2 = videoinput( 'winvideo', deviceIndex2, 'YUY2_320x240' );
    end
    szFrame = [ 240 320 ];
end
if szAcquisition >= 2
    
	videoIn = videoinput( 'winvideo', deviceIndex, 'YUY2_160x120' );
    if nCameras == 2
        videoIn2 = videoinput( 'winvideo', deviceIndex2, 'YUY2_160x120' );
    end
    szFrame = [ 120 160 ];
end

% My cameras don't support an RGB return format, only YUV (specifically
% YUY2, corresponding to MATLAB's 'YCbCr'), so I don't think this command
% has any effect:
% ReturnedColorSpace = 'rgb'
% % ReturnedColorSpace = 'grayscale'
% % ReturnedColorSpace = 'YCbCr'

% preview(videoIn);
% preview(videoIn2);
% pause( nDelayTransient );

% Configure the object for manual trigger mode.
triggerconfig( videoIn, 'manual' );
if nCameras == 2
    triggerconfig( videoIn2, 'manual' );
end

% Now that the device is configured for manual triggering, call START.
% This will cause the device to send data back to MATLAB, but will not log
% frames to memory at this point.
start( videoIn )
if nCameras == 2
    start( videoIn2 )
end

if bSave && tAutoSave > 0

    strFullStemPartial = [ strFilestem '_listMotion_Partial' ];
    strFilenamePartial = [ strFullStemPartial '.mat' ];
    fid = fopen( strFilenamePartial );
    nP = 0; % number of '+'s to append to the file name.
    % While the file already exists, append '+'s to stem:
    while fid ~= -1 
        fclose( fid );
        nP = nP + 1;
        strFullStemPartial = [ strFullStemPartial '+' ];
        strFilenamePartial = [ strFullStemPartial '.mat' ];
        fid = fopen( strFilenamePartial );
    end
end

% Set up GUI window:
hDiffDisp = figure;
set( hDiffDisp, 'Visible', 'off' )
set( hDiffDisp, 'ToolBar', 'none' )
set( hDiffDisp, 'MenuBar', 'none' )
set( hDiffDisp, 'NumberTitle', 'off' )
%set( hDiffDisp, 'Color', [0 0 0] )
set( hDiffDisp, 'WindowStyle', 'modal' )
set( hDiffDisp, 'Position', [200 100 960 600] )
% set( hDiffDisp, 'CloseRequestFcn', @set_end )   % No. I don't know why.

% "Motion" idiot light.
hM = uicontrol('Style', 'pushbutton', 'String', 'Motion!', 'BackgroundColor', [1 .5 .5], ...
     'Position', [40 350 80 30] );

% "Display resolution +" pushbutton.
hDRp = uicontrol('Style', 'pushbutton', 'String', 'Display res. +', 'BackgroundColor', [.7 .9 .7], ...
     'Position', [20 300 80 20], 'Callback', 'show_scale_plus' );
% "Display resolution -" pushbutton.
hDRm = uicontrol('Style', 'pushbutton', 'String', 'Display res. -', 'BackgroundColor', [.9 .7 .7], ...
     'Position', [20 280 80 20], 'Callback', 'show_scale_minus' ); 
 
% "Show motion" pushbutton.
hSM = uicontrol('Style', 'pushbutton', 'String', 'Show motion', 'BackgroundColor', [.9 .9 .5], ...
     'Position', [20 250 80 20], 'Callback', 'show_motion' );
% "Show motion icon" pushbutton.
hSI = uicontrol('Style', 'pushbutton', 'String', ' Show icon ', 'BackgroundColor', [.6 .8 .8],...
     'Position', [20 230 80 20], 'Callback', 'show_motion_icon' );
% "Show background" pushbutton.
hSB = uicontrol('Style', 'pushbutton', 'String', ' Show image ', 'BackgroundColor', [.9 .6 .9],...
     'Position', [20 210 80 20], 'Callback', 'show_background' );
 


% % "Sensitivity +" pushbutton.
% h = uicontrol('Style', 'pushbutton', 'String', 'Sensitivity +',...
%      'Position', [50 70 80 20], 'Callback', 'sensitivity_plus' );
% % "Sensitivity -" pushbutton.
% h = uicontrol('Style', 'pushbutton', 'String', 'Sensitivity -',...
%      'Position', [50 50 80 20], 'Callback', 'sensitivity_minus' );
 
% "Thresh. +" pushbutton.
h = uicontrol('Style', 'pushbutton', 'String', 'Thresh +', 'BackgroundColor', [.9 .9 .9], ...
     'Position', [50 180 50 20], 'Callback', 'thresh_plus' );
% "Thresh. -" pushbutton.
h = uicontrol('Style', 'pushbutton', 'String', 'Thresh -', 'BackgroundColor', [.9 .9 .9], ...
     'Position', [50 160 50 20], 'Callback', 'thresh_minus' );
 
% "Start recording" pushbutton.
hR = uicontrol( 'Style', 'pushbutton', 'String', 'Start recording', 'BackgroundColor', [1 1 0], ...
     'Position', [10 120 90 30], 'Callback', 'start_recording' );
 
% "Stop" pushbutton.
h = uicontrol('Style', 'pushbutton', 'String', 'Stop', 'BackgroundColor', [1 .2 0], ...
     'Position', [10 80 50 30], 'Callback', 'set_end' );
 
figure( hDiffDisp ) 

nAccTimePointsMax = (tAccumulationMax*3600)/dtAccumulation;

% tShowscale                                            % [0 : tSpacing : log2ScaleMax]
% tShowscale = log2ScaleMax;                             % lowest resolution
tShowscale = 0;                                         % highest resolution

lengthFiltTemp = length( filtTmp );

flNoiseSubtractFactor(1:nCameras) = flNoiseSubtractFactorInit;

bEnd = false;


szFrame = [ szFrame(1) nCameras*szFrame(2) ];


set_scale_parameters % must be after setting of full szFrame


% Array initialization.
for ic = 1 : tSpacing : log2ScaleMax+1
    
    % Note: This balks when the lowest resolution frame size is not related by an
    % even power of two to the acquired image, resulting in non-integer indices.
% To Do: Sanity check, display and return error.
    szFrameIntm = szFrame/( 2^(ic-1) );

    
	uint8pyrDisplay{ic}             = zeros( [ szFrameIntm(1) szFrameIntm(2) 3 ], 'uint8'  );
	uint32pyrDisplay{ic}            = zeros( [ szFrameIntm(1) szFrameIntm(2) 3 ], 'uint32'  );
    
    uint8pyrNextClr{ic}           	= zeros( szFrameIntm, 'uint8'  );
    if ic < log2ScaleMax+1
        uint32pyrNextClrRowSum{ic}       = zeros( [ szFrameIntm(1)/(2^tSpacing) szFrameIntm(2) ], 'uint32'  );
    end
    uint32pyrNext{ic}           	= zeros( szFrameIntm, 'uint32' );
    uint32pyrLast{ic}               = zeros( szFrameIntm, 'uint32' );
%     uint32pyrRecent{ic}             = zeros( [ szFrameIntm nFramesNoiseAvg ], 'uint32' );
    uint32pyrDiffRecent{ic}         = zeros( [ szFrameIntm nFramesNoiseAvg ], 'uint32' );
    uint32pyrSumOfRecentDiff{ic}    = zeros( szFrameIntm, 'uint32' );
    uint32pyrDiffRecent{ic}         = zeros( [ szFrameIntm nFramesNoiseAvg ], 'uint32' );
    uint32pyrDiffNoisy{ic}          = zeros( szFrameIntm, 'uint32' );
    uint32pyrDiff{ic}               = zeros( szFrameIntm, 'uint32' );
    uint8pyrDiffAmplified{ic}       = zeros( szFrameIntm, 'uint8'  );      
end


listnMotionRecent( 1:nFramesRecent, 1:5, 1:nCameras ) = 0;

nAccFrames = 0;
iAccTimePoint = 0;
listAccMotion( 1:nAccTimePointsMax, 1:2, 1:nCameras ) = 0;

motionAverageY( 1:nCameras ) = 0;
motionAverageX( 1:nCameras ) = 0;

nthFrame = 0;

nMotion = 0;
meanMotion = 0;
nszBlock = 2^tSpacing;
nBlock = nszBlock^2;
nFalsePositives = 0;
iFrameRecent = 0;

             
% % Display GUI with blank image:
% figure( hDiffDisp )
% imshow( uint8pyrDisplay{tShowscale+1} );

tic
%%%%%%%%%%%
% Main Loop
% Exits main loop when "Stop" pushbutton is pressed.

tInitial  = clock;
tLastSave = clock;
tAcqCurrent = -1;
tR = 0;
tAC = 0;

nR = 0;
    
if bRecording
    
    nAccFrames = 0;
    tAccFirst = tInitial;
    nR = 0;
    
    set( hR, 'BackgroundColor', [.2 1 .2] )
    set( hR, 'String', 'Recording ...' )
else    
    
    tAccFirst( 1:6 ) = -1;
    set( hR, 'BackgroundColor', [1 1 0] )
    set( hR, 'String', 'Start recording' )   
end



while    ~bEnd ...
      &&  etime( clock, tInitial ) < tAccumulationMax*3600
    
    % Acquire image(s).
	if nCameras == 2
        % Note: not generalized to n-cameras
        uint8pyrDisplay{1}( :,                1 : szFrame(2)/2, 1:3 ) = getsnapshot( videoIn  );
        uint8pyrDisplay{1}( :, szFrame(2)/2 + 1 : szFrame(2)  , 1:3 ) = getsnapshot( videoIn2 );
    else
        uint8pyrDisplay{1} = getsnapshot( videoIn );
    end
    
    tAcqCurrent = clock;
    nthFrame = nthFrame + 1;
    iFrameRecent = iFrameRecent + 1;
    % Wrap recent frame array
    if iFrameRecent > nFramesRecent
        
        listnMotionRecent( 1:floor(nFramesRecent/2), : ) = listnMotionRecent( nFramesRecent-floor(nFramesRecent/2)+1 : nFramesRecent, : );
        listnMotionRecent( nFramesRecent-floor(nFramesRecent/2)+1 : nFramesRecent, : ) = 0;
        iFrameRecent = floor(nFramesRecent/2);
    end

    % Luma only.
    uint32pyrNext{1} = uint32( uint8pyrDisplay{1}(:,:,1) );

    % Fill raw image pyramids using block sum downsampling.
    % Note: This is done in YUV2 space, before conversion to RGB.
    uint32pyrDisplay{1} = uint32( uint8pyrDisplay{1} );
    for it = tSpacing+1 : tSpacing : log2ScaleMax+1
        
        szLastScale = size( uint8pyrDisplay{it-tSpacing} );
        szNextScale = szLastScale/nszBlock;

        % Block sum across rows.
        for j = 1 : szNextScale(1)
            jl  = (j-1)*nszBlock + 1;
            jh = j*nszBlock;
            
            for clr = 1 : 3 
                uint32pyrNextClrRowSum{it-tSpacing}( j, :, clr ) = sum( uint32pyrDisplay{it-tSpacing}( jl:jh, :, clr ), 1 );
            end
        end
            
        % Block sum across columns.
        for i = 1 : szNextScale(2)
            il  = (i-1)*nszBlock + 1;
            ih = i*nszBlock;

            for clr = 1 : 3 
                uint32pyrDisplay{it}( :, i, clr ) = sum( uint32pyrNextClrRowSum{it-tSpacing}( :, il:ih, clr ), 2 );
            end
        end

        % Copy luma channel before conversion to RGB.
% To Do: Base noise on sum, not this normalization to average.
        uint32pyrNext{it} = uint32pyrDisplay{it}(:,:,1)/(4^tShowscale);
    end
    
    % Calculate an RGB display image for only one scale, the current display scale:
    if tShowscale > 0 && bShowBackground
        uint8pyrDisplay{tShowscale+1} = uint8( uint32pyrDisplay{tShowscale+1}/(4^tShowscale) );
    end
    if bShowBackground    
        % Convert raw image to RGB format.
% uint8pyrDisplay{it} = YUY2toRGB( uint8pyrDisplay{it} );
        % Uses YUY2 to RGB converter abstracted from YUY2toRGB.m
        % http://www.mathworks.com/matlabcentral/fileexchange/26249-yuy2-to-rgb-converter

        % input is (:,:,1:3), where
        % (:,:,1) is Y, (:,:,2) is U, (:,:,3) is V

        Y = single( uint8pyrDisplay{tShowscale+1}(:,:,1) );
        U = single( uint8pyrDisplay{tShowscale+1}(:,:,2) );
        V = single( uint8pyrDisplay{tShowscale+1}(:,:,3) );

        C = Y -  16;
        D = U - 128;
        E = V - 128;

        R = uint8((298*C+409*E+128)/256);
        G = uint8((298*C-100*D-208*E+128)/256);
        B = uint8((298*C+516*D+128)/256);

        uint8pyrDisplay{tShowscale+1}(:,:,1) = R;
        uint8pyrDisplay{tShowscale+1}(:,:,2) = G;
        uint8pyrDisplay{tShowscale+1}(:,:,3) = B;
    else
        uint8pyrDisplay{tShowscale+1}(:,:,:) = 0;
    end


    if nthFrame > 1

% To Do: Do all scales need these calculations, or only the display scale?

        % Absolute difference of frames:
        uint32pyrDiffNoisy{tShowscale+1} = uint32( abs( int16( uint32pyrNext{tShowscale+1} ) - int16( uint32pyrLast{tShowscale+1} ) ) );
        % Subtract running average of difference noise:
        if nCameras > 1
            for iC = 1:nCameras
                
                uint32pyrDiff{tShowscale+1}( :, 1 + (iC-1)*szFrame(2)/nCameras : iC*szFrame(2)/nCameras ) ...
                        = uint32pyrDiffNoisy{tShowscale+1}( :, 1 + (iC-1)*szFrame(2)/nCameras : iC*szFrame(2)/nCameras ) ...
                          - (flNoiseSubtractFactor(iC)/nFramesNoiseAvg)*uint32pyrSumOfRecentDiff{tShowscale+1}( :, 1 + (iC-1)*szFrame(2)/nCameras : iC*szFrame(2)/nCameras );
            end
        else
            uint32pyrDiff{tShowscale+1} = uint32pyrDiffNoisy{tShowscale+1} - (flNoiseSubtractFactor/nFramesNoiseAvg)*uint32pyrSumOfRecentDiff{tShowscale+1};
        end
% To Do: Are both noisy and noise supressed images necessary?
% Can logical indexing make this more efficient?
%     lgcSubThreshold = (int16frameDiff < nLowThreshold_t);
%     int16frameDiffNoisy(  lgcSubThreshold ) = 0;
%     int16frameDiff(       lgcSubThreshold ) = 0;

        % Update running average of difference noise.
        uint32pyrSumOfRecentDiff{tShowscale+1} =   uint32pyrSumOfRecentDiff{tShowscale+1} ... 
                               - uint32pyrDiffRecent{tShowscale+1}( :, :, mod( nthFrame, nFramesNoiseAvg ) + 1 ) ...
                               + uint32pyrDiffNoisy{tShowscale+1};

        uint32pyrDiffRecent{tShowscale+1}( :, :, mod( nthFrame, nFramesNoiseAvg ) + 1 ) = uint32pyrDiffNoisy{tShowscale+1};


        % NOTE: Only using first channel, luma, for difference counting.
        % Subtract the low threshold s.t. the only difference values are 0 and positive.
        uint32pyrDiff{tShowscale+1} = uint32pyrDiff{tShowscale+1} - nLowThreshold_t;
        
        % Add yellow motion overlay to display background.
       	if bShowMotionPixels
            
            uint8pyrDiffAmplified{tShowscale+1} = uint8( nAmplifiedNoiseSlope*uint32pyrDiff{tShowscale+1} );
            
            % Add to yellow channels.
            uint8pyrDisplay{tShowscale+1}(:,:,1) = uint8pyrDisplay{tShowscale+1}(:,:,1) + uint8pyrDiffAmplified{tShowscale+1};
            uint8pyrDisplay{tShowscale+1}(:,:,2) = uint8pyrDisplay{tShowscale+1}(:,:,2) + uint8pyrDiffAmplified{tShowscale+1};
        end
        
        for iC = 1 : nCameras
            
            % Get lists of super-threshold differences.
            [ jj, ii, vv ] = find( uint32pyrDiff{tShowscale+1}( :, 1 + (iC-1)*szFrame(2)/(nCameras*2^tShowscale) : iC*szFrame(2)/(nCameras*2^tShowscale) ) );

            % Number of difference values above threshold.
            nMotionTest = length( ii );


            % Undersampling motion for high N.
            %
            % If there are a large number of differences above threshold, it
            % might take a long time to accumulate all motion statistics. 
            % An estimate is made on a fixed sample.
            %
            % Notes: This should work for finding statistics of false positives
            % and motion candidates, but it does not exclude the majority of
            % false positives from the display.
            %
            % It seems that here and below, when the statistics of false
            % positives are known, is a good time to reset the threshold for
            % false positives -- NOT like "Motion recalibration" at a fixed schedule
            % which is based on all candidates, not false positive candidates.
            %

            % To Do: Optimize this. 
            % To Do: Adjust estimated number of motion and false positive pixels. 
            % To Do: Number threshold, based on imaged dimensions.
            % To Do: Use same array?
            % To Do: This nMotionTest threshold needs to high enough to get good statistics on
            % false positives, even when most candidates are not false
            % positives.
            flFractionTested = 1;
            if nMotionTest > 2 * nMotionSamples
                
                flFractionTested = nMotionSamples/nMotionTest;

                ith = 0;
                
                jjT = 0;
                iiT = 0;
                vvT = 0;
                
                % Notes: Is the sample size large enough? Depends on the precision 
                % of estimation desired. 
                % Is the sampling suitable random? Not if there are regularites with 
                % spatial frequencies that match the sampling frequency (aliasing)
                % To Do: Adjust for middle to middle of first/last sampling.
                for iM = 1 : floor(nMotionTest/nMotionSamples) : nMotionTest  % sample nMotionSamples points
                    ith = ith + 1;
            % To Do: Preallocate temporary vectors with more than enough room. Only 
            % assign the used values making sure that the final vectors only include 
            % current values.
                    jjT(ith) = jj(iM);
                    iiT(ith) = ii(iM);
                    vvT(ith) = vv(iM);
                end
                jj = jjT;
                ii = iiT;
                vv = vvT;
                nMotionTest = length( ii );
            end

            % Distinguish motion candidates and false positive by simple clustering criteria.
            %   Contiguity of n>1 pixels with a neighborhood criterion.
            %   Every pixel that is alone in it's neighborhood is considered a false
            %   positive.
            
            % To Do: 
            %   - histogram techniques for threshold adjustment to handle illumination changes?
            %   - preemptive exclusion for high density (almost filled) motion regions?
            
            nFalsePositives = 0;
            if nMotionTest > 0

                for nT = 1:nMotionTest
                    
                    % Surviving differences below this threshold without
                    % neighborhood support are condsidered false positives.
                    if vv(nT) < 1*nLowThreshold_t % factor of 2 (two subtractions of  
                                                  % nLowThreshold, the second one here) is  
                                                  % arbitrary, could be a parameter.

                        yl = max(                 1, jj(nT) - nNbrhood );
                        yh = min(    szFrameShow(1), jj(nT) + nNbrhood );
                        xl = (iC-1)*szFrameShow(2)/nCameras + max(                       1, ii(nT) - nNbrhood );
                        xh = (iC-1)*szFrameShow(2)/nCameras + min( szFrameShow(2)/nCameras, ii(nT) + nNbrhood );
                        
                        % n2Nbrhood = (yh-yl+1)*(xh-xl+1); % number of pixels in neighborhood

                        % Remove central value.
                        uint32pyrDiff{tShowscale+1}( jj(nT), (iC-1)*szFrameShow(2)/nCameras + ii(nT) ) = 0;

                        if   any( any( uint32pyrDiff{tShowscale+1}( yl:yh, xl:xh ) ) )
  
                            % Restore original value.  % Restoration display only.
                            uint32pyrDiff{tShowscale+1}( jj(nT), (iC-1)*szFrameShow(2)/nCameras + ii(nT) ) = vv(nT);   
                        else
                            nFalsePositives = nFalsePositives + 1;
                            jj(nT) = 0;
                            ii(nT) = 0;
                            vv(nT) = 0; % effectively remove from list
                        end
                    end
                end
            end

            nMotion = (nMotionTest - nFalsePositives)/flFractionTested;

            yMotion = sum(jj)/(nMotionTest - nFalsePositives);
            xMotion = sum(ii)/(nMotionTest - nFalsePositives);
 
                listnMotionRecent( iFrameRecent, 1, iC ) = etime( tAcqCurrent, tInitial );
                listnMotionRecent( iFrameRecent, 2, iC ) = nMotion;
                listnMotionRecent( iFrameRecent, 3, iC ) = yMotion;
                listnMotionRecent( iFrameRecent, 4, iC ) = xMotion;
                listnMotionRecent( iFrameRecent, 5, iC ) = sum(vv); % Sum of luminance differences 
                                                            % across super-threshold
                                                            % pixels in contribution sample,
                                                            % with zero from false positives.
            if    bRecording ... 
               && iC == nCameras       % record data from both cameras just once, after second cameras
                                       % arrays are updated
                
                % Accumulated motion estimation.
% To Do: If there is a long period without frames before the record-off button is pressed,
% the last accumulated frames will not be recorded -- a new period will not be recorded even
% though there was a valid set of frames. Fix this.

                nAccFrames = nAccFrames + 1;
                tAC = etime( tAcqCurrent, tAccFirst );

                if tAC > (nR+1)*dtAccumulation
                    
                    if tAC >= (nR+2)*dtAccumulation
                        % Insert marker for empty bins, when no frame occured in the bin interval.
                        for iZ = 1:floor( (tAC-(nR+2)*dtAccumulation)/dtAccumulation )
                            iAccTimePoint = iAccTimePoint + 1;
                            nR = nR + 1;
                            listAccMotion( iAccTimePoint, 1, 1:nCameras ) = etime( tAccFirst, tInitial ) + nR*dtAccumulation;
                            listAccMotion( iAccTimePoint, 2, 1:nCameras ) = flNotFramesInBin;
                        end
                    end
                    % Accumulate the last dtAccumulation seconds of motion estimates.
                    iAccTimePoint = iAccTimePoint + 1;
                    nR = nR + 1;
                    listAccMotion( iAccTimePoint, 1, 1:nCameras ) = etime( tAccFirst, tInitial ) + nR*dtAccumulation;
                    % Note: These lines select appropriate frames used to calculate the 
                    % "Average magnitude / frame".
                    listRecentFew = listnMotionRecent( iFrameRecent - (nAccFrames-1) : iFrameRecent, :, 1:nCameras );
                    iAccFrames = find(  listRecentFew( :, 1, 1 ) >  etime( tAccFirst, tInitial ) ...
                                      & listRecentFew( :, 1, 1 ) <= etime( tAccFirst, tInitial ) + nR*dtAccumulation );
       
%                    listAccMotion( iAccTimePoint, 2, : ) = sum( listnMotionRecent( iFrameRecent - (nAccFrames-1) : iFrameRecent - 1, 2, : ) )/nAccFrames;
                    if ~isempty( iAccFrames )
%                         length( iAccFrames )
%                         mean( listRecentFew( iAccFrames, 2, 1:nCameras ) )
                        listAccMotion( iAccTimePoint, 2, 1:nCameras ) = mean( listRecentFew( iAccFrames, 2, 1:nCameras ) );
                    else
                        listAccMotion( iAccTimePoint, 2, 1:nCameras ) = flNotFramesInBin;
                    end

                    % Reset for next accumulation time period.
                    nAccFrames = 1; % the current frame wasn't included
                end
            end

            % Temporal smoothing of estimated center of motion position.
            if    nMotion > flMotionToFalsePosThresh*nFalsePositiveTarget_t ...
               && bShowMotionIcon ...
               && nthFrame >= lengthFiltTemp

                nT = listnMotionRecent( iFrameRecent-lengthFiltTemp+1 : iFrameRecent, 2, iC );
                biT = (nT > flMotionToFalsePosThresh*nFalsePositiveTarget_t);
                filtTmpNonZero = filtTmp( biT );

%                if length( filtTmpNonZero ) > 0 % should never be false
                    
                    filtTmpNonZero = filtTmpNonZero'/sum(filtTmpNonZero);    % normalize filter
                    Yt = listnMotionRecent( iFrameRecent-lengthFiltTemp+1 : iFrameRecent, 3, iC );
                    Yt = Yt( biT );
                    Xt = listnMotionRecent( iFrameRecent-lengthFiltTemp+1 : iFrameRecent, 4, iC );
                    Xt = Xt( biT );
%                     sumN = listnMotionRecent( iFrameRecent-lengthFiltTemp+1 : iFrameRecent, 2, iC );
%                     sumN = sumN( biT );

                    motionAverageY( iC ) = sum(filtTmpNonZero.*Yt);
                    motionAverageX( iC ) = sum(filtTmpNonZero.*Xt);
            end

            % Find the mean of the number of motion pixels over the last
            % several frames (an arbitrary number of frames, only for display).
            if nthFrame > 49
                meanMotion = mean( listnMotionRecent( iFrameRecent - 49:iFrameRecent, 2 ) );
            end


            if flNoiseSubtractFactorIncrement > 0
                if nFalsePositives < .5*nFalsePositiveTarget_t

                    flNoiseSubtractFactor(iC) = max( 0, flNoiseSubtractFactor(iC) - flNoiseSubtractFactorIncrement );
                end

                if nFalsePositives > 1.5*nFalsePositiveTarget_t

                    flNoiseSubtractFactor(iC) = flNoiseSubtractFactor(iC) + round(nFalsePositives/nFalsePositiveTarget_t)*flNoiseSubtractFactorIncrement;
                end
            end
            
            % Overlay motion icon.
            if   nMotion > flMotionToFalsePosThresh*nFalsePositiveTarget_t ...
              && bShowMotionIcon ...
              && nthFrame >= lengthFiltTemp

    %             nCursorHalfW = max( 1, round( niconMotion/(2^(tShowscale+1)) ) );

                yMT = max(              1, round( motionAverageY( iC )  - niconMotion/2 ) );
                yMB = min( szFrameShow(1), yMT + niconMotion );
                xML = max( (iC-1)*szFrameShow(2)/nCameras + 1, (iC-1)*szFrameShow(2)/nCameras + round( motionAverageX( iC ) - niconMotion/2 ) );
                xMR = min(     iC*szFrameShow(2)/nCameras    , xML + niconMotion );

                % Add to cyan channels.
                uint8pyrDisplay{tShowscale+1}( yMT:yMB, xML:xMR, 2:3 ) = uint8pyrDisplay{tShowscale+1}( yMT:yMB, xML:xMR, 2:3 ) + nAddCyan;
            end
            
        end % each camera
        
        % Display GUI,
        if bShowImage
            % ... image with overlays,
            %figure( hDiffDisp )
            imshow( uint8pyrDisplay{tShowscale+1} );
        end
        % ... caption,
        xlabel( [ 'low thresh.: ' num2str( nLowThreshold_t )  '   ' 'false pos. target: ' num2str( nFalsePositiveTarget_t )  '   ' 'mean: ' num2str( round( meanMotion ) ) '   ' 'N motion: ' num2str( sum( listnMotionRecent( iFrameRecent, 2, : ) ) ) '    ' 'False pos.: ' num2str( nFalsePositives ) '    ' 'Acc.: ' num2str( mean(flNoiseSubtractFactor) ) '    ' num2str( floor( max( listnMotionRecent( iFrameRecent, 3, : ) ) ) ) '    ' num2str( floor( max( listnMotionRecent( iFrameRecent, 4, : ) ) ) ) ] );

        % ... and motion icon.
        if max( listnMotionRecent( iFrameRecent, 2, : ) ) > flMotionToFalsePosThresh*nFalsePositiveTarget_t ...
          && nthFrame >= lengthFiltTemp
            set( hM, 'Visible', 'on' )
        else     
            set( hM, 'Visible', 'off' )
        end

    end % nthFrame > 1

    uint32pyrLast = uint32pyrNext;
    
    if    bSave && tAutoSave > 0 ...
       && etime( clock, tLastSave ) > tAutoSave*60
   
        % Trim timeseries to actual length.
        listnMotionRecentPartial    = listnMotionRecent( 1:iFrameRecent, :, : );
        listAccMotionPartial        = listAccMotion( 1:iAccTimePoint, :, : );

        save( strFilenamePartial, 'listAccMotionPartial', 'listnMotionRecentPartial', 'tInitial' );
        
        if bSaveDLM 
            
            tvvp( 1:iAccTimePoint, 1 ) = listAccMotionPartial( 1:iAccTimePoint, 1, 1 );
            tvvp( 1:iAccTimePoint, 2 ) = listAccMotionPartial( 1:iAccTimePoint, 2, 1 );
            if nCameras == 2
                tvvp( 1:iAccTimePoint, 3 ) = listAccMotionPartial( 1:iAccTimePoint, 2, 2 );
            end
            strFilenamePartialTXT = [ strFullStemPartial '.txt' ];
            dlmwrite( strFilenamePartialTXT, tvvp, ' ' );
        end
        
        tLastSave = clock;
    end
    
    if flDelayBetween > .000001
        pause( flDelayBetween );
    end

end
% Main loop.
%%%%%%%%%%%%
elapsedTime = toc


% Find the time per frame and effective frame rate.
timePerFrame        = elapsedTime/nthFrame;
effectiveFrameRate  = 1/timePerFrame


% Clean up.
close( hDiffDisp )

stop(videoIn)
delete(videoIn)
if nCameras == 2
    stop(videoIn2)
    delete(videoIn2)
end


% Trim timeseries to actual length.
listnMotionRecent = listnMotionRecent( 1:iFrameRecent, :, : );
listAccMotion = listAccMotion( 1:iAccTimePoint, :, : );

if bSave 
    
%     save( [ strFilestem '_listMotion.mat' ], 'listAccMotion', 'listnMotionRecent', 'tInitial' );

    strFullStem = [ strFilestem '_listMotion' ];
    strFilename = [ strFullStem '.mat' ];
    fid = fopen( strFilename );
    nP = 0; % number of '+'s to append to the file name.
    % While the file already exists:
    while fid ~= -1 
        fclose( fid );
        nP = nP + 1;
        strFullStem = [ strFullStem '+' ];
        strFilename = [ strFullStem '.mat' ];
        fid = fopen( strFilename );
    end

    if bSaveMAT  
        save( strFilename, 'listAccMotion', 'listnMotionRecent', 'tInitial' );
    end
    if bSaveXLS
        strFilename = [ strFullStem '.xls' ];
        dlmwrite( strFilename, listAccMotion, ' ' );
    end
    if bSaveDLM 
        tvv( 1:iAccTimePoint, 1 ) = listAccMotion( 1:iAccTimePoint, 1, 1 );
        tvv( 1:iAccTimePoint, 2 ) = listAccMotion( 1:iAccTimePoint, 2, 1 );
        if nCameras == 2
            tvv( 1:iAccTimePoint, 3 ) = listAccMotion( 1:iAccTimePoint, 2, 2 );
        end
        strFilename = [ strFullStem '.txt' ];
        dlmwrite( strFilename, tvv, ' ' );
    end

    
    % Clean up a "partial" intermediate file.
    if    tAutoSave > 0 ...
       && etime( clock, tInitial ) > tAutoSave*60
        delete( strFilenamePartial );
    end
end
 
strTitleStem = '';
if nCameras > 1
    strTitleStem = [ 'CAMERA #' num2str( iC ) ':  ' ];
end

if bShowFramePlot
    for iC = 1:nCameras

        strTitleStem = '';
        if nCameras > 1
            strTitleStem = [ 'CAMERA #' num2str( iC ) ':  ' ];
        end

        % Plot of basic summary data.
        % ?? What threshold for scatter plot?

%         % Remove first and last of most recent frames to suppress motion required for startup and 
%         % shutdown.
%         nClipBegFrames = 0;
%         nClipEndFrames = 0;
% 
%         iFramesToShow = 1 + nClipBegFrames : iFrameRecent - nClipEndFrames;
%         
%         nFramesToShow = length( iFramesToShow );
        
        if iFrameRecent > 0
        
            listValues = listnMotionRecent( :, 2, iC );
            listValues( listValues == 0 ) = 10^flDisplayZeroAs;
            listValues( listValues == 1 ) = flDisplayOnesAs;
            
            if bShowFrameTimeDiffHistogram
                dt =  listnMotionRecent( 2 : iFrameRecent    , 1, iC ) ...
                    - listnMotionRecent( 1 : iFrameRecent - 1, 1, iC );
                figure; hist(dt,1000);
            end
             
            % Frame motion magnitude bar chart.
            if iFrameRecent < 500
                
                % Bar chart colored by bin. This uses a trick to do the coloring -- not an 
                % option with standard syntax. A matrix with only diagonal elements containing 
                % values to be plotted is constructed, and a "stacked" bar chart of every 
                % column, like:
                %            >> bar(rand(10,5),'stacked') ) 
                % but with only a single non-zero bin in each stack, at sequential indices of 
                % each stack. 
                % A sparse matrix can be used to avoid memory problems with long timeseries. 
                % But this is not useful because the stacked bar function's main limitation is 
                % rendering a lot of blank (zero) values in columns. Furthermore, 'bar' does not 
                % maintain a sparse representation. So don't use this colored verion unless the 
                % number of data points is <~ 500.

%                 mtxDiagonal = sparse( nFramesToShow, nFramesToShow ); % empty sparse matrix
                mtxDiagonal = zeros( iFrameRecent ); % empty sparse matrix
                
                for iF = 1:iFrameRecent
                    mtxDiagonal( iF, iF ) = log10( listValues(iF) );
                end 
                figure; bar( listnMotionRecent( 1:iFrameRecent, 1, iC ), mtxDiagonal, 'stacked' );
                title(  [ strTitleStem 'Motion magnitude of most recent frames (color -> time)' ] )
                xlabel( 'frame time of acquisition' )
                ylabel( 'log10( Motion magnitude )' )
                xlim( [ 0 listnMotionRecent( iFrameRecent, 1, iC ) ] );
                ylim( [ log10( flNotFramesInBin )   log10( max( listnMotionRecent( :, 2, iC ) ) ) + .5 ] )
                clear mtxDiagonal;
            else

                figure; bar( listnMotionRecent( 1:iFrameRecent, 1, iC ), log10( listValues(:) ) );
                title(  [ strTitleStem 'Motion magnitude of most recent frames' ] )
                xlabel( 'frame time of acquisition' )
                ylabel( 'log10( Motion magnitude )' )
                xlim( [ 0 listnMotionRecent( iFrameRecent, 1, iC ) ] );
                ylim( [ log10( flNotFramesInBin )   log10( max( listnMotionRecent( :, 2, iC ) ) ) + .5 ] )
            end
        end
    end
end

if bShowMotionPlot  
    for iC = 1:nCameras

        strTitleStem = '';
        if nCameras > 1
            strTitleStem = [ 'CAMERA #' num2str( iC ) ':  ' ];
        end
        
        nPeriodsTotal = ceil( listnMotionRecent( iFrameRecent, 1 )/dtAccumulation );
        nTPointsToShow = iAccTimePoint;
        if nTPointsToShow > 1
             
            % Accumulated motion magnitude bar chart.
                                               
            % Construct vectors that include filler blank bars.
            listAccMotionShow = listAccMotion;
            % Replace zeros with a new display value (log10(0) = -Inf)
            listValues = listAccMotion( :, 2, iC );
              % This is done with linear interpolation of values < 1 below.
%             listValues( listValues == 0 ) = flDisplayZeroAs;
            listValues( listValues == 1 ) = flDisplayOnesAs;
            listAccMotionShow( :, 2, iC ) = listValues;


            % To show colors across the full time (to match by frame data), need to pad 
            % beginning, middle gaps and end with zero-bars. These bars need to match the 
            % width (dtAccumulation) during accumulation periods but not overlap, so there 
            % are non-visible spaces between bars in recording gaps. But they should be as 
            % dense as possible, and extend over the begin and end time.

            nPadBeg = floor( listAccMotion( 1, 1, iC ) / dtAccumulation );
            flOffsetBeg = listAccMotion( 1, 1, iC ) - nPadBeg*dtAccumulation - dtAccumulation/2;
            nPadEnd = ceil( (  listnMotionRecent( iFrameRecent, 1, iC ) ... 
                             - listAccMotion( nTPointsToShow, 1, iC ) ) / dtAccumulation ); % at least one to stretch colors over all frames.
            flOffsetEnd = listAccMotion( nTPointsToShow, 1, iC ) + dtAccumulation/2;

            % Pad beginning.
            for iP = 1 : nPadBeg

                tC( iP ) = (iP-1)*dtAccumulation + flOffsetBeg;
                vB( iP ) = flNotRecordingValue;
            end
            tTPLast = listAccMotionShow( 1, 1, iC );
            vTPLast = listAccMotionShow( 1, 2, iC );
            nTP = nPadBeg + 1;
            tC( nTP ) = listAccMotionShow( 1, 1, iC ) - dtAccumulation/2;
            vB( nTP ) = log10( listAccMotion( 1, 2, iC ) );
            for iTP = 2:nTPointsToShow

                nTP = nTP + 1;

                % If there is an interval longer than the accumulation period it must be a 
                % inter-recording period. Shorter inter-recording periods are left blank 
                % (no padding bar)
                while listAccMotionShow( iTP, 1, iC ) - tTPLast > 2*dtAccumulation
                    % Pad inter-recording period
                    tC( nTP ) = tTPLast + dtAccumulation/2;
                    vB( nTP ) = flNotRecordingValue;

                    tTPLast = tTPLast + dtAccumulation;

                    nTP = nTP + 1;
                end

                tTPLast = listAccMotionShow( iTP, 1, iC );

                % Insert bar.
                tC( nTP ) = listAccMotionShow( iTP, 1, iC ) - dtAccumulation/2;
                if listAccMotionShow( iTP, 2, iC ) >= 1
                    vB( nTP ) = log10( listAccMotionShow( iTP, 2, iC ) );
                else
                    vB( nTP ) = -listAccMotionShow( iTP, 2, iC )*flDisplayZeroAs + flDisplayZeroAs;
                end

            end
            % Pad ending.
            nEnd = 0;
            for iP = nTP + 1 : nTP + nPadEnd

               tC( iP ) = flOffsetEnd + nEnd*dtAccumulation;
               vB( iP ) = flNotRecordingValue;
               nEnd = nEnd + 1;
            end
            nTP = nTP + nPadEnd;                

%                 mtxDiagonal = sparse( nTP, nTP ); % empty sparse matrix (not useful).
            mtxDiagonal = zeros( nTP ); % empty sparse matrix
            for iTP = 1:nTP
                mtxDiagonal( iTP, iTP ) = vB( iTP );
            end
% dtAccumulation
% tC
% vB
% mtxDiagonal


            if nPeriodsTotal < 512

                figure; bar( tC, mtxDiagonal, 1, 'stacked' );
                title(  [ strTitleStem 'Motion magnitude (color -> time)' ] )
                xlabel( [ 'time, ' num2str(dtAccumulation) ' second bins'] )
                ylabel( 'log10( Average magnitude / frame )' )
                xlim( [ 0 tC( nTP ) ] )
                ylim( [ log10( flNotFramesInBin )   max( vB ) + .5 ] )

                clear mtxDiagonal;
            else

                figure; bar( tC, vB );
                title(  [ strTitleStem 'Motion magnitude' ] )
                xlabel( [ 'time, ' num2str(dtAccumulation) ' second bins'] )
                ylabel( 'log10( Average magnitude / frame )' )
                xlim( [ 0 tC( nTP ) ] )
                ylim( [ log10( flNotFramesInBin )   max( vB ) + .5 ] )
            end

            if bShowMotionCentersToo

        %       figure; scatter( listForPlot( :, 3 ), listForPlot( :, 2 ) );
                listForPlot = listnMotionRecent( :, 2:4, iC );
                iValid = find( listForPlot( :, 1 ) );
                %listForPlot( :, 3 ) = szFrame(2) - listForPlot( :, 3 );
                listForPlot( :, 2 ) = szFrame(1) - listForPlot( :, 2);

                szList = size(listForPlot);
                maxMag = log( max( listForPlot( iValid, 1 ) ) );
                szIcon = ( log( listForPlot(iValid, 1 ) )/maxMag );
                szIcon = 200*(szIcon - min(szIcon) + .1);
                %     min(szIcon)
                %     max(szIcon)

                figure; scatter3( listForPlot( iValid, 3 ), listForPlot( iValid, 2 ), max(.01, log10( listForPlot( iValid, 1 ) ) ), szIcon, 1 : length( iValid ) );
                xlim( [ 1 szFrame(2)/nCameras ] );
                ylim( [ 1 szFrame(1) ] );
                title(  [ strTitleStem 'Motion position/magnitude, most recent frames (color -> time)' ] )
                xlabel( 'x position (pixels)' )
                ylabel( 'y position (pixels)' )   
                zlabel( 'log10( Motion magnitude )' ) 

        %         figure; plot( listForPlot( :, 3 ), listForPlot( :, 2 ), 'bo' );
                figure; scatter( listForPlot( iValid, 3 ), listForPlot( iValid, 2 ), szIcon, 1 : length( iValid ) );
                xlim( [ 1 szFrame(2)/nCameras ] );
                ylim( [ 1 szFrame(1) ] );
                title(  [ strTitleStem 'Average position/magnitude of motion, most recent frames (color -> time)' ] )
                xlabel( 'x position (pixels)' )
                ylabel( 'y position (pixels)' )    
            end
        end
	end
end
    
% Power spectrum by frame.
if    bShowMotionDFT ...
   && iFrameRecent >= 64

	for iC = 1:nCameras

        L = iFrameRecent - nClipEndFrames - nClipEndFrames;

        Fs = effectiveFrameRate;      % Sampling frequency
        T =  timePerFrame;                     % Sample time
        NFFT = 2^nextpow2(L); % Next power of 2 from length of y

    % NOTE: The 5th element of list nMotion is "vv", sum of
    % luminance differences across all superthreshold pixels.
        Y = fft( listnMotionRecent( 1 + nClipBegFrames : iFrameRecent - nClipEndFrames, 5, iC ), NFFT )/L;
        f = Fs/2*linspace( 0, 1, NFFT/2+1 );

        % Plot single-sided amplitude spectrum.
        figure
        plot( f, (2*abs( Y(1:NFFT/2+1) )).^2 );
        title(  [ strTitleStem 'Temporal Power Spectrum of motion metric in most recent frames' ] )
        xlabel( 'Frequency (Hz)' )
        ylabel( 'Power' )    
    end
end

% Power spectrum of accumulated motion.
if    bShowMotionDFT ...
   && iAccTimePoint > 64

	for iC = 1:nCameras


        L = iAccTimePoint;

        Fs = iAccTimePoint/listAccMotion( iAccTimePoint, 1, iC );      % Sampling frequency
        T =  1/Fs;                                     % Sample time
        NFFT = 2^nextpow2(L); % Next power of 2 from length of y

    % NOTE: The 5th element of list nMotion is "vv", sum of
    % luminance differences across all superthreshold pixels.
        Y = fft( listAccMotion( 1:iAccTimePoint, 2, iC ), NFFT )/L;
        f = Fs/2*linspace( 0, 1, NFFT/2+1 );

        % Plot single-sided amplitude spectrum.
        figure
        plot( f, (2*abs( Y(1:NFFT/2+1) )).^2 );
        title(  [ strTitleStem 'Temporal Power Spectrum of motion' ] )
        xlabel( 'Frequency (Hz)' )
        ylabel( 'Power' )    
    end
end




function set_end

% global videoIn
% global hDiffDisp
global bEnd
bEnd = true;
% close( hDiffDisp )
% stop(videoIn)
% delete(videoIn)


function thresh_plus

global nLowThreshold
global nLowThreshold_t
global tShowscale

if nLowThreshold < 10
    nLowThreshold = nLowThreshold + 1
else
    if nLowThreshold < 20
        nLowThreshold = nLowThreshold + 2
    else
        if nLowThreshold < 50
            nLowThreshold = nLowThreshold + 5
        else
            if nLowThreshold < 100
                nLowThreshold = nLowThreshold + 10
            else
                if nLowThreshold < 240
                    nLowThreshold = nLowThreshold + 20
                else
                    nLowThreshold = 255;
                end
            end
        end
    end
end

%nLowThreshold_t = nLowThreshold/(2^tShowscale);
nLowThreshold_t = nLowThreshold/sqrt( tShowscale + 1 );



function thresh_minus

global nLowThreshold
global nLowThreshold_t
global tShowscale

if nLowThreshold <= 1
    nLowThreshold = 1
else
    if nLowThreshold <= 10
        nLowThreshold = nLowThreshold - 1
    else
        if nLowThreshold <= 20
            nLowThreshold = nLowThreshold - 2
        else
            if nLowThreshold <= 50
                nLowThreshold = nLowThreshold - 5
            else
                if nLowThreshold <= 100
                    nLowThreshold = nLowThreshold - 10
                else
                    if nLowThreshold <= 255
                        nLowThreshold = nLowThreshold - 20
                    end
                end
            end
        end
    end
end

%nLowThreshold_t = nLowThreshold/(2^tShowscale);
nLowThreshold_t = nLowThreshold/sqrt( tShowscale + 1 );

% 
% function false_pos_plus
% 
% global flFalsePositiveFactor
% global nFalsePositiveTarget
% 
% nFalsePositiveTarget   = nFalsePositiveTarget*flFalsePositiveFactor;
% 
% 
% function false_pos_minus
% 
% global flFalsePositiveFactor
% global nFalsePositiveTarget
% 
% nFalsePositiveTarget   = nFalsePositiveTarget/flFalsePositiveFactor;
%

function show_scale_plus

global tShowscale
global tSpacing
global log2ScaleMax

tShowscale = tShowscale - tSpacing;
tShowscale = tSpacing*floor( tShowscale/tSpacing );
tShowscale = min( tShowscale, tSpacing*floor( log2ScaleMax/tSpacing ) );  
tShowscale = max( tShowscale, 0 );

set_scale_parameters


function show_scale_minus

global tShowscale
global tSpacing
global log2ScaleMax

tShowscale = tShowscale + tSpacing;
tShowscale = tSpacing*floor( tShowscale/tSpacing );
tShowscale = min( tShowscale, log2ScaleMax ); 
tShowscale = max( tShowscale, 0 );

set_scale_parameters


function set_scale_parameters

global tShowscale
global tSpacing
global szFrame
global szFrameShow
global niconMotion
global sziconMotion
global log2ScaleMax
global szAcquisition
global nLowThreshold
global nLowThreshold_t
global nFalsePositiveTarget
global nFalsePositiveTarget_t
global hDRp
global hDRm

szFrameShow = szFrame/(2^tShowscale);
niconMotion = floor( sziconMotion*szFrameShow(1) );
%nLowThreshold_t = nLowThreshold/(2^tShowscale);
nLowThreshold_t = nLowThreshold/sqrt( tShowscale + 1 );
nFalsePositiveTarget_t = nFalsePositiveTarget/(2^tShowscale);


if tShowscale == 0
    set( hDRp, 'BackgroundColor', [.8 .8 .8] )
else     
    set( hDRp, 'BackgroundColor', [.7 .9 .7] )
end

if tShowscale == tSpacing*floor(log2ScaleMax/tSpacing)
    set( hDRm, 'BackgroundColor', [.8 .8 .8] )
else     
    set( hDRm, 'BackgroundColor', [.9 .7 .7] )
end


function show_motion

global bShowMotionPixels
global hSM

bShowMotionPixels = ~bShowMotionPixels;

if bShowMotionPixels
    set( hSM, 'BackgroundColor', [.9 .9 .5] )
else     
    set( hSM, 'BackgroundColor', [.8 .8 .8] )
end


function show_motion_icon

global bShowMotionIcon
global hSI

bShowMotionIcon = ~bShowMotionIcon;

if bShowMotionIcon
    set( hSI, 'BackgroundColor', [.6 .8 .8] )
else     
    set( hSI, 'BackgroundColor', [.8 .8 .8] )    
end


function show_background

global bShowBackground
global hSB

bShowBackground = ~bShowBackground;

if bShowBackground
    set( hSB, 'BackgroundColor', [.9 .6 .9] )
else     
    set( hSB, 'BackgroundColor', [.8 .8 .8] )    
end


function start_recording

global bRecording
global hR
global tAccFirst
global nAccFrames
global nR

bRecording = ~bRecording;

nAccFrames = 0;

tAccFirst = clock;
nR = 0;               

if bRecording
    set( hR, 'BackgroundColor', [.2 1 .2] )
    set( hR, 'String', 'Recording ...' )
else     
    set( hR, 'BackgroundColor', [1 1 0] )
    set( hR, 'String', 'Start recording' )
end


