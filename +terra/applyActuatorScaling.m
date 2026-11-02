function scaledMatrices = applyActuatorScaling(matrices, actuatorScale)
%APPLYACTUATORSCALING Similarity scaling W^-1 * M * W for every page.
%   scaledMatrices = terra.applyActuatorScaling(matrices, actuatorScale)
%   returns W^-1 M(:,:,n) W for W = diag(actuatorScale), i.e. element
%   (i,j) multiplied by w_j / w_i (manuscript Section 2.2). Works for
%   3x3xN arrays of return differences or their parameter derivatives.

    scaleColumn = reshape(actuatorScale, [], 1);
    axisCount = numel(scaleColumn);
    if size(matrices, 1) ~= axisCount || size(matrices, 2) ~= axisCount
        error('terra:ScalingDimension', ...
            'Scaling has %d entries but matrices are %dx%d.', ...
            axisCount, size(matrices, 1), size(matrices, 2));
    end
    pageCount = size(matrices, 3);
    similarityFactor = (1 ./ scaleColumn) * scaleColumn.';
    scaledMatrices = matrices .* repmat(similarityFactor, [1, 1, pageCount]);
end
