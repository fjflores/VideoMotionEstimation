function cropFrame = crop( frame, cropBox )
% CROP an image to the limits given in the crop box vector.
% 
% Usage:
% cropFrame = crop( frame, cropBox )
% 
% Input:
% frame: image frame to crop.
% cropBox: 4-element vector with new boundaries fro the image frame. It
% must be in the following format: [ left top right bottom ] with respect
% to the top left corner, which is ( 1, 1 ).
% 
% Output:
% cropFrame: Image cropped to the new boundaries.


cropFrame = frame(...
    cropBox( 2 ) : cropBox( 4 ), cropBox( 1 ) : cropBox( 3 ), : );


