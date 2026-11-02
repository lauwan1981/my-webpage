function singularValues = singularValueSpectrum(matrices)
%SINGULARVALUESPECTRUM Singular values of every page, descending, KxN.
%   singularValues = terra.singularValueSpectrum(matrices) returns a
%   matrix whose column n holds svd(matrices(:,:,n)) in descending order,
%   so the last row is sigma_min.

    pageCount = size(matrices, 3);
    valueCount = min(size(matrices, 1), size(matrices, 2));
    singularValues = zeros(valueCount, pageCount);
    for pageIndex = 1:pageCount
        singularValues(:, pageIndex) = svd(matrices(:, :, pageIndex));
    end
end
