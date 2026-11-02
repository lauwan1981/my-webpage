function diagnostic = evaluateMeasurementEndDiagnostic(plant, controller, configuration, delaySeconds)
%EVALUATEMEASUREMENTENDDIAGNOSTIC Auxiliary check at the measurement end.
%   diagnostic = terra.evaluateMeasurementEndDiagnostic(plant, controller,
%   configuration, delaySeconds) evaluates the measurement-end return
%   difference (manuscript Section 2.1(1))
%       F_y = I_6 + H G_z Ga e^{-s tau} K,     W_y^-1 F_y W_y
%   with y = [star tracker attitude (3); gyro rate (3)]. It is reported
%   separately and never mixed with the actuator-end minimum. Because
%   rank(H G_z Ga K) <= 3 < 6, sigma_min(F_y) <= 1 at every frequency.
%
%   Output: minimumValue, minimumFrequency, gridPointCount, note

    search = configuration.search;
    measurementScale = configuration.scaling.measurementScale(:);
    frequencies = terra.buildFrequencyGrid(search.bandRadiansPerSecond, ...
        search.initialGridPointCount, plant, configuration);
    values = measurementEndValues(plant, controller, configuration, delaySeconds, ...
        measurementScale, frequencies);
    [minimumValue, minimumIndex] = min(values);
    lowerIndex = max(minimumIndex - 1, 1);
    upperIndex = min(minimumIndex + 1, numel(frequencies));
    objective = @(logFrequency) measurementEndValues(plant, controller, configuration, ...
        delaySeconds, measurementScale, exp(logFrequency));
    [logOptimum, refinedValue] = terra.brentMinimize(objective, log(frequencies(lowerIndex)), ...
        log(frequencies(upperIndex)), search.refinementToleranceLogFrequency, ...
        search.brentMaximumIterations);
    if refinedValue < minimumValue
        minimumValue = refinedValue;
        minimumFrequency = exp(logOptimum);
    else
        minimumFrequency = frequencies(minimumIndex);
    end
    diagnostic.minimumValue = minimumValue;
    diagnostic.minimumFrequency = minimumFrequency;
    diagnostic.gridPointCount = numel(frequencies);
    diagnostic.note = 'Auxiliary; sigma_min(F_y) <= 1 because the loop gain has rank 3 in R^6.';
end

function values = measurementEndValues(plant, controller, configuration, delaySeconds, ...
        measurementScale, frequencies)
%MEASUREMENTENDVALUES sigma_min of the scaled 6x6 F_y on a grid.
    axisCount = 3;
    loop = terra.evaluateLoopResponse(plant, controller, configuration, frequencies, delaySeconds);
    channels = loop.channels;
    similarity = (1 ./ measurementScale) * measurementScale.';
    values = zeros(1, numel(frequencies));
    for pointIndex = 1:numel(frequencies)
        plantResponse = loop.plantResponse(:, :, pointIndex);
        laplaceValue = loop.laplaceValues(pointIndex);
        measuredPlant = [channels.starTracker(pointIndex) * plantResponse; ...
                         channels.gyro(pointIndex) * laplaceValue * plantResponse];
        lowpass = channels.lowpass(:, pointIndex);
        controllerMatrix = [diag(lowpass .* channels.proportionalGains), ...
                            diag(lowpass .* channels.derivativeGains)];
        actuatorFactor = channels.wheel(pointIndex) * channels.delayFactor(pointIndex);
        measurementReturnDifference = eye(2 * axisCount) + ...
            measuredPlant * actuatorFactor * controllerMatrix;
        singularValues = svd(measurementReturnDifference .* similarity);
        values(pointIndex) = singularValues(end);
    end
end
