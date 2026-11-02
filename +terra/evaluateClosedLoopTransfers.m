function transfers = evaluateClosedLoopTransfers(plant, controller, configuration, ...
        frequencies, delaySeconds)
%EVALUATECLOSEDLOOPTRANSFERS Disturbance and noise transfers, exact delay.
%   transfers = terra.evaluateClosedLoopTransfers(plant, controller,
%   configuration, frequencies, delaySeconds) evaluates on s = j*omega
%   (manuscript Section 2.1(1), r = 0):
%       u     = -F_u^-1 K (H G_z d + n),   theta = G (Ga e^{-s tau} u + d)
%   giving
%       disturbanceToCommand  T_du    (3x3xN)   [N m / N m]
%       disturbanceToPointing T_dth   (3x3xN)   [rad / N m]
%       noiseToCommand        T_nu    (3x6xN)   [N m / rad, N m s / rad]
%       noiseToPointing       T_nth   (3x6xN)
%   Noise columns are [star tracker x y z, gyro x y z].

    axisCount = 3;
    noiseCount = 6;
    frequencies = reshape(frequencies, 1, []);
    pointCount = numel(frequencies);
    loop = terra.evaluateLoopResponse(plant, controller, configuration, frequencies, delaySeconds);
    channels = loop.channels;
    feedbackPath = channels.sensorBlend .* channels.lowpass;
    actuatorPath = channels.wheel .* channels.delayFactor;

    transfers.frequencies = frequencies;
    transfers.disturbanceToCommand = zeros(axisCount, axisCount, pointCount);
    transfers.disturbanceToPointing = zeros(axisCount, axisCount, pointCount);
    transfers.noiseToCommand = zeros(axisCount, noiseCount, pointCount);
    transfers.noiseToPointing = zeros(axisCount, noiseCount, pointCount);
    identityMatrix = eye(axisCount);
    for pointIndex = 1:pointCount
        plantResponse = loop.plantResponse(:, :, pointIndex);
        returnDifference = loop.returnDifference(:, :, pointIndex);
        disturbanceFeedback = diag(feedbackPath(:, pointIndex)) * plantResponse;
        noiseFeedback = [diag(channels.lowpass(:, pointIndex) .* channels.proportionalGains), ...
                         diag(channels.lowpass(:, pointIndex) .* channels.derivativeGains)];
        commandFromDisturbance = -(returnDifference \ disturbanceFeedback);
        commandFromNoise = -(returnDifference \ noiseFeedback);
        transfers.disturbanceToCommand(:, :, pointIndex) = commandFromDisturbance;
        transfers.disturbanceToPointing(:, :, pointIndex) = plantResponse * ...
            (identityMatrix + actuatorPath(pointIndex) * commandFromDisturbance);
        transfers.noiseToCommand(:, :, pointIndex) = commandFromNoise;
        transfers.noiseToPointing(:, :, pointIndex) = plantResponse * ...
            actuatorPath(pointIndex) * commandFromNoise;
    end
end
