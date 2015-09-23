%
% video_frame_diff( strFilename, iFrame1, iFrame2, bShow, bWrite )
%
%       Get absolute difference of any pair of video frames from a file.
%       Each color channel of the 3 x 8-bit frames are differenced 
%       independently.
%
%       A utility for video motion quantification.
%
%   USAGE: imDiff = video_frame_diff( 'Marks_face_test_640x480.avi', 1, 9, 8.0, true, false );
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
%       bShow:          Show video information text in command window,
%                       and dislay difference image.
%
%       bWrite:         Write the difference image to a .png file, named
%                       [ strFilestem '-diff-' iFrame1 '_' iFrame2 '.png' ]
%                       -> 'Marks_face_test_640x480-diff-1_9.png'                      
%
%   RETURN VALUES:
%
%       imDiff:         H x W x 3 uint8 array.
%
%   HARDCODED:      (none)
%
%   CALLS:          (none)
%
%
% Mark Dow,           February 3, 2009
%

function imDiff = video_frame_diff( strFilename, iFrame1, iFrame2, flGain, bShow, bWrite )

%%%%%%%%%%%%%%%%%%%%%%%%
% Hardcoded information:

%
%%%%%%%%%%%%%%%%%%%%%%%%

if bShow
    videoIn = mmreader( strFilename )
else
    videoIn = mmreader( strFilename );
end

nframes = get( videoIn, 'NumberOfFrames' );

if bShow
    
    if iFrame1 > nframes
        fprintf( [ '\nThe number of frames in the video is ' num2str(nframes) '. \n' ] );
        fprintf( [ 'The last frame will be used, not frame #' num2str(iFrame1) '. \n' ] );

        iFrame1 = nframes;
    end
    if iFrame2 > nframes

        fprintf( [ '\nThe number of frames in the video is ' num2str(nframes) '. \n' ] );
        fprintf( [ 'The last frame will be used, not frame #' num2str(iFrame2) '. \n' ] );
        iFrame2 = nframes;
    end
end

if iFrame1 == iFrame2
    
    fprintf( [ '\n\nFailed, the two frames must be different. \n\n' ] );
    imDiff = -1;
    return
end

% Read frames, and allocate memory for the output difference frame.
imFrame1 = read( videoIn, iFrame1 );
imFrame2 = read( videoIn, iFrame2 );
imDiff   = zeros( size(imFrame1) ); 

% Difference and clip magnified range.
imDiff   = flGain*abs( double(imFrame2) - double(imFrame1) );
imDiff( find( imDiff > 255 ) ) = 255;


if bShow
    
    figure
    imshow( uint8(imDiff) )
end

if bWrite
    
    strFilestem = [ strFilename( 1 : length(strFilename) - 4 ) ];
    imwrite( uint8(imDiff), [ strFilestem '-diff-' num2str(iFrame1) '_' num2str(iFrame2) '.png' ] );
end


