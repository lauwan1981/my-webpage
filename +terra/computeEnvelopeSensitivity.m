function sensitivity = computeEnvelopeSensitivity(context, valleys, parameterName, ...
        stepSize, crossoverValleyIndex)
%COMPUTEENVELOPESENSITIVITY Directed derivatives d+-, D+-, R+- and predictions.
%   sensitivity = terra.computeEnvelopeSensitivity(context, valleys,
%   parameterName, stepSize, crossoverValleyIndex) evaluates at every
%   candidate valley the one-sided derivatives of f_W along +e_i and
%   -e_i and combines them as in manuscript Section 3.2:
%       d+ = min_{k in A} f_k'(+e_i),   d- = min_{k in A} f_k'(-e_i)
%       D+- = h * d+-,   R+- = max(0, -D+-)
%   where A is the near-active set (valleys.activeIndices) and h is the
%   declared allowed variation stepSize. It also returns first-order
%   predictions of b after a finite step +-h for four screening rules:
%       active_set        b + D+-                         (paper Sec. 3.2)
%       branch_aware      min_k (b_k + h f_k'(+-))        (all valleys)
%       spectrum_aware    min_k min_j (sigma_jk +- h sigma_jk')
%       single_crossover  b_c + h f_c'(+-) at the main crossover valley
%   Predictions are heuristics, never certified bounds.

    valleyCount = numel(valleys.values);
    repeatedTolerance = context.configuration.search.repeatedSingularValueTolerance;
    weightedValues = terra.evaluateWeightedReturnDifference(context, valleys.frequencies);
    weightedDerivatives = terra.computeReturnDifferenceDerivative(context, ...
        valleys.frequencies, parameterName);

    singularValueCount = size(weightedValues, 1);
    slopesPositive = zeros(1, valleyCount);
    slopesNegative = zeros(1, valleyCount);
    spectrumPositive = zeros(singularValueCount, valleyCount);
    spectrumNegative = zeros(singularValueCount, valleyCount);
    for valleyIndex = 1:valleyCount
        local = terra.computeSingularValueSensitivity(weightedValues(:, :, valleyIndex), ...
            weightedDerivatives(:, :, valleyIndex), repeatedTolerance);
        slopesPositive(valleyIndex) = local.minimumSlopePositive;
        slopesNegative(valleyIndex) = local.minimumSlopeNegative;
        spectrumPositive(:, valleyIndex) = local.singularValues + stepSize * local.slopes;
        spectrumNegative(:, valleyIndex) = local.singularValues - stepSize * local.slopes;
    end

    activeIndices = valleys.activeIndices;
    sensitivity.parameterName = parameterName;
    sensitivity.stepSize = stepSize;
    sensitivity.valleySlopesPositive = slopesPositive;
    sensitivity.valleySlopesNegative = slopesNegative;
    sensitivity.unitDerivativePositive = min(slopesPositive(activeIndices));
    sensitivity.unitDerivativeNegative = min(slopesNegative(activeIndices));
    sensitivity.changePositive = stepSize * sensitivity.unitDerivativePositive;
    sensitivity.changeNegative = stepSize * sensitivity.unitDerivativeNegative;
    sensitivity.degradationPositive = max(0, -sensitivity.changePositive);
    sensitivity.degradationNegative = max(0, -sensitivity.changeNegative);

    baseline = valleys.minimumValue;
    predictions.active_set.positive = baseline + sensitivity.changePositive;
    predictions.active_set.negative = baseline + sensitivity.changeNegative;
    predictions.branch_aware.positive = min(valleys.values + stepSize * slopesPositive);
    predictions.branch_aware.negative = min(valleys.values + stepSize * slopesNegative);
    predictions.spectrum_aware.positive = min(spectrumPositive(:));
    predictions.spectrum_aware.negative = min(spectrumNegative(:));
    if isnan(crossoverValleyIndex)
        predictions.single_crossover.positive = NaN;
        predictions.single_crossover.negative = NaN;
    else
        predictions.single_crossover.positive = valleys.values(crossoverValleyIndex) + ...
            stepSize * slopesPositive(crossoverValleyIndex);
        predictions.single_crossover.negative = valleys.values(crossoverValleyIndex) + ...
            stepSize * slopesNegative(crossoverValleyIndex);
    end
    sensitivity.predictions = predictions;
end
