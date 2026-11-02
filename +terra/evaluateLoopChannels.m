function channels = evaluateLoopChannels(controller, configuration, laplaceValues, delaySeconds)
%EVALUATELOOPCHANNELS Scalar transfer factors of sensors, controller, wheel.
%   channels = terra.evaluateLoopChannels(controller, configuration,
%   laplaceValues, delaySeconds) evaluates, at the row of complex
%   frequencies s, every scalar factor of the actuator-command-end loop
%
%       L(s) = diag(c(s)) * G(s),
%       c_i(s) = (Kp_i * STR(s) + Kd_i * GYR(s) * s) * LP_i(s) * RW(s) * exp(-s*tau)
%
%   which equals K(s) H(s) G_z(s) Ga(s) with G_z = [G; s G] (attitude and
%   rate outputs), H = blkdiag(STR*I3, GYR*I3), K = LP*[Kp, Kd] and
%   Ga = RW*I3 (manuscript Section 2.1(1)). The factors are returned
%   separately because the parameter derivatives reuse them.
%
%   Output fields (1xN rows unless noted)
%       laplaceValues, starTracker, gyro, wheel, delayFactor,
%       lowpass (3xN), proportionalGains (3x1), derivativeGains (3x1),
%       sensorBlend (3xN) = Kp*STR + Kd*GYR*s,
%       channelGainWithoutDelay (3xN), channelGain (3xN)

    laplaceRow = reshape(laplaceValues, 1, []);
    pointCount = numel(laplaceRow);
    axisCount = 3;

    starBandwidth = configuration.sensors.starTrackerBandwidthRadiansPerSecond;
    gyroBandwidth = configuration.sensors.gyroBandwidthRadiansPerSecond;
    wheelFrequency = configuration.actuator.wheelNaturalFrequencyRadiansPerSecond;
    wheelDamping = configuration.actuator.wheelDampingRatio;

    channels.laplaceValues = laplaceRow;
    channels.starTracker = starBandwidth ./ (laplaceRow + starBandwidth);
    channels.gyro = gyroBandwidth ./ (laplaceRow + gyroBandwidth);
    channels.wheel = wheelFrequency ^ 2 ./ (laplaceRow .^ 2 + ...
        2 * wheelDamping * wheelFrequency * laplaceRow + wheelFrequency ^ 2);
    channels.delayFactor = exp(-laplaceRow * delaySeconds);

    [proportionalGains, derivativeGains] = terra.computeControllerGains(controller);
    channels.proportionalGains = proportionalGains;
    channels.derivativeGains = derivativeGains;

    rolloff = controller.rolloffFrequencyRadiansPerSecond(:);
    laplaceGrid = repmat(laplaceRow, axisCount, 1);
    rolloffGrid = repmat(rolloff, 1, pointCount);
    channels.lowpass = 1 ./ (1 + laplaceGrid ./ rolloffGrid) .^ 2;

    channels.sensorBlend = proportionalGains * channels.starTracker + ...
        derivativeGains * (channels.gyro .* laplaceRow);
    channels.channelGainWithoutDelay = channels.sensorBlend .* channels.lowpass .* ...
        repmat(channels.wheel, axisCount, 1);
    channels.channelGain = channels.channelGainWithoutDelay .* ...
        repmat(channels.delayFactor, axisCount, 1);
end
