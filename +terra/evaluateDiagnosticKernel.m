function weightedReturnDifference = evaluateDiagnosticKernel(kernel, frequenciesRadiansPerSecond)
%EVALUATEDIAGNOSTICKERNEL W^-1 (I + L(j omega)) W from a precomputed kernel.
%   weightedReturnDifference = terra.evaluateDiagnosticKernel(kernel,
%   frequenciesRadiansPerSecond) returns a 3x3xN array; frequencies are
%   processed in chunks of kernel.chunkSize to bound memory use. The
%   result is mathematically equivalent to terra.evaluateLoopResponse
%   followed by terra.applyActuatorScaling and agrees with it to rounding
%   (verified by terra.verifyModelConsistency).

    axisCount = kernel.axisCount;
    frequencies = reshape(frequenciesRadiansPerSecond, 1, []);
    pointCount = numel(frequencies);
    weightedReturnDifference = zeros(axisCount, axisCount, pointCount);
    for chunkStart = 1:kernel.chunkSize:pointCount
        chunkIndices = chunkStart:min(chunkStart + kernel.chunkSize - 1, pointCount);
        weightedReturnDifference(:, :, chunkIndices) = reshape( ...
            evaluateChunk(kernel, frequencies(chunkIndices)), axisCount, axisCount, []);
    end
end

function flattened = evaluateChunk(kernel, frequencies)
%EVALUATECHUNK 9xN flattened weighted return difference for one chunk.
    axisCount = kernel.axisCount;
    laplaceRow = 1i * frequencies;
    chunkCount = numel(laplaceRow);
    laplaceColumn = laplaceRow.';

    plantFlattened = kernel.rigidColumn * (1 ./ laplaceRow .^ 2);
    if ~isempty(kernel.eigenvalues)
        directTerms = 1 ./ (repmat(laplaceColumn, 1, numel(kernel.eigenvalues)) - ...
            repmat(kernel.eigenvalues, chunkCount, 1));
        plantFlattened = plantFlattened + kernel.residueMatrix * directTerms.';
    end
    if ~isempty(kernel.conjugateEigenvalues)
        conjugateTerms = 1 ./ (repmat(laplaceColumn, 1, numel(kernel.conjugateEigenvalues)) - ...
            repmat(kernel.conjugateEigenvalues, chunkCount, 1));
        plantFlattened = plantFlattened + kernel.conjugateResidueMatrix * conjugateTerms.';
    end

    starTracker = kernel.starBandwidth ./ (laplaceRow + kernel.starBandwidth);
    gyro = kernel.gyroBandwidth ./ (laplaceRow + kernel.gyroBandwidth);
    wheel = kernel.wheelFrequency ^ 2 ./ (laplaceRow .^ 2 + ...
        2 * kernel.wheelDamping * kernel.wheelFrequency * laplaceRow + kernel.wheelFrequency ^ 2);
    delayFactor = exp(-laplaceRow * kernel.delaySeconds);
    lowpass = 1 ./ (1 + kernel.inverseRolloff * laplaceRow) .^ 2;
    channelGain = (kernel.proportionalGains * starTracker + ...
        kernel.derivativeGains * (gyro .* laplaceRow)) .* lowpass .* ...
        repmat(wheel .* delayFactor, axisCount, 1);

    flattened = plantFlattened .* channelGain(kernel.rowOfEntry, :);
    flattened(kernel.diagonalEntries, :) = flattened(kernel.diagonalEntries, :) + 1;
    flattened = flattened .* repmat(kernel.similarityColumn, 1, chunkCount);
end
