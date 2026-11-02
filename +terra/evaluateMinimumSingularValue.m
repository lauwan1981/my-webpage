function minimumSingularValue = evaluateMinimumSingularValue(context, frequencyRadiansPerSecond)
%EVALUATEMINIMUMSINGULARVALUE Scalar diagnostic f_W at one frequency.
%   minimumSingularValue = terra.evaluateMinimumSingularValue(context,
%   frequencyRadiansPerSecond) returns sigma_min(W^-1 F_u W) at a single
%   frequency; used as the objective of the local refinements.

    weightedReturnDifference = terra.evaluateWeightedReturnDifference(context, ...
        frequencyRadiansPerSecond);
    singularValues = svd(weightedReturnDifference);
    minimumSingularValue = singularValues(end);
end
