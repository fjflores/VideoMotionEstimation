function [ arrMotion, t, dsScale, imSumDiff ] = video_total_motion_v2(...
    strFilename, rcCrop, bShow, bWrite, offset )

% video_total_motion_v2( strFilename, rcCrop, bShow, bWrite )
%
%       Estimation of total motion based on absolute differences between
%       frames, without respect to the direction of motion that causes
%       differences.
%
%       Test program for video motion estimation and quantification.
%
%   USAGE: arrMotion = video_total_motion_v2( 'Cosmo_torso_no-instruction_640x480.avi', 0, true, true )
%           OR
%          arrMotion = video_total_motion_v2( 'Cosmo_torso_no-instruction_640x480.avi', [100 1 470 256], true, true )
%
%   ARGUMENTS:
%
%       strFilename:    Video file name.
%                       .avi,.mpg and.wmv recognized on Windows systems.
%                       .avi and .mov on recognized on Mac.
%
%       rcCrop:     	0 for full frame (no cropping)
%                       [ left top right bottom ] Cropping rectangele
%                       boundary with respect to top-left corner at ( 1, 1 ).
%                           Use get_video_frame( 'Cosmo_torso_no-instruction_640x480.avi', 1, true, false );
%                           and data cursor tool to find crop corner coordinates.
%
%       bShow:          Show progress, plot result, display, total motion image.
%
%       bWrite:         Write the total motion array to a .mat file, the
%                       plot to a .fig file, and the total motion to a .jpg
%                       file. The crop bounds are encoded in the file name.
%
%   RETURN VALUES:
%
%       arrMotion:     An array with time courses of estimated motion,
%                      one time course for each of tsMax time-scale.
%       
%       t:             A vector with timestamps for the arrMotion.
% 
%       dsScale:       Approximate 1-pixel deviation scale.
%
%   HARDCODED:
%
%       nDiffThreshold:     [1,255] Difference threshold for inclusion,
%                           independently for each 8-bit channel.
%                           It might be better use a single luminance channel
%                           particularly for speed (not yet implemented).
%
%       tsMax:          Number of temporal differences found,
%                       from nSkip*2^1 to nSkip*2^(tsMax-1)
%
%       nSkip:          Frame index increment.
%                       1 for every frame
%
%   CALLS:          (none)
%
%
% University of Oregon Brain Development Laboratory
% Mark Dow, http://lcni.uoregon.edu/~mark/
% Created     February 2, 2009
% Modified    March    5, 2009	(optional crop rectangle, total motion
%                                image, show and write options)



% Hardcoded information:
nDiffThreshold  = 20;    % [1,255] Difference threshold for inclusion,
% independently for each 8-bit channel.

% It might be better use a single luminance channel
% particularly for speed (not yet implemented).

tsMax =  2;    % Number of temporal differences to compute.

% from nSkip*2^1 to nSkip*2^(tsMax-1)
nSkip =  1;   % Decimation factor. Set to 1 for no decimation.

% check user input
if nargin < 5
    offset = 0;
    
end

fprintf( 'Preprocessing...' )
strFilestem = strFilename( 1 : length( strFilename ) - 4 );
videoIn = VideoReader( strFilename )
nFrames = get( videoIn, 'NumberOfFrames' );
frameRate = get( videoIn, 'FrameRate' );

% Get a full frame.
imFrameFull = read( videoIn, 1 );

% Default to no cropping
if rcCrop == 0
    [ m, n, z ] = size( imFrameFull );
    rcCrop = [ 1 1 n m ];
    clear m n z
    
else
    % To Do: sanity check on crop boundaries
    cropStr = strcat(...
        num2str( rcCrop( 1 ) ), '-',...
        num2str( rcCrop( 2 ) ), '-',...
        num2str( rcCrop( 3 ) ), '-',...
        num2str( rcCrop( 4 ) ) )
    strFilestem = strcat( strFilestem, cropStr );

end

% Crop image if required.
imFrame = crop( imFrameFull, rcCrop );
[ m, n, z ] = size( imFrame );

% Allocate memory for reference and difference frames.
imFrame0 = repmat( zeros( m, n, z ), 1, 1, 1, 3 );
imDiff = zeros( m, n, z );
imSumDiff = zeros( m, n, z );

for i = 1 : tsMax - 1
    imFrame0( :, :, :, i ) = imFrame;
    
end

nFrame0( 1 : tsMax - 1 ) = 1;

% create array with video block boundaries
framesPerBlock = 1200;
tmp1 = 0 : framesPerBlock : nFrames;
tmp1( end ) = [ ];
tmp2 = 1 : length( tmp1 );
startBound = tmp1 + tmp2;
endBound = [ ( startBound( 2 : end ) - 1 ) nFrames ];
% sanity check
if length( startBound ) ~= length( endBound )
    error( 'Block bounds do not match' )
    
