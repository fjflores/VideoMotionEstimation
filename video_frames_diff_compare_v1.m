%
% video_frames_diff_compare_v1( strFilename, iFrame1, iFrame2, flGain, rcCrop, bShow, bWrite )
%
%       Get absolute difference of a sequence of video frames. Each color
%       channel of the 3 x 8-bit frames are differenced independently.
%
%       A utility for video motion quantification.
%
%   USAGE: imDiff = video_frames_diff_compare_v1( 'Marks_face_test_640x480.avi', 240, 250, 8.0, [ 190 75 430 190 ], true, false );
%
%   ARGUMENTS:
%
%       strFilename:    Video file name,with three character extension. 
%                       .avi and .mpg recognized on Windows systems.
%                       .avi and .mov on recognized on Mac.
%
%       iFrame1/2:      Index of frames to be differenced. If one frame is
%                       larger than the number of frames in the video, the
%                       last frame will be used.
%
%       flGain:     	Image value gain of the difference image.
%                       If the value difference of one pixel in one color
%                       channel is -5, the output value of that pixel's
%                       channel is 5*16 = 80.
%
%       rcCrop:     	[ left top right bottom ] Cropping rectangele
%                       boundary with respect to top-left corner at ( 1, 1 ).
%                           Use get_video_frame( 'Marks_face_test_640x480.avi', 1, true, false );
%                           and data cursor tool to find crop corner coordinates.
%
%       bShow:          Show video information text in command window,
%                       and dislay difference image.
%
%       bWrite:         Write the comparison video to an AVI file, with
%                       file name:
%                           [ strFilestem '-diff-' num2str(iFrame1) '_' num2str(iFrame2) ].avi
%                       where strFilestem is extracted from the strFilename
%                       argument.
%                           -> 'Marks_face_test_640x480-diff-240_250.avi'                         
%   RETURN VALUES:
%
%       imDiff:         H x W x 3 uint8 array.
%
%   HARDCODED:
%
%       nSkip:          Frame index increment, 1 to use every frame
%
%       nInterpolate:	Temporal linear interpolation of result,
%                   	#output/#result frames. 1 for no interpolation.
%
%       flFrameRateOut: Output frame rate.
%
%   CALLS:
%
%       MATLAB Image Processing Toolbox required for:
%           -> immovie [Note that this could be avoided using the avifile
%                       and addframe functions.]
%
% University of Oregon Brain Development Laboratory
% Mark Dow, http://lcni.uoregon.edu/~mark/
% Created   February 3, 2009
% Modified  February 4, 2009	(composite difference with original, 
%                           	 crop rectangle)   
% Modified    March 16, 2009	(minor cosmetic, bShow logic bug fix) 
%

function imDiff = video_frames_diff_compare_v1( strFilename, iFrame1, iFrame2, flGain, rcCrop, bShow, bWrite )

%%%%%%%%%%%%%%%%%%%%%%%%
% Hardcoded information:

nSkip           =  1;    % Frame index increment.
                         % 1 for every frame
nInterpolate    =  1;    % Temporal linear interpolation, #output/#result frames.
                         % 1 for no interpolation 
flFrameRateOut  = 15;

%
%%%%%%%%%%%%%%%%%%%%%%%%

if bShow
    videoIn = mmreader( strFilename )
    %To Do: Print hardcoded parameters.
else
    videoIn = mmreader( strFilename );
end

nframes = get( videoIn, 'NumberOfFrames' );
    
if iFrame1 > nframes
    if bShow
        fprintf( [ '\nThe number of frames in the video is ' num2str(nframes) '. \n' ] );
        fprintf( [ 'The first frame number specified, ' num2str(iFrame1) ' is too large. \n' ] );
        fprintf( [ 'Starting at the first frame instead. \n' ] );
    end

    iFrame1 = 1;
end
if iFrame2 > nframes

    if bShow
        fprintf( [ '\nThe number of frames in the video is ' num2str(nframes) '. \n' ] );
        fprintf( [ 'The last frame will be used, not frame #' num2str(iFrame2) '. \n' ] );
    end
    
    iFrame2 = nframes;
end

if iFrame1 == iFrame2
    
    fprintf( [ '\n\nFailed, the two bracketing frame number arguements must be different. \n\n' ] );
    imDiff = -1;
    return
end

nframesOut = nInterpolate*( floor( ( iFrame2 - iFrame1 )/nSkip ) ) - ( nInterpolate - 1 ) - 1;

imFrame1 = read( videoIn, iFrame1 );
%szFrame = size( imFrame1 )
% Allocate memory for the intermediate and output difference frames.
imFrame2 = zeros( size(imFrame1) );
imDiff     = zeros( [ rcCrop(4)-rcCrop(2) rcCrop(3)-rcCrop(1) 3 ] );
imDiffLast = zeros( [ rcCrop(4)-rcCrop(2) rcCrop(3)-rcCrop(1) 3 ] );
videoDiff  = zeros( [2*( rcCrop(4)-rcCrop(2) ) rcCrop(3)-rcCrop(1) 3 nframesOut ], class(imFrame1) );

iiFrame = 0;

for iFrame = iFrame1 + nSkip : nSkip : iFrame2 - 1
    
    imFrame2 = read( videoIn, iFrame + 1 );

    % Difference and clip magnified range.
    imDiff   = flGain*abs(  double( imFrame2( rcCrop(2):rcCrop(4)-1, rcCrop(1):rcCrop(3)-1, : ) ) ...
                          - double( imFrame1( rcCrop(2):rcCrop(4)-1, rcCrop(1):rcCrop(3)-1, : ) ) );
    imDiff( find( imDiff > 255 ) ) = 255;
    
    for iInterp = 1 : nInterpolate
        
        iiFrame = iiFrame + 1;
        
        fInterp  = iInterp/double(nInterpolate);
        imDiffiInterp = imDiff*fInterp + imDiffLast*(1-fInterp);
        % Fill top of composite frame with difference image.
        videoDiff(                       1 :     rcCrop(4)-rcCrop(2)  , :, :, iiFrame ) ...
                = uint8( imDiffiInterp );
        % Fill bottom of composite frame with original image.
        videoDiff( rcCrop(4)-rcCrop(2) + 1 : 2*( rcCrop(4)-rcCrop(2) ), :, :, iiFrame ) ...
                = imFrame2( rcCrop(2):rcCrop(4)-1, rcCrop(1):rcCrop(3)-1, : );
    end

    imDiffLast = imDiff;
    imFrame1 = imFrame2;
end


if bShow
    
    implay( videoDiff, flFrameRateOut );
end

if bWrite
    
    movDiff = immovie( videoDiff );
    
    strFilestem = [ strFilename( 1 : length(strFilename) - 4 ) ];

    movie2avi( movDiff, [ strFilestem '-diff-' num2str(iFrame1) '_' num2str(iFrame2) ], 'FPS', flFrameRateOut )
end


