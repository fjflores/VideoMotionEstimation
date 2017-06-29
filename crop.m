function cropFrame = crop( frame, cropBox )


% Default to no cropping
if cropBox == 0
    cropBox = [ 1 1 size( frame, 2 ) size( frame, 1 ) ];
    
else
    % To Do: sanity check on crop boundaries   
%     strFilestem = [ strFilestem '_' num2str( rcCrop( 1 ) ) '-' num2str( rcCrop( 2 ) )  '-' num2str( rcCrop( 3 ) ) '-' num2str( rcCrop( 4 ) ) ];

end

cropFrame = frame(...
    cropBox( 2 ) : cropBox( 4 ), cropBox( 1 ) : cropBox( 3 ), : );