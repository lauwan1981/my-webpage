function loop = evaluateLoopResponse(plant, controller, configuration, ...
        frequenciesRadiansPerSecond, delaySeconds)
%EVALUATELOOPRESPONSE Actuator-command-end loop and return difference.
%   loop = terra.evaluateLoopResponse(plant, controller, configuration,
%   frequenciesRadiansPerSecond, delaySeconds) evaluates, for s = j*omega,
%       L(s)   = K H G_z Ga exp(-s tau)   (3x3xN, loop broken at u,
%                G_z = [G; s G] attitude and rate outputs)
%       F_u(s) = I + L(s)                 (manuscript Section 2.1(1))
%   with the exact transport delay. The modal plant response G and all
%   scalar channel factors are returned for reuse by derivative code.
%
%   Output fields
%       frequencies (1xN), laplaceValues (1xN), plantResponse (3x3xN),
%       channels (see terra.evaluateLoopChannels), loopResponse,
%       returnDifference

    axisCount = 3;
    frequencies = reshape(frequenciesRadiansPerSecond, 1, []);
    laplaceValues = 1i * frequencies;
    pointCount = numel(frequencies);

    plantResponse = terra.evaluatePlantResponse(plant, laplaceValues);
    channels = terra.evaluateLoopChannels(controller, configuration, ...
        laplaceValues, delaySeconds);

    rowScale = reshape(channels.channelGain, axisCount, 1, pointCount);
    loopResponse = plantResponse .* repmat(rowScale, [1, axisCount, 1]);
    returnDifference = loopResponse + repmat(eye(axisCount), [1, 1, pointCount]);

    loop.frequencies = frequencies;
    loop.laplaceValues = laplaceValues;
    loop.plantResponse = plantResponse;
    loop.channels = channels;
    loop.loopResponse = loopResponse;
    loop.returnDifference = returnDifference;
end
