function imFrame = get_video_frame( strFilename, iFrame, bShow, bWrite )

% imFrame = get_video_frame( strFilename, iFrame, bShow, bWrite )
%
%       Select a single frame from a video, and optionally show the image 
%       and/or write it to a PNG image file.
%
%       A utility for video motion estimation and quantification.
%
%   USAGE: imFrame = get_video_frame( 'Marks_face_test_640x480.avi', 245, true, true );
%
%   ARGUMENTS:
%
%       strFilename:    Video file name. 
%                       .avi,.mpg and.wmv recognized on Windows systems.
%                       .avi and .mov on recognized on Mac.
%
%       iFrame:         Index of frame.
%
%       bShow:          Dislay selected frame.
%
%       bWrite:         Write the image to a .png file, named
%                       [ strFilestem '-' num2str(iFrame) '.png' ]
%                       -> 'Marks_face_test_640x480-245.png'                      
%
%   RETURN VALUES:
%
%       imFrame:         H x W x 3 uint8 array.
%
%   HARDCODED:      (none)
%
%   CALLS:          (none)
%
%
% University of Oregon Brain Development Laboratory
% Mark Dow, http://lcni.uoregon.edu/~mark/
% Created     February 4, 2009
%


%%%%%%%%%%%%%%%%%%%%%%%%
% Hardcoded information:

%
%%%%%%%%%%%%%%%%%%%%%%%%

if bShow
    videoIn = VideoReader( strFilename )
else
    videoIn = VideoReader( strFilename );
end

nframes = get( videoIn, 'NumberOfFrames' );

if iFrame > nframes   
    fprintf( [ '\n\nFailed, the video only has ' num2str(nframes) ' frames. \n\n'] );
    imDiff = -1;
    return
    
end

% Read frames, and allocate memory for the output difference frame.
imFrame = read( videoIn, iFrame );
 

if bShow    
    figure
    imshow( imFrame )
    
end

if bWrite   
    strFilestem = [ strFilename( 1 : length(strFilename) - 4 ) ];
    imwrite( imFrame, [ strFilestem '-' num2str(iFrame) '.png' ] );
    
end


