%
% video_supress_camera_jitter_v2( strFilename, bShow )
%
%       Block motion estimate
%
%       A utility for video motion estimation and quantification.
%
%   USAGE: video_supress_camera_jitter_v2( 'FILE0085-0.avi', true )
%
%   ARGUMENTS:
%
%       strFilename:    Video file name, .avi and .mpg recognized on
%                       Windows systems, .mov on Mac.
%
%
%   RETURN VALUES:  (none)
%
%   HARDCODED:
%
%       nframes:     	
%
%       nFrameOffset:     	
%
%       nSkip:     	
%
%       flFrameRateOut:     	
%
%       flGain:     	Image value gain of the difference image.
%                       If the value difference of one pixel in one color
%                       channel is -5, the output value of that pixel's
%                       channel is 5*16 = 80.
%   CALLS:
%
%       -> block_motion_v5.m
%           -> block_correlate_v1.m
%           -> velocity_map_CA_interpolate_v1.m     %To Do: Move call to this.
%               -> block_correlate_v1.m
%
%
% University of Oregon Brain Development Laboratory
% Mark Dow, http://lcni.uoregon.edu/~mark/
% Created   February  6, 2009
% Modified  February  8        (testing, show, motion corrected frames)
%

function video_block_motion_v2( strFilename, bShow )

%%%%%%%%%%%%%%%%%%%%%%%%
% Hardcoded information:

nframes         = 52;
% nframes         = 4;
%nFrameOffset = 310
%nFrameOffset    = 22
nFrameOffset    = 1
nSkip           = 1
flFrameRateOut  = 29.97
flGain          = 10
bWrite          = true
%
%%%%%%%%%%%%%%%%%%%%%%%%

videoIn = mmreader( strFilename )

%nframes = get( videoIn, 'NumberOfFrames' );

% Get frame size and allocate memory for output (difference frames).
imFrame         = read( videoIn, nFrameOffset );
imFrame0        = imFrame;
imFrameNext     = zeros( [size(imFrame,1) size(imFrame,2) 3 nframes ], class(imFrame) );
videoOut        = zeros( [size(imFrame,1) size(imFrame,2) 3 nframes ], class(imFrame) );
videoDiff       = zeros( [size(imFrame,1) size(imFrame,2) 3 nframes ], class(imFrame) );
velMap          = zeros( [size(imFrame,1) size(imFrame,2) 3 nframes ], class(imFrame) );

for k = nFrameOffset : nSkip : nFrameOffset + nSkip*nframes - 1
    
    frame_number = k
    
    imFrameNext = read( videoIn, k + nSkip );
    
%     imwrite( imFrame,     'tf1.png' )
%     imwrite( imFrameNext, 'tf2.png' )
    
    % To Do: Don't warp the next frame in this function.
    % To Do: Initialize storage for all velocity maps, store each one.
    [ velMap imFrameNext ] = block_motion_v5( imFrame0, imFrameNext, 4, 6, 0 );
    
    videoOut (:,:,:, (k - nFrameOffset)/nSkip + 1 ) = imFrameNext;
    videoDiff(:,:,:, (k - nFrameOffset)/nSkip + 1 ) = flGain*abs( imFrameNext - imFrame );
    
    imFrame     = imFrameNext;

end

% To Do: Optionally apply velocity maps to images.

if bShow
    
    implay( videoOut,  flFrameRateOut );
    implay( videoDiff, flFrameRateOut );
end


if bWrite
    
    movUnjittered = immovie( videoOut );
    
    strFilestem = [ strFilename( 1 : length(strFilename) - 4 ) ];

    movie2avi( movUnjittered, [ strFilestem '-unjittered' ], 'FPS', flFrameRateOut )
end

