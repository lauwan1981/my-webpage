function loopResponse = evaluateStateSpaceLoop(interconnection, frequenciesRadiansPerSecond, delaySeconds)
%EVALUATESTATESPACELOOP Independent loop response from the resolvent.
%   loopResponse = terra.evaluateStateSpaceLoop(interconnection,
%   frequenciesRadiansPerSecond, delaySeconds) evaluates
%       L(j w) = -C_u (j w I - A)^-1 B_v * exp(-j w tau)       (3x3xN)
%   directly from the assembled state-space interconnection. The
%   evaluation (one resolvent solve per frequency) is independent of the
%   modal residue sums and transfer-function factors of
%   terra.evaluateLoopResponse; both paths share the modal plant data and
%   the gain law (terra.computeControllerGains). Used for the
%   independent dense reference and the self-checks.

    frequencies = reshape(frequenciesRadiansPerSecond, 1, []);
    pointCount = numel(frequencies);
    stateCount = interconnection.stateCount;
    identityMatrix = eye(stateCount);
    axisCount = size(interconnection.commandOutput, 1);
    loopResponse = zeros(axisCount, axisCount, pointCount);
    for pointIndex = 1:pointCount
        laplaceValue = 1i * frequencies(pointIndex);
        resolventTimesInput = (laplaceValue * identityMatrix - ...
            interconnection.stateMatrix) \ interconnection.delayedCommandInput;
        loopResponse(:, :, pointIndex) = -(interconnection.commandOutput * ...
            resolventTimesInput) * exp(-laplaceValue * delaySeconds);
    end
end