end
nBlocks = length( startBound );

fprintf(' Done!\n')

hWait1 = waitbar(...
        0,...
        sprintf( 'Reading block 0 of %u', nBlocks ),...
        'Position', [ 517 583 288 60 ] );

nthDiff = 0;
nftDiff( 1 : nFrames - 1, 1 : 2, 1 : tsMax - 1 ) = 0; % currently only (:, 2, :) are used
for thisBound = 1 : nBlocks
    % set up debugging message
    fprintf(...
        'Block [ %u %u ]\n', startBound( thisBound ), endBound( thisBound ) );
    msg = sprintf( 'Processing block %u of %u', thisBound, nBlocks );
    waitbar( thisBound / nBlocks, hWait1, msg );
    
    % read block of video
    allFrames = read(...
        videoIn, [ startBound( thisBound) endBound( thisBound ) ] );
    framesPerBlock = endBound( thisBound ) - startBound( thisBound );
    
    msg = sprintf( 'Processing difference 1 of %u', framesPerBlock )
    hWait2 = waitbar( 0, msg, 'Position', [ 517 503 288 60 ] );
    
    for k = 1 : nSkip : framesPerBlock - 1        
        nthDiff = nthDiff + 1;        
        imFrameFull	= squeeze( allFrames( :, :, :, k ) );
        imFrame = crop( imFrameFull, rcCrop );
        imFrameNextFull = squeeze( allFrames( :, :, :, k + nSkip ) );
        imFrameNext = crop( imFrameNextFull, rcCrop );
        
        if ( k == 1 ) && ( thisBound == 1 )
            % Auto shift first frame difference by one pixel for scaling.
            disp( 'First frame. Obtaining scaling factor.' )
            imX1 = imFrame( :, 1 : rcCrop( 3 ) - rcCrop( 1 ) - 1, : );
            imX2 = imFrame( :, 2 : rcCrop( 3 ) - rcCrop( 1 ), : );
            x1Diff = abs( imX1 - imX2 );
            x1Scale = length( find( x1Diff > nDiffThreshold ) );
            
            imY1 = imFrame( 1 : rcCrop( 4 ) - rcCrop( 2 ) - 1, :, : );
            imY2 = imFrame( 2 : rcCrop( 4 ) - rcCrop( 2 ), :, : );
            y1Diff = abs( imY1 - imY2 );
            y1Scale = length( find( y1Diff > nDiffThreshold ) );

        end
        
        imDiff = double( abs( imFrameNext - imFrame ) );
        imSumDiff( find( imDiff > nDiffThreshold ) ) = imSumDiff( find( imDiff > nDiffThreshold ) ) + imDiff( find( imDiff > nDiffThreshold ) );
        nftDiff( nthDiff, 2, 1 ) = length( find( imDiff > nDiffThreshold ) );
        
        waitbar( k / framesPerBlock, hWait2, sprintf( 'Processing frame %u of %u', k, framesPerBlock ) );
    
    end
    close( hWait2 );

    
end
close( hWait1 );

% make variables to save
arrMotion = squeeze( nftDiff( :, 2, : ) );
t0 = 1 / frameRate + offset;
tMax = ( nFrames / frameRate ) - ( 1 / frameRate ) + offset;
t = linspace( t0, tMax, nFrames - 1 ); 

if bWrite
    saveas( gcf, [ strFilestem '_total-motion.fig' ] )
    
end

dsScale = sqrt( x1Scale * x1Scale + y1Scale * y1Scale );
fprintf( [ '\nApproximate one pixel deviation scale: ' num2str( dsScale ) ' \n\n' ] );

figure
stdFactor = dsScale ./ frameRate;
plot( t, arrMotion ./ stdFactor )
xlabel( 'time (sec)' )
ylabel( 'movement speed (pixels/sec)' )


imSumDiff = 3 .* imSumDiff ./ ( max( imSumDiff( : ) ) );
imSumDiff( find( imSumDiff > 1 ) ) = 1;

% accumulate the sumdiffs
for jj = 1 : rcCrop( 4 ) - rcCrop( 2 )
    for ii = 1 : rcCrop( 3 ) - rcCrop( 1 )
        for cc = 1 : 3
            if imSumDiff( jj, ii, cc ) > 0
                imSumDiff( jj, ii, cc ) = 1 - ( 0.8 * ( 1 - imSumDiff( jj, ii, cc ) ) );
                
            end
            
        end
        
    end
    
end


% show if desired
if bShow
    figure
    imagesc( imSumDiff )
    
end

% save if desired
if bWrite
    imwrite( imSumDiff, [ strFilestem '_sumdiff.jpg' ] );
    strFilenameOut = [ strFilestem '_total-motion.mat' ];
    save( strFilenameOut, 'arrMotion', 't', 'dsScale' )
    
end





