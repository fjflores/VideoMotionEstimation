function [ x1Scale, y1Scale, x1Diff, y1Diff ] = onepixdev(...
    frame, cropBox, thresh )

% ONEPIXDEV computes one pixel self-frame deviation.
% 
% Usage:
% [ x1Scale, y1Scale ] = onepixdev( frame, cropBox );
% [ x1Scale, y1Scale, x1Diff, y1Diff ] = onepixdev( frame, cropBox );
% 
% Input:
% frame: image frame.
% cropBox: 4-element vector with new boundaries fro the image frame. It
% must be in the following format: [ left top right bottom ] with respect
% to the top left corner, which is ( 1, 1 ).
% thresh: Optional. Luminance threshold for inclusion of deviation.
% Default is 0.
% 
% Output:
% x1Scale: number of x-axis differences greater than threshold.
% y1Scale: number of y-axis differences greater than threshold.
% x1Diff: difference image in the x axis.
% y1Diff: difference image in the y axis.

% If not threshold provided, include all differences.
if nargin < 3
    thresh = 0; 
     
end

imX1 = frame( :, 1 : cropBox( 3 ) - cropBox( 1 ) - 1, : );
imX2 = frame( :, 2 : cropBox( 3 ) - cropBox( 1 ), : );
x1Diff = abs( imX1 - imX2 );
x1Scale = length( find( x1Diff > thresh ) );

imY1 = frame( 1 : cropBox( 4 ) - cropBox( 2 ) - 1, :, : );
imY2 = frame( 2 : cropBox( 4 ) - cropBox( 2 ), :, : );
y1Diff = abs( imY1 - imY2 );
y1Scale = length( find( y1Diff > thresh ) );