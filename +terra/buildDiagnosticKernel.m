function kernel = buildDiagnosticKernel(plant, controller, configuration, delaySeconds, actuatorScale)
%BUILDDIAGNOSTICKERNEL Precomputed constants for fast evaluation of W^-1 F_u W.
%   kernel = terra.buildDiagnosticKernel(plant, controller, configuration,
%   delaySeconds, actuatorScale) gathers every frequency-independent
%   quantity of the modal loop L = diag(c) G (see terra.evaluateLoopResponse)
%   into flat arrays, so that terra.evaluateDiagnosticKernel needs only a
%   few vectorized operations per call. The adaptive method evaluates
%   single frequencies thousands of times; without the kernel the
%   per-call overhead, not the mathematics, would dominate its cost and
%   bias the equal-error cost comparison against it. Agreement with
%   terra.evaluateLoopResponse is a mandatory self-check
%   (terra.verifyModelConsistency).

    axisCount = size(plant.rigidResidue, 1);
    entryCount = axisCount * axisCount;
    [proportionalGains, derivativeGains] = terra.computeControllerGains(controller);
    modeCount = numel(plant.eigenvalues);
    isComplexMode = reshape(~plant.isReal, 1, []);

    kernel.axisCount = axisCount;
    kernel.rigidColumn = reshape(plant.rigidResidue, entryCount, 1);
    kernel.residueMatrix = reshape(plant.residues, entryCount, modeCount);
    kernel.eigenvalues = reshape(plant.eigenvalues, 1, []);
    kernel.conjugateResidueMatrix = conj(kernel.residueMatrix(:, isComplexMode));
    kernel.conjugateEigenvalues = conj(kernel.eigenvalues(isComplexMode));
    kernel.proportionalGains = proportionalGains;
    kernel.derivativeGains = derivativeGains;
    kernel.inverseRolloff = 1 ./ controller.rolloffFrequencyRadiansPerSecond(:);
    kernel.starBandwidth = configuration.sensors.starTrackerBandwidthRadiansPerSecond;
    kernel.gyroBandwidth = configuration.sensors.gyroBandwidthRadiansPerSecond;
    kernel.wheelFrequency = configuration.actuator.wheelNaturalFrequencyRadiansPerSecond;
    kernel.wheelDamping = configuration.actuator.wheelDampingRatio;
    kernel.delaySeconds = delaySeconds;
    % Column-major entry r of a 3x3 matrix lies in row mod(r-1, 3) + 1.
    kernel.rowOfEntry = repmat((1:axisCount)', axisCount, 1);
    diagonalStride = axisCount + 1;
    kernel.diagonalEntries = (1:diagonalStride:entryCount)';
    scaleColumn = reshape(actuatorScale, [], 1);
    kernel.similarityColumn = reshape((1 ./ scaleColumn) * scaleColumn.', entryCount, 1);
    kernel.chunkSize = configuration.search.evaluationChunkSize;
end
