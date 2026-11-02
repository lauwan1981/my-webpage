function weightedReturnDifference = evaluateWeightedReturnDifference(context, frequenciesRadiansPerSecond)
%EVALUATEWEIGHTEDRETURNDIFFERENCE W^-1 (I + L(j omega)) W, 3x3xN.
%   weightedReturnDifference = terra.evaluateWeightedReturnDifference(
%   context, frequenciesRadiansPerSecond) dispatches on
%   context.evaluatorKind ('modal' or 'state_space', see
%   terra.createDiagnosticContext).

    axisCount = 3;
    frequencies = reshape(frequenciesRadiansPerSecond, 1, []);
    switch context.evaluatorKind
        case 'modal'
            weightedReturnDifference = terra.evaluateDiagnosticKernel(context.kernel, frequencies);
        case 'state_space'
            loopResponse = terra.evaluateStateSpaceLoop(context.interconnection, ...
                frequencies, context.delaySeconds);
            returnDifference = loopResponse + ...
                repmat(eye(axisCount), [1, 1, numel(frequencies)]);
            weightedReturnDifference = terra.applyActuatorScaling(returnDifference, ...
                context.actuatorScale);
        otherwise
            error('terra:UnknownEvaluator', 'Unknown evaluator kind "%s".', ...
                context.evaluatorKind);
    end
end
