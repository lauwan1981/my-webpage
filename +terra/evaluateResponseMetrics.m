function metrics = evaluateResponseMetrics(plant, controller, configuration, delaySeconds)
%EVALUATERESPONSEMETRICS Engineering outputs tied to the source requirements.
%   metrics = terra.evaluateResponseMetrics(plant, controller,
%   configuration, delaySeconds) reports, with the exact delay:
%     staticPointingErrorRadians  Kp^-1 * T_ext (exact DC response to the
%                                 orbital torque bound of the source)
%     absolutePointingErrorRatio  static error / APE requirement, per axis
%     peakPointingGain, peakPointingFrequency       max sigma_max(T_dth)
%     peakCommandGain, peakCommandFrequency         max sigma_max(T_du)
%     highBandPointingGain, highBandPointingFrequency   max over
%                                 configuration.response.highFrequencyBandRadiansPerSecond
%     noiseCommandRmsNewtonMeters, noisePointingRmsRadians   per axis, from
%                                 the star-tracker and gyro noise intensities
%                                 (variance = intensity/pi * int_0^inf |T|^2)
%     noiseIntegrationBand        band used for the noise integrals
%   Peaks use a grid followed by local refinement; integrals use the
%   trapezoidal rule on a log grid with modal points.

    response = configuration.response;
    requirements = configuration.requirements;
    [proportionalGains, ~] = terra.computeControllerGains(controller);

    metrics.staticPointingErrorRadians = ...
        requirements.orbitalDisturbanceTorqueNewtonMeters(:) ./ proportionalGains;
    metrics.absolutePointingErrorRatio = metrics.staticPointingErrorRadians ./ ...
        requirements.absolutePointingErrorRadians(:);

    band = configuration.search.bandRadiansPerSecond;
    [metrics.peakPointingGain, metrics.peakPointingFrequency] = refinedPeak(plant, ...
        controller, configuration, delaySeconds, band, 'disturbanceToPointing');
    [metrics.peakCommandGain, metrics.peakCommandFrequency] = refinedPeak(plant, ...
        controller, configuration, delaySeconds, band, 'disturbanceToCommand');
    [metrics.highBandPointingGain, metrics.highBandPointingFrequency] = refinedPeak(plant, ...
        controller, configuration, delaySeconds, response.highFrequencyBandRadiansPerSecond, ...
        'disturbanceToPointing');

    integrationFrequencies = terra.buildFrequencyGrid( ...
        response.noiseIntegrationBandRadiansPerSecond, ...
        response.noiseIntegrationGridPointCount, plant, configuration);
    transfers = terra.evaluateClosedLoopTransfers(plant, controller, configuration, ...
        integrationFrequencies, delaySeconds);
    sensors = configuration.sensors;
    axisCount = numel(proportionalGains);
    noiseIntensities = [sensors.starTrackerNoiseIntensityRadiansSquaredSeconds * ones(axisCount, 1); ...
                        sensors.gyroNoiseIntensityRadiansSquaredPerSecond * ones(axisCount, 1)];
    metrics.noiseCommandRmsNewtonMeters = noiseRms(transfers.noiseToCommand, ...
        integrationFrequencies, noiseIntensities);
    metrics.noisePointingRmsRadians = noiseRms(transfers.noiseToPointing, ...
        integrationFrequencies, noiseIntensities);
    metrics.noiseIntegrationBand = response.noiseIntegrationBandRadiansPerSecond;
end

function rmsValues = noiseRms(transferArray, frequencies, noiseIntensities)
%NOISERMS Per-output RMS for independent white noises.
    outputCount = size(transferArray, 1);
    pointCount = size(transferArray, 3);
    powerDensity = zeros(outputCount, pointCount);
    for pointIndex = 1:pointCount
        powerDensity(:, pointIndex) = abs(transferArray(:, :, pointIndex)) .^ 2 * noiseIntensities;
    end
    variance = zeros(outputCount, 1);
    for outputIndex = 1:outputCount
        variance(outputIndex) = trapz(frequencies, powerDensity(outputIndex, :)) / pi;
    end
    rmsValues = sqrt(variance);
end

function [peakValue, peakFrequency] = refinedPeak(plant, controller, configuration, ...
        delaySeconds, band, transferName)
%REFINEDPEAK Grid maximum of sigma_max followed by local refinement.
    response = configuration.response;
    frequencies = terra.buildFrequencyGrid(band, response.peakSearchGridPointCount, ...
        plant, configuration);
    gains = largestSingularValue(plant, controller, configuration, delaySeconds, ...
        frequencies, transferName);
    [peakValue, peakIndex] = max(gains);
    peakFrequency = frequencies(peakIndex);
    localMaxima = find(gains(2:end - 1) >= gains(1:end - 2) & ...
        gains(2:end - 1) > gains(3:end)) + 1;
    negativeGain = @(logFrequency) -largestSingularValue(plant, controller, ...
        configuration, delaySeconds, exp(logFrequency), transferName);
    for gridIndex = localMaxima
        [logLocation, negativeValue] = terra.brentMinimize(negativeGain, ...
            log(frequencies(gridIndex - 1)), log(frequencies(gridIndex + 1)), ...
            response.peakRefinementToleranceLogFrequency, ...
            configuration.search.brentMaximumIterations);
        if -negativeValue > peakValue
            peakValue = -negativeValue;
            peakFrequency = exp(logLocation);
        end
    end
end

function gains = largestSingularValue(plant, controller, configuration, delaySeconds, ...
        frequencies, transferName)
%LARGESTSINGULARVALUE sigma_max of one closed-loop transfer on a grid.
    transfers = terra.evaluateClosedLoopTransfers(plant, controller, configuration, ...
        frequencies, delaySeconds);
    transferArray = transfers.(transferName);
    gains = zeros(1, size(transferArray, 3));
    for pointIndex = 1:size(transferArray, 3)
        gains(pointIndex) = norm(transferArray(:, :, pointIndex), 2);
    end
end
