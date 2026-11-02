function [bestArgument, bestValue, evaluationCount] = goldenSectionMinimize( ...
        objective, lowerBound, upperBound, relativeTolerance, maximumIterations)
%GOLDENSECTIONMINIMIZE Golden-section search, independent of Brent's method.
%   [bestArgument, bestValue, evaluationCount] = terra.goldenSectionMinimize(
%   objective, lowerBound, upperBound, relativeTolerance,
%   maximumIterations) minimizes a unimodal scalar function on
%   [lowerBound, upperBound]. The interval is shrunk until its width is
%   below relativeTolerance * max(1, |midpoint|). This deliberately uses
%   a different algorithm from the adaptive method (terra.brentMinimize)
%   so that the dense reference is independent of it.

    goldenRatioConjugate = (sqrt(5) - 1) / 2;
    leftBound = lowerBound;
    rightBound = upperBound;
    leftProbe = rightBound - goldenRatioConjugate * (rightBound - leftBound);
    rightProbe = leftBound + goldenRatioConjugate * (rightBound - leftBound);
    leftValue = objective(leftProbe);
    rightValue = objective(rightProbe);
    evaluationCount = 2;
    iteration = 0;
    while (rightBound - leftBound) > relativeTolerance * ...
            max(1, abs(leftBound + rightBound) / 2) && iteration < maximumIterations
        iteration = iteration + 1;
        if leftValue < rightValue
            rightBound = rightProbe;
            rightProbe = leftProbe;
            rightValue = leftValue;
            leftProbe = rightBound - goldenRatioConjugate * (rightBound - leftBound);
            leftValue = objective(leftProbe);
        else
            leftBound = leftProbe;
            leftProbe = rightProbe;
            leftValue = rightValue;
            rightProbe = leftBound + goldenRatioConjugate * (rightBound - leftBound);
            rightValue = objective(rightProbe);
        end
        evaluationCount = evaluationCount + 1;
    end
    if leftValue < rightValue
        bestArgument = leftProbe;
        bestValue = leftValue;
    else
        bestArgument = rightProbe;
        bestValue = rightValue;
    end
end
