%
% video_real_time_test_v10( deviceIndex, strFilestem, szAcquisition, log2ScaleMax, tSpacing )
%
%	Test interface for real time motion detection and simple recognition.
%
%   Currently the program is a simple interface for differencing sequential
%   video frames, false positive estimation, and overlaying results.
%   
%   To Do: More documentation and cleanup.
%
%   USAGE: listnMotion = video_real_time_test_v10( 1, 'Motion_info_1', 2, 2, 1 );
%
%       Note: There is no built in initialization of the cameras. If the 
%             program crashes the camera will not be available after 
%             restarting. I've been using MATLAB's Image Acquisition Tool 
%             to clear access to camera devices.
%               >> imaqtool
%               Tools | Refresh Image Acquisition Hardware
%
%             There is also no attempt to find appropriate available
%             cameras. It is hardcoded to accept common webcams (and iSight
%             camera on my MacBook Pro):
%           
%                   videoinput( 'winvideo', deviceIndex, 'YUY2_640x480' );
%                   videoinput( 'winvideo', deviceIndex, 'YUY2_320x240' );
%                   videoinput( 'winvideo', deviceIndex, 'YUY2_160x120' );
%
%   ARGUMENTS:
%
%       deviceIndex: 	Index of cameras available to the system.
%
%       strFilestem:	File stem of data and representative images.
%
%       szAcquisition:  [0,2] Size of image to acquire from camera.
%                       0: 640x480
%                       1: 320x240
%                       2: 160x120
%
%       log2ScaleMax:	Largest block downsampling scale, as a power of 2.
%                       For example, log2ScaleMax = 3 results in
%                       downsampling by a factor of 2^3 = 8. For an image 
%                       acquired at 640 x 480, the largest scale will be 
%                       80 x 60.
%
%       tSpacing:       Integer spacing between scale representations, log2.
%                       For example tSpacing = 3 results in 8x8 (8 = 2^3) 
%                       block averaging between scales.
%
%
%           Multi-resolution performance:
%               15   Hz.    video_real_time_test( 1, 'Motion_info_1', 2, 2, 2 );
%     4/19/10   12.8
%     4/22/10   14.8
%     4/24/10   14.0
%
%     4/24/10   13.7 Hz.    video_real_time_test( 1, 'Motion_info_1', 2, 2, 1 );
%
%                       Lots of room at lowest possible resolution: 
%     4/19/10   20.5 Hz.    video_real_time_test( 1, 'Motion_info_1', 2, 3 );
%                       
%                       Currently the most useable high resolution alone 
%                       (without downsampling) is: 
%               15   Hz.    video_real_time_test( 1, 'Motion_info_1', 1, 0 );
%     4/19/10   18.7
%
%                       But at multiple resolution acquisition size 2 runs slow: 
%                2.7 Hz.    video_real_time_test( 1, 'Motion_info_1', 1, 1, 1 );
%     4/19/10    1.6
%     4/22/10   13.2
%                       Even skipping 2 scales is limited: 
%                7.4 Hz.    video_real_time_test( 1, 'Motion_info_1', 1, 2 );
%
%                       Skipping three scales is still fast at 15 Hz.: 
%               15   Hz.    video_real_time_test( 1, 'Motion_info_1', 1, 3 );
%     4/19/10   10.8
%
%     4/22/10 3.8-5.0 Hz.   video_real_time_test( 1, 'Motion_info_1', 0, 5, 1 );
%
%     4/24/10     8.9 Hz.   video_real_time_test( 1, 'Motion_info_1', 0, 0, 1 );
%
%
%   RETURN VALUES:
% 
%       listnMotion:	Sampled number of difference pixels above
%                       threshold, a motion metric as a function of time.
%                       listnMotion(:,1): 
%                       listnMotion(:,2): Time points relative to start of
%                                         the main loop, not necessarily
%                                         uniformly distributed.
%                       listnMotion(:,3): 
%                       listnMotion(:,4): 
%                       listnMotion(:,5): 
%
%   HARDCODED:     
% 
%     bSave = false;   % Write motion timecourse and representative images to file.
% 
%     nLowThreshold           = 8 % Initial 8-bit interframe difference threshold. 
%                                 % An absolute sequential frame difference, less 
%                                 % averaged noise*flNoiseSubtractFactor, above this
%                                 % threshold is considered a motion candidate.
% 
%     flNoiseSubtractFactor           = 2.00; % See nLowThreshold above.
%     flNoiseSubtractFactorIncrement  =  .02;	% Controls rate and resolution of noise accomodation.
%                                             % Currently accomodation operates
%                                             % on both this and nLowThreshold,
%                                             % but they should be independently
%                                             % set based on noise statistics.
% 
%     nFalsePositiveTarget = 7;
%     flFalsePositiveFactor = sqrt(2);
% 
%     flFalsePositiveRateTarget   = 60;
% 
%     flMotionToFalsePosThresh = 2;
% 
%     nFrames         = 1000000   % At 15 fps, about the fastest with luma only, 
%                                 % 10,000 frames takes 11 minutes.
% 
%     nFramesAvg      = 20;       % Time window for noise estimation. This number of frames
%                                 % need to be stored, about 1 MB/frame for 640 x 480 images.
% 
%     nDelayTransient	= 0.0;      % Initial pause, in seconds, to avoid camera transients.
%                                 % Not currently used.                            
% 
% 
%     flSensitivityFactor = sqrt(2);    % Not used?                             
%     knLow           = 2
%     knHigh          = 4
% 
%     nAmplifiedNoiseFactor = 3;
%     nHoldBlocking   = 20
%     flDelayBetween = 0.003;
% 
%     bShowMotionHistogram    = false;
%     bShowAmplifiedNoise     = true;
%     bShowMotionPixels       = true;
% 
%     bShowMotionPlot         = false;    % Plot estimation on exit.
%     bShowMotionFFT          = false;    % Plot FFT of estimated motion time series on exit.
% 
%     bShowRepresentativeImages  = false;
% 
%     sziconMotion = .03;      % Size of motion icon, as a fraction of raw image width.
% 
%     filtTmp = [ 10 25 35 50 70 100 ];   % Filter that weights recent time points, 
%                                         % with most recent at right. Used to
%                                         % smooth motion blob position estimate.
% 
%     bHold = true;                       % Not used.
% 
%
%   CALLS: 
%
%       Requires MATLAB's Image Acquisition Toolbox. Not available on Macs.
%
%       YUY2toRGB.m (YUY2 to RGB converter from
%                    http://www.mathworks.com/matlabcentral/fileexchange/26249-yuy2-to-rgb-converter)
%
% Mark Dow,           January  6, 2010
% Mark Dow, modified  January 10, 2010  (calibration, etc.)
% Mark Dow, modified  January 10, 2010  (fixing up)
% Mark Dow, modified  January 12, 2010  (rough real time calibration, stronger typing)
% Mark Dow, modified  January 16, 2010  (noise adaptation)
% Mark Dow, modified  January 21, 2010  (controls, red flag display)
% Mark Dow,           April   13, 2010  (derived from video_motion_real_time.m)
% Mark Dow, modified  April   13, 2010  (v1, backround displayed as image)
% Mark Dow, modified  April   15, 2010  (v2, started downsampling)
% Mark Dow, modified  April   15, 2010  (v3, started basic image pyramids)
% Mark Dow, modified  April   17, 2010  (v4, filtered center of motion)
% Mark Dow, modified  April   19, 2010  (v5, switch between scales)
% Mark Dow, modified  April   22, 2010  (v7, distinguishes motion/false positives)
% Mark Dow, modified  April   22, 2010  (v8, efficient image pyramid construction)
% Mark Dow, modified  April   24, 2010  (v9, experimental dynamic threshold adaptation)
% Mark Dow, modified  May     29, 2010  (v9, difference only display)
%

%
%   To Do:
%
%       Filter high frequecy motion candidates by low frequency candidates.
%           Cluster blobs by low frequency neighborhood.
%
%       Start rough motion direction estimation.
%
%       Fast and fine adaptation of noise subtraction scalar, 
%       flNoiseSubtractFactor.
%
%       Think about the best way to decouple nLowThreshold and
%       flNoiseSubtractFactor.
%
%       Sketch a more detailed flowchart of basic elements.
%
%       Optimize undersampling of motion when N is high.
%       
%       Accumulate old frames for slow motion detection when number of
%       motion hits is negligable.
%


function listnMotion = video_real_time_test_v10( deviceIndex, strFilestem, szAcquisition, log2ScaleMax, tSpacing )

global bEnd
global nLowThreshold
global flFalsePositiveFactor
global nFalsePositiveTarget
global bHold
global flSensitivityFactor
global knLow
global knHigh
global bShowMotionPixels
global bShowDiff
global tShowscale
global tSpacing
global log2ScaleMax
global nFalsePositiveTarget
global szFrame
global niconMotion
global sziconMotion
global szFrameShow
global tShowscale
global nFramesAvg
global nthFrameAvg
global szFrameShow
global niconMotion
global nFalsePositiveTarget
global flFalsePositiveRateTarget
global szAcquisition

%%%%%%%%%%%%%%%%%%%%%%
%   Hardcoded:

bSave = false;   % Write motion timecourse and representative images to file.

nLowThreshold           = 8 % Initial 8-bit interframe difference threshold. 
                            % An absolute sequential frame difference, less 
                           	% averaged noise*flNoiseSubtractFactor, above this
                          	% threshold is considered a motion candidate.
                            
flNoiseSubtractFactor           = 2.00; % See nLowThreshold above.
flNoiseSubtractFactorIncrement  =  .02;	% Controls rate and resolution of noise accomodation.
                                        % Currently accomodation operates
                                        % on both this and nLowThreshold,
                                        % but they should be independently
                                        % set based on noise statistics.

nFalsePositiveTarget = 7;
flFalsePositiveFactor = sqrt(2);

flFalsePositiveRateTarget   = 60;

flMotionToFalsePosThresh = 2;

nFrames         = 1000000   % At 15 fps, about the fastest with luma only, 
                            % 10,000 frames takes 11 minutes.

nFramesAvg      = 20;       % Time window for noise estimation. This number of frames
                            % need to be stored, about 1 MB/frame for 640 x 480 images.

nDelayTransient	= 0.0;      % Initial pause, in seconds, to avoid camera transients.
                            % Not currently used.                            


flSensitivityFactor = sqrt(2);                              
knLow           = 2
knHigh          = 4

nAmplifiedNoiseFactor = 3;
nHoldBlocking   = 20
flDelayBetween = 0.003;

bShowDiff               = false;
bShowMotionHistogram    = false;
bShowAmplifiedNoise     = true;
bShowMotionPixels       = true;

bShowMotionPlot         = false;    % Plot estimation on exit.
bShowMotionFFT          = false;    % Plot FFT of estimated motion time series on exit.

bShowRepresentativeImages  = false;

sziconMotion = .03;      % Size of motion icon, as a fraction of raw image width.

filtTmp = [ 10 25 35 50 70 100 ];   % Filter that weights recent time points, 
                                    % with most recent at right. Used to
                                    % smooth motion blob position estimate.
                                    
bHold = true;                       % Not used.

%   Hardcoded:
%%%%%%%%%%%%%%%%%%%%%%%%

tShowscale = tSpacing*floor(log2ScaleMax/tSpacing);	% [0 : tSpacing : log2ScaleMax]

lengthFiltTemp = length( filtTmp );


bShowingDiff = false;
bEnd = false;

listnMotion(1:nFrames, 1:5) = 0;

% % Get device info:
% imaqhwinfo
% dev_info = imaqhwinfo('winvideo',2)

if szAcquisition == 0
	videoIn = videoinput( 'winvideo', deviceIndex, 'YUY2_640x480' );
    szFrame = [ 480 640 ];
end
if szAcquisition == 1
    videoIn = videoinput( 'winvideo', deviceIndex, 'YUY2_320x240' );
    szFrame = [ 240 320 ];
end
if szAcquisition >= 2
    videoIn = videoinput( 'winvideo', deviceIndex, 'YUY2_160x120' );
    szFrame = [ 120 160 ];
end
% My cameras don't support an RGB return format, only YUV (specifically
% YUY2, corresponding to MATLAB's 'YCbCr'), so I don't think this command
% has any effect:
% ReturnedColorSpace = 'rgb'
% % ReturnedColorSpace = 'grayscale'
% % ReturnedColorSpace = 'YCbCr'

% preview(videoIn);
pause( nDelayTransient );

% Configure the object for manual trigger mode.
triggerconfig(videoIn, 'manual');

% Set up difference window:
hDiffDisp = figure;
set( hDiffDisp, 'Visible', 'off' )
set( hDiffDisp, 'ToolBar', 'none' )
set( hDiffDisp, 'MenuBar', 'none' )
set( hDiffDisp, 'NumberTitle', 'off' )
%set( hDiffDisp, 'Color', [0 0 0] )
set( hDiffDisp, 'WindowStyle', 'modal' )
set( hDiffDisp, 'Position', [200 100 960 600] )
% set( hDiffDisp, 'CloseRequestFcn', @clean_up )


% Now that the device is configured for manual triggering, call START.
% This will cause the device to send data back to MATLAB, but will not log
% frames to memory at this point.
start(videoIn)


% "Stop" pushbutton.
h = uicontrol('Style', 'pushbutton', 'String', 'Stop',...
     'Position', [10 15 30 20], 'Callback', 'clean_up' );
 
% "Display resolution +" pushbutton.
h = uicontrol('Style', 'pushbutton', 'String', 'Display resolution +',...
     'Position', [50 180 80 20], 'Callback', 'show_scale_plus' );
% "Display resolution -" pushbutton.
h = uicontrol('Style', 'pushbutton', 'String', 'Display resolution -',...
     'Position', [50 160 80 20], 'Callback', 'show_scale_minus' ); 
 
% "Show motion" pushbutton.
h = uicontrol('Style', 'pushbutton', 'String', 'Show motion',...
     'Position', [50 130 80 20], 'Callback', 'show_motion' );
 
% "Show diff" pushbutton.
h = uicontrol('Style', 'pushbutton', 'String', 'Show diff',...
     'Position', [50 100 80 20], 'Callback', 'show_diff' );
 
% "Sensitivity +" pushbutton.
h = uicontrol('Style', 'pushbutton', 'String', 'Sensitivity +',...
     'Position', [50 70 80 20], 'Callback', 'sensitivity_plus' );
% "Sensitivity -" pushbutton.
h = uicontrol('Style', 'pushbutton', 'String', 'Sensitivity -',...
     'Position', [50 50 80 20], 'Callback', 'sensitivity_minus' );
 
% "Thresh. +" pushbutton.
h = uicontrol('Style', 'pushbutton', 'String', 'Thresh +',...
     'Position', [50 25 50 20], 'Callback', 'thresh_plus' );
% "Thresh. -" pushbutton.
h = uicontrol('Style', 'pushbutton', 'String', 'Thresh -',...
     'Position', [50 5 50 20], 'Callback', 'thresh_minus' );
 
% % "False Pos. +" pushbutton.
% h = uicontrol('Style', 'pushbutton', 'String', 'False Pos. +',...
%      'Position', [110 25 70 20], 'Callback', 'false_pos_plus' );
% % "False Pos. -" pushbutton.
% h = uicontrol('Style', 'pushbutton', 'String', 'False Pos. -',...
%      'Position', [110 5 70 20], 'Callback', 'false_pos_minus' );
%  
% % "Hold" pushbutton.
% h = uicontrol('Style', 'pushbutton', 'String', 'Hold',...
%      'Position', [190 15 30 20], 'Callback', 'toggle_hold' );
 
% "Motion" idiot light.
hM = uicontrol('Style', 'pushbutton', 'String', 'Motion!', 'BackgroundColor', [1 0 0], ...
     'Position', [10 150 150 300], 'Callback', 'thresh_minus' );
 
 
set_scale_parameters
% szFrameShow = szFrame/(2^tShowscale);
% niconMotion = floor( sziconMotion*szFrameShow(2) );
% nFalsePositiveTarget = max( 1, szFrameShow(1)*szFrameShow(2)*flFalsePositiveRateTarget/(2^(2*log2ScaleMax)) );


% int16frameNext      = uint16( zeros( szFrameShow ) );
% int16frameLast      = uint16( zeros( szFrameShow ) );
% int16frameDiff      = uint16( zeros( szFrameShow ) );
% int16frameDiffNoisy = uint16( zeros( szFrameShow ) );
% lgcSubThreshold     = logical( int16frameDiff );

for ic = 1 : tSpacing : log2ScaleMax+1
    
    % Note: This balks when the lowest resolution frame size is not related by an
    % even power of two to the acquired image, resulting in non-integer indices.
    szFrameIntm = szFrame/( 2^(ic-1) );
    
    uint8pyrNextClr{ic}           	= zeros( szFrameIntm, 'uint8'  );
    if ic < log2ScaleMax+1
        uint8pyrNextClrRowSum{ic}       = zeros( [ szFrameIntm(1)/(2^tSpacing) szFrameIntm(2) ], 'uint8'  );
    end
    uint16pyrNext{ic}           	= zeros( szFrameIntm, 'uint16' );
    uint16pyrLast{ic}               = zeros( szFrameIntm, 'uint16' );
%     uint16pyrRecent{ic}             = zeros( [ szFrameIntm nFramesAvg ], 'uint16' );
    uint16pyrDiffRecent{ic}         = zeros( [ szFrameIntm nFramesAvg ], 'uint16' );
    uint16pyrSumOfRecentDiff{ic}    = zeros( szFrameIntm, 'uint16' );
    uint16pyrDiffRecent{ic}         = zeros( [ szFrameIntm nFramesAvg ], 'uint16' );
    uint8pyrDiffAmplified{ic}       = zeros( szFrameIntm, 'uint8'  );
    uint16pyrDiffNoisy{ic}          = zeros( szFrameIntm, 'uint16' );
    uint16pyrDiff{ic}               = zeros( szFrameIntm, 'uint16' );
end

% Get estimate of backround average and deviation of noise.
nthFrameAvg = 0;
% int16SumOfRecentDiff    = uint16( zeros( szFrameShow ) );
% int16framesRecent	    = uint16( zeros( szFrameShow(1), szFrameShow(2), nFramesAvg ) );
% int16framesDiffRecent	= uint16( zeros( szFrameShow(1), szFrameShow(2), nFramesAvg ) );
motionRecent( 1:2, nFramesAvg ) = 0;
motionAverage(1:2) = 0;
nMotionRecent( nFramesAvg, 2 ) = 0;



%%%%%%%%%%%%
% Main loop.
% Exits main loop when "End" pushbutton is pressed.

nthFrame = 0;
nHolding = 0;
bHolding = false;

tic
initClock = clock;
bShowingDiff = true;
bHolding = true;
nMotion = 0;
meanMotion = 0;
nszBlock = 2^tSpacing;
nBlock = nszBlock^2;
nFalsePositives = 0;

figure(hDiffDisp)

while    ~bEnd ...
      && nthFrame <= nFrames
    
    nthFrame = nthFrame + 1;

    % Acquire image.
    uint8pyrNextClr{1} = getsnapshot(videoIn);
    
    % Luma only.
    uint16pyrNext{1} = uint16( uint8pyrNextClr{1}(:,:,1) );

    % Fill raw image pyramids using block average downsampling.
    % Note: This is done in YUV2 space, before conversion to RGB.
    for it = tSpacing+1 : tSpacing : log2ScaleMax+1
        
        szLastScale = size( uint8pyrNextClr{it-tSpacing} );
        szNextScale = szLastScale/nszBlock;

        % Block sum across rows.
        for j = 1 : szNextScale(1)
            jl  = (j-1)*nszBlock + 1;
            jh = j*nszBlock;
            
            for clr = 1 : 3 
                uint8pyrNextClrRowSum{it-tSpacing}( j, :, clr ) = uint8( sum( uint16( uint8pyrNextClr{it-tSpacing}( jl:jh, :, clr ) ), 1 )/nszBlock );
            end
        end
            
        % Block sum across columns.
        for i = 1 : szNextScale(2)
            il  = (i-1)*nszBlock + 1;
            ih = i*nszBlock;

            for clr = 1 : 3 
                uint8pyrNextClr{it}( :, i, clr ) = uint8( sum( uint16( uint8pyrNextClrRowSum{it-tSpacing}( :, il:ih, clr ) ), 2 )/nszBlock );
            end
        end

        
        % Copy luma channel before conversion to RGB.
        uint16pyrNext{it} = uint16( uint8pyrNextClr{it}(:,:,1) );
    end
    
	for it = 1 : tSpacing : log2ScaleMax+1
        % Convert raw image to RGB format.
        uint8pyrNextClr{it} = YUY2toRGB( uint8pyrNextClr{it} );
    end
    
    

    if nthFrame > 1

    % To Do: Do all scales need these calculations, or only the display scale?
        uint16pyrDiffNoisy{tShowscale+1} = uint16( abs( int16( uint16pyrNext{tShowscale+1} ) - int16( uint16pyrLast{tShowscale+1} ) ) );
        uint16pyrDiff{tShowscale+1} = uint16pyrDiffNoisy{tShowscale+1} - (flNoiseSubtractFactor/nFramesAvg)*uint16pyrSumOfRecentDiff{tShowscale+1};

    % To Do: Are both noisy and noise supressed images necessary?
    %     lgcSubThreshold = (int16frameDiff < nLowThreshold);
    %     int16frameDiffNoisy(  lgcSubThreshold ) = 0;
    %     int16frameDiff(       lgcSubThreshold ) = 0;

        % Update the average frame difference, used above.
        uint16pyrSumOfRecentDiff{tShowscale+1} =   uint16pyrSumOfRecentDiff{tShowscale+1} ... 
                               - uint16pyrDiffRecent{tShowscale+1}( :, :, mod( nthFrame, nFramesAvg ) + 1 ) ...
                               + uint16pyrDiffNoisy{tShowscale+1};

        uint16pyrDiffRecent{tShowscale+1}( :, :, mod( nthFrame, nFramesAvg ) + 1 ) = uint16pyrDiffNoisy{tShowscale+1};


        % NOTE: Only using first channel, luma, for difference counting.
        uint16pyrDiff{tShowscale+1} = uint16pyrDiff{tShowscale+1} - nLowThreshold;
    % To Do: Preallocate? Are these arrays created each time? Is the correct
    % length used every time?
        [ jj, ii, vv ] = find( uint16pyrDiff{tShowscale+1} );

        nMotionTest = length( ii );

        
        % Undersampling motion for high N.
        %
        % Notes: This should work for finding statistics of false positives
        % and motion candidates, but it does not exclude the majority of
        % false positives from the display
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
        if nMotionTest > 500
    %         nMotionTest
            ith = 0;
            jjT = 0;
            iiT = 0;
            vvT = 0;
            for iM = 1 : floor(nMotionTest/125) : nMotionTest
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
    %   Contiguity of n>1 pixels with a 24-neighborhood (using nNbrhood = 2) criterion.
    %   Every pixel that is alone in it's neighborhood is considered a false
    %   positive.
    %
    % To Do: 
    %   - This algorithm might drag for exceptional high change frames. Do 
    %     something else for large values of nMotionTest. See "Undersampling 
    %     motion for high N", above.
    %   - histogram techniques for threshold adjustment to handle illumination changes?
    %   - preemptive exclusion for high density (almost filled) motion regions?
    %
    %   - Collect statistics on false positives, and dynamically reset
    %   threshold.
    %
        nFalsePositives = 0;
%         listFPValues(1:500) = 0; % To Do: Initialize ouside of main loop.
        nNbrhood = 2;

        if nMotionTest > 0

            for nT = 1:nMotionTest

                % To Do: Use a new threshold for large difference values -- only test
                % differences near threshold for false positives.
                if vv(nT) < nLowThreshold + 15

                    yl = max(              1, jj(nT) - nNbrhood );
                    yh = min( szFrameShow(1), jj(nT) + nNbrhood );
                    xl = max(              1, ii(nT) - nNbrhood );
                    xh = min( szFrameShow(2), ii(nT) + nNbrhood );
                    n2Nbrhood = (yh-yl+1)*(xh-xl+1);

                    % Remove central value.
                    uint16pyrDiff{tShowscale+1}( jj(nT), ii(nT) ) = 0;
        % To Do: Does use of 'reshape' make it more efficient?
        %           if   any( any( uint16pyrDiff{tShowscale+1}( yl:yh, xl:xh ) ) )
                    if   any( reshape( uint16pyrDiff{tShowscale+1}( yl:yh, xl:xh ), n2Nbrhood, 1 ) )
                        % Restore original value.
                        uint16pyrDiff{tShowscale+1}( jj(nT), ii(nT) ) = vv(nT);   
                    else
                        nFalsePositives = nFalsePositives + 1;
%                         if nFalsePositives < 500
%                             listFPValues( nFalsePositives ) = vv(nT); % Note: Not sampling false positives uniformly across image.
%                         end
                        vv(nT) = 0;
                    end
                end
            end
        end
        

        nMotion = length( ii ) - nFalsePositives;
        % coordinates, weighted by difference above threshold.
        yMotion = sum(jj.*double(vv));
        xMotion = sum(ii.*double(vv));
        vMotion = sum(vv);

        listnMotion( nthFrame, 1 ) = etime( clock, initClock );
        listnMotion( nthFrame, 2 ) = nMotion;
        listnMotion( nthFrame, 3 ) = yMotion;
        listnMotion( nthFrame, 4 ) = xMotion;
        listnMotion( nthFrame, 5 ) = vMotion;
    %     motionRecent( 1, mod( nthFrame, nFramesAvg ) + 1 ) = yMotion;
    %     motionRecent( 2, mod( nthFrame, nFramesAvg ) + 1 ) = xMotion;

        % Temporal smoothing of estimated center of motion position.
        if    nMotion > nFalsePositiveTarget ...
           && nthFrame >= lengthFiltTemp

            nT = listnMotion( nthFrame-lengthFiltTemp+1 : nthFrame, 2 );
            filtTmpNonZero = filtTmp( nT > 0 );

            filtTmpNonZero = filtTmpNonZero'/sum(filtTmpNonZero);    % normalize filter
            sumY = listnMotion( nthFrame-lengthFiltTemp+1 : nthFrame, 3 );
            sumY = sumY( nT > 0 );
            sumX = listnMotion( nthFrame-lengthFiltTemp+1 : nthFrame, 4 );
            sumX = sumX( nT > 0 );
            sumV = listnMotion( nthFrame-lengthFiltTemp+1 : nthFrame, 5 );
            sumV = sumV( nT > 0 );
            nT = nT( nT > 0 );

    %         motionAverageY = sum( filtTmpNonZero.*sumY./nT );
    %         motionAverageX = sum( filtTmpNonZero.*sumX./nT );
            motionAverageY = sum( filtTmpNonZero.*sumY./(sumV) );
            motionAverageX = sum( filtTmpNonZero.*sumX./(sumV) );
        end

%         % Motion recalibration:
%         if mod( nthFrame, nFramesAvg ) == 1
% 
%     % Sensitivity adjustments should be made on the basis of actual false
%     % positive estimate, not true positive estimates made here.
%             nMotionRecent = listnMotion( nthFrame-nFramesAvg + 1:nthFrame, 2 );
% 
%             stdMotion  =  std( nMotionRecent );
%             meanMotion = mean( nMotionRecent );
%             nMR = nMotionRecent( nMotionRecent < meanMotion + 3*stdMotion );
%             if length( nMR ) > 0
%                 stdMotion  =  std( nMotionRecent( nMotionRecent < meanMotion + 3*stdMotion ) );
%                 meanMotion = mean( nMotionRecent( nMotionRecent < meanMotion + 3*stdMotion ) );
%                 nMR = nMotionRecent( nMotionRecent < meanMotion + 3*stdMotion );
%                 if length( nMR ) > 0
%                     stdMotion  =  std( nMotionRecent( nMotionRecent < meanMotion + 3*stdMotion ) );
%                     meanMotion = mean( nMotionRecent( nMotionRecent < meanMotion + 3*stdMotion ) );
%                 else
%                     meanMotion = 0;
%                 end
%             else
%                 meanMotion = 0;
%             end
% 
%     % To Do: These should be adaptive based on an estimate of false positives,
%     % not on the low numbers of total motion. But still, it performs pretty
%     % well, except for overcompensating for constant motion.

% %     % Test dynamic resetting of threshold.
% %     if nFalsePositives > 10
% %         nLowThreshold = mean( listFPValues(1:nFalsePositives) ) + 2*std( listFPValues(1:nFalsePositives) );
% %     end
% %     if nFalsePositives == 0
% %         flNoiseSubtractFactor = max( 0, flNoiseSubtractFactor - flNoiseSubtractFactorIncrement );
% %     end
% % else % no superthreshold pixels
% %     flNoiseSubtractFactor = max( 0, flNoiseSubtractFactor - flNoiseSubtractFactorIncrement );
% %     nLowThreshold = min( 1, nLowThreshold - 1 )

if nthFrame > 20
    meanMotion = mean( listnMotion( nthFrame - 20:nthFrame, 2 ) );
end


%         if meanMotion < .7*nFalsePositiveTarget
            if nFalsePositives < 1*nFalsePositiveTarget


%                 dThresh = max( 1, nLowThreshold/3 );
%                 nLowThreshold = max( 1, nLowThreshold - round(dThresh) );

                nLowThreshold = max( 1, nLowThreshold - .1 );
                
                if nLowThreshold == 1
                    flNoiseSubtractFactor = max( 1, flNoiseSubtractFactor - flNoiseSubtractFactorIncrement );
                end
            end
    %         if meanMotion > 1.4*nFalsePositiveTarget
            if nFalsePositives > 2.4*nFalsePositiveTarget

                flNoiseSubtractFactor = flNoiseSubtractFactor + flNoiseSubtractFactorIncrement;

%                 dThresh = max( 1, nLowThreshold/3 );
%                 nLowThreshold = max( 1, nLowThreshold + round(dThresh) );
                if flNoiseSubtractFactor > 1.5
                     nLowThreshold = nLowThreshold + 1; 
                end
            end
% 
%         end % Motion recalibration

        %%%%%%%%%%%%%%%%%%%%
        % Set holding state.
        if 0
        if    ~bHold ...
           && ( knLow > 0 || knHigh > 0 )
    %        if   nMotion > knHigh*meanMotion ...
            if   nMotion > nFalsePositiveTarget ...
               | bHolding

                if    ~bHolding ...
                   & nMotion > nFalsePositiveTarget
    %                &  nMotion > knHigh*meanMotion
                    nHolding = nHoldBlocking;
                    bHolding = true;
                end

                bShowingDiff = true;
                set( hDiffDisp, 'Visible', 'on' )
            end
            if nHolding > 0
                nHolding = nHolding - 1;
            else
                bHolding = false;
            end
    %         if    nMotion < knLow*meanMotion ...
            if    nMotion < nFalsePositiveTarget ...
               & ~bHolding

                bShowingDiff = false;
                set( hDiffDisp, 'Visible', 'off' )
            end
        else

            set( hDiffDisp, 'Visible', 'on' )    
            bShowingDiff = true;
        end
    end
    % Set holding state.
    %%%%%%%%%%%%%%%%%%%%
    

    if bShowingDiff
        
        % Display difference image:
        
%         figure(hDiffDisp)
        
       	if bShowDiff
            uint8pyrNextClr{tShowscale+1}(:,:,1) = uint8(5*uint16pyrDiffRecent{tShowscale+1}( :, :, mod( nthFrame, nFramesAvg ) + 1 ) );
            uint8pyrNextClr{tShowscale+1}(:,:,2) = uint8pyrNextClr{tShowscale+1}(:,:,1);
            uint8pyrNextClr{tShowscale+1}(:,:,3) = uint8pyrNextClr{tShowscale+1}(:,:,1);
        end
           
       	if bShowMotionPixels
            
% To Do: Display images like uint8pyrFrameDiffAmplified should be single size, no matter the scale range?
            % Overlay large temporal difference pixels.
% This addition to only non-zero values is only to make the yellow motion pixels more obvious. Is it necessary
% to both subtract the threshold (above) and do this addition?
            % Add contant (another display only free parameter) do non-zero
            % difference values.
            uint16pyrDiff{tShowscale+1}( uint16pyrDiff{tShowscale+1} > 0 ) = uint16pyrDiff{tShowscale+1}( uint16pyrDiff{tShowscale+1} > 0 ) + 10;

            uint8pyrDiffAmplified{tShowscale+1} = uint8( nAmplifiedNoiseFactor*uint16pyrDiff{tShowscale+1} );
            % Add to yellow channels.
            uint8pyrNextClr{tShowscale+1}(:,:,1) = uint8pyrNextClr{tShowscale+1}(:,:,1) + uint8pyrDiffAmplified{tShowscale+1};
            uint8pyrNextClr{tShowscale+1}(:,:,2) = uint8pyrNextClr{tShowscale+1}(:,:,2) + uint8pyrDiffAmplified{tShowscale+1};
        end
        
        % Overlay motion icon.
        if   nMotion > flMotionToFalsePosThresh*nFalsePositiveTarget ...
          && nthFrame >= lengthFiltTemp
            
%             nCursorHalfW = max( 1, round( niconMotion/(2^(tShowscale+1)) ) );

            xML = max(              1, round( motionAverageX - niconMotion/2 ) );
            xMR = min( szFrameShow(2), xML + niconMotion );
            yMT = max(              1, round( motionAverageY - niconMotion/2 ) );
            yMB = min( szFrameShow(1), yMT + niconMotion );
            % Add to cyan channels.
            uint8pyrNextClr{tShowscale+1}( yMT:yMB, xML:xMR, 2:3 ) = uint8pyrNextClr{tShowscale+1}( yMT:yMB, xML:xMR, 2:3 ) + 64;
        end
       
        
        imshow( uint8pyrNextClr{tShowscale+1} );

    end
end % nthFrame > 1

%     int16frameLast = uint16pyrNext{tShowscale+1};
    uint16pyrLast = uint16pyrNext;
    
    set( hM, 'Visible', 'off' )
    if 0
%     display( [ 'mean: ' num2str( round( meanMotion ) ) '   ' 'N motion: ' num2str( nMotion ) '   ' 'Acc.: ' num2str( flNoiseSubtractFactor ) ] );
    strMotionDetected = '';
    if   (nMotion > knHigh*meanMotion) %...
       %|| bHolding
        strMotionDetected = 'MMM';
        set( hM, 'Visible', 'on' )
    else     
        set( hM, 'Visible', 'off' )
    end
    end
    
    xlabel( [ 'sensitivity: ' num2str( round( 100/knLow )/100 )  '   ' 'thrsh.: ' num2str( nLowThreshold )  '   ' 'false pos.: ' num2str( nFalsePositiveTarget )  '   ' 'mean: ' num2str( round( meanMotion ) ) '   ' 'N motion: ' num2str( nMotion ) '    ' 'False pos.: ' num2str( nFalsePositives ) '    ' 'Acc.: ' num2str( flNoiseSubtractFactor ) ] );
    
    pause( flDelayBetween );
end

% Main loop.
%%%%%%%%%%%%




elapsedTime = toc

close( hDiffDisp )

stop(videoIn)
delete(videoIn)

% Compute the time per frame and effective frame rate.
timePerFrame        = elapsedTime/nthFrame
effectiveFrameRate  = 1/timePerFrame


% frameDiffAverageCh1 = uint16pyrSumOfRecentDiff{1}(:,:,1);
% % frameAverageCh1     = uint16pyrSumOfRecent{1}(:,:,1);
% frameAverageCh1     = uint16pyrSumOfRecentDiff{1}(:,:,1);
%     
% if bShowRepresentativeImages
%     
%     figure
%     imagesc( frameDiffAverageCh1 );
%     colormap(gray)
% 
%     figure; imagesc( uint8( uint16pyrLast{1}(:,:,1) ) ); colormap(gray)
% %     figure; imshow( uint8( uint8frameLast ) );
% 
%     figure; imagesc( frameAverageCh1 ); colormap(gray)
% %     frameAverageCh1 = int16SumOfRecent;
% %     figure; imshow( frameAverageCh1 );
% 
%     frameAverageCh1Low = frameAverageCh1;
%     frameAverageCh1Low( frameAverageCh1Low > max(frameAverageCh1Low(:))/5 ) = max(frameAverageCh1Low(:))/5;
%     figure; imagesc( frameAverageCh1Low ); colormap(gray)
% 
%     frameAverageCh1High = frameAverageCh1;
%     frameAverageCh1High = frameAverageCh1High - 4*max(frameAverageCh1High(:))/5;
%     frameAverageCh1High( frameAverageCh1High < 0 ) = 0;
%     figure; imagesc( frameAverageCh1High ); colormap(gray)
% end

% Trim timeseries to actual length.
listnMotion = listnMotion( 1:nthFrame, : );

if bSave
    
    im = double(frameAverageCh1)/max( double( frameAverageCh1(:) ) );
    imwrite( im, [ strFilestem '_avgCh1.png' ] )
    
    im = double(frameDiffAverageCh1)/max( double( frameDiffAverageCh1(:) ) );
    imwrite( im, [ strFilestem '_diffavgCh1.png' ] )
    
    im = double( int16frameLast(:,:,1) );
    im = im/max( im(:) );
    imwrite( im, [ strFilestem '_lastframe.png' ] )
    
    
    save( [ strFilestem '_listMotion.mat' ], 'listnMotion' );
end

if bShowMotionPlot
    figure; plot( listnMotion );
end

if    bShowMotionFFT ...
   && nthFrame > 300
    
    figure;
    % Remove last 100 frames (7-10 seconds) because of motion required
    % for shutdown.
    L = nthFrame-100;
    Fs = effectiveFrameRate;      % Sampling frequency
    T = 1/Fs;                     % Sample time
    NFFT = 2^nextpow2(L); % Next power of 2 from length of y
    Y = fft( listnMotion( 1:nthFrame-100, 1 ), NFFT )/L;
    f = Fs/2*linspace( 0, 1, NFFT/2+1 );

    % Plot single-sided amplitude spectrum.
    plot( f, (2*abs( Y(1:NFFT/2+1) )).^2 );
    title('Power Spectrum of motion metric')
    xlabel('Frequency (Hz)')
    ylabel('Power')
end





function clean_up

% global videoIn
% global hDiffDisp
global bEnd
bEnd = true;
% close( hDiffDisp )
% stop(videoIn)
% delete(videoIn)


function thresh_plus

global nLowThreshold
nLowThreshold = nLowThreshold + 1


function thresh_minus

global nLowThreshold
nLowThreshold = nLowThreshold - 1


function false_pos_plus

global flFalsePositiveFactor
global nFalsePositiveTarget

nFalsePositiveTarget   = nFalsePositiveTarget*flFalsePositiveFactor;


function false_pos_minus

global flFalsePositiveFactor
global nFalsePositiveTarget

nFalsePositiveTarget   = nFalsePositiveTarget/flFalsePositiveFactor;


function toggle_hold

global bHold

bHold = ~bHold;


function show_scale_plus

global tShowscale
global tSpacing
global log2ScaleMax
global nLowThreshold

tShowscaleOld = tShowscale;
tShowscale = tShowscale - tSpacing;
tShowscale = tSpacing*floor( tShowscale/tSpacing );
tShowscale = min( tShowscale, tSpacing*floor( log2ScaleMax/tSpacing ) );  
tShowscale = max( tShowscale, 0 );

nLowThreshold = 15

set_scale_parameters


function show_scale_minus

global tShowscale
global tSpacing
global log2ScaleMax
global nLowThreshold

tShowscaleOld = tShowscale;
tShowscale = tShowscale + tSpacing;
tShowscale = tSpacing*floor( tShowscale/tSpacing );
tShowscale = min( tShowscale, tSpacing*floor( log2ScaleMax/tSpacing ) ); 
tShowscale = max( tShowscale, 0 );

nLowThreshold = 15


set_scale_parameters


function set_scale_parameters

global tShowscale
global szFrame
global szFrameShow
global nFalsePositiveTarget
global niconMotion
global sziconMotion
global flFalsePositiveRateTarget
global log2ScaleMax
global szAcquisition

szFrameShow = szFrame/(2^tShowscale);
niconMotion = floor( sziconMotion*szFrameShow(2) );
nFalsePositiveTarget = flFalsePositiveRateTarget/((szAcquisition + tShowscale + 1)^2) % max( 1, szFrameShow(1)*szFrameShow(2)*flFalsePositiveRateTarget );



function show_motion

global bShowMotionPixels

bShowMotionPixels = ~bShowMotionPixels;

function show_diff

global bShowDiff

bShowDiff = ~bShowDiff;


function sensitivity_plus

global flSensitivityFactor
global knLow
global knHigh

knLow   = knLow/flSensitivityFactor;
knHigh  = knHigh/flSensitivityFactor;


function sensitivity_minus

global flSensitivityFactor
global knLow
global knHigh

knLow   = knLow*flSensitivityFactor;
knHigh  = knHigh*flSensitivityFactor;


