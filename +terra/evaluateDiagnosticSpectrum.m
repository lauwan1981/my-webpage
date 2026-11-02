function [singularValues, timing] = evaluateDiagnosticSpectrum(context, frequenciesRadiansPerSecond)
%EVALUATEDIAGNOSTICSPECTRUM Singular values of W^-1 F_u W on a grid.
%   [singularValues, timing] = terra.evaluateDiagnosticSpectrum(context,
%   frequenciesRadiansPerSecond) returns a 3xN matrix of singular values
%   (descending; last row is f_W) and the time split between building
%   the frequency response and computing the SVDs (manuscript Section 4.3
%   cost accounting).
%
%   timing fields: frequencyResponseSeconds, singularValueSeconds

    frequencyResponseTimer = tic;
    returnDifference = terra.evaluateWeightedReturnDifference(context, ...
        frequenciesRadiansPerSecond);
    timing.frequencyResponseSeconds = toc(frequencyResponseTimer);

    singularValueTimer = tic;
    singularValues = terra.singularValueSpectrum(returnDifference);
    timing.singularValueSeconds = toc(singularValueTimer);
end
