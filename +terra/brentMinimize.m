function [bestArgument, bestValue, evaluationCount] = brentMinimize(objective, ...
        lowerBound, upperBound, absoluteTolerance, maximumIterations)
%BRENTMINIMIZE Bounded scalar minimization by Brent's method.
%   [bestArgument, bestValue, evaluationCount] = terra.brentMinimize(
%   objective, lowerBound, upperBound, absoluteTolerance,
%   maximumIterations) minimizes the scalar function objective on
%   [lowerBound, upperBound] with Brent's combination of golden-section
%   and successive parabolic steps (R. P. Brent, Algorithms for
%   Minimization without Derivatives, Prentice-Hall, 1973, Ch. 5).
%
%   Stopping rule: the search ends when the best point x lies within
%   2*tolerance - (b - a)/2 of the bracket midpoint, with
%       tolerance = 2*eps*|x| + absoluteTolerance/3,
%   or after maximumIterations steps (safety cap). A trial point whose
%   value ties the best value does not replace it (see the update step).
%
%   Why not fminbnd: MATLAB's fminbnd adds sqrt(eps)*|x| to TolX (about
%   5e-8 at x = log(37 rad/s), i.e. a band-minimum error of up to about
%   1e-11 on the sharpest valleys), whereas Octave's fminbnd adds only
%   2*eps*|x|. The same study would therefore give different switch
%   locations and secant errors on the two platforms. This function
%   gives the same, eps-limited accuracy on both.
%
%   Inputs
%       objective          handle, scalar -> scalar
%       lowerBound, upperBound   finite bracket, lowerBound < upperBound
%       absoluteTolerance  requested accuracy of the argument (same units)
%       maximumIterations  cap on the number of iterations
%   Outputs
%       bestArgument, bestValue  best point found and its value
%       evaluationCount          number of objective evaluations

    goldenFraction = (3 - sqrt(5)) / 2;
    bracketLow = lowerBound;
    bracketHigh = upperBound;

    % x: best point so far; w: second best; v: previous value of w.
    bestArgument = bracketLow + goldenFraction * (bracketHigh - bracketLow);
    secondArgument = bestArgument;
    previousArgument = bestArgument;
    bestValue = objective(bestArgument);
    secondValue = bestValue;
    previousValue = bestValue;
    evaluationCount = 1;

    % step: last step taken; stepBeforeLast: the step before it.
    step = 0;
    stepBeforeLast = 0;
    iteration = 0;
    while iteration < maximumIterations
        midpoint = (bracketLow + bracketHigh) / 2;
        tolerance = 2 * eps * abs(bestArgument) + absoluteTolerance / 3;
        doubleTolerance = 2 * tolerance;
        if abs(bestArgument - midpoint) <= doubleTolerance - (bracketHigh - bracketLow) / 2
            break;
        end
        iteration = iteration + 1;

        isParabolicStep = false;
        if abs(stepBeforeLast) > tolerance
            % Parabola through (x, fx), (w, fw), (v, fv): step = numerator/denominator.
            termFromSecond = (bestArgument - secondArgument) * (bestValue - previousValue);
            termFromPrevious = (bestArgument - previousArgument) * (bestValue - secondValue);
            numerator = (bestArgument - previousArgument) * termFromPrevious - ...
                (bestArgument - secondArgument) * termFromSecond;
            denominator = 2 * (termFromPrevious - termFromSecond);
            if denominator > 0
                numerator = -numerator;
            end
            denominator = abs(denominator);
            stepTwoBack = stepBeforeLast;
            stepBeforeLast = step;
            % Accept only a step shorter than half the step before last
            % that stays inside the bracket.
            isParabolicStep = abs(numerator) < abs(denominator * stepTwoBack / 2) && ...
                numerator > denominator * (bracketLow - bestArgument) && ...
                numerator < denominator * (bracketHigh - bestArgument);
        end

        if isParabolicStep
            step = numerator / denominator;
            trialArgument = bestArgument + step;
            % Do not evaluate too close to the bracket ends.
            if (trialArgument - bracketLow) < doubleTolerance || ...
                    (bracketHigh - trialArgument) < doubleTolerance
                step = signedMagnitude(tolerance, midpoint - bestArgument);
            end
        else
            if bestArgument >= midpoint
                stepBeforeLast = bracketLow - bestArgument;
            else
                stepBeforeLast = bracketHigh - bestArgument;
            end
            step = goldenFraction * stepBeforeLast;
        end

        % Do not evaluate closer than the tolerance to the best point.
        if abs(step) >= tolerance
            trialArgument = bestArgument + step;
        else
            trialArgument = bestArgument + signedMagnitude(tolerance, step);
        end
        trialValue = objective(trialArgument);
        evaluationCount = evaluationCount + 1;

        % A tie keeps the incumbent and turns the trial point into a
        % bracket end, so the bracket closes around the best point on the
        % plateaus of equal (roundoff-level) values next to a minimum.
        % Brent's original "<=" walks along such a plateau instead.
        if trialValue < bestValue
            if trialArgument >= bestArgument
                bracketLow = bestArgument;
            else
                bracketHigh = bestArgument;
            end
            previousArgument = secondArgument;
            previousValue = secondValue;
            secondArgument = bestArgument;
            secondValue = bestValue;
            bestArgument = trialArgument;
            bestValue = trialValue;
        else
            if trialArgument < bestArgument
                bracketLow = trialArgument;
            else
                bracketHigh = trialArgument;
            end
            if trialValue <= secondValue || secondArgument == bestArgument
                previousArgument = secondArgument;
                previousValue = secondValue;
                secondArgument = trialArgument;
                secondValue = trialValue;
            elseif trialValue <= previousValue || previousArgument == bestArgument || ...
                    previousArgument == secondArgument
                previousArgument = trialArgument;
                previousValue = trialValue;
            end
        end
    end
end

function value = signedMagnitude(magnitude, direction)
%SIGNEDMAGNITUDE |magnitude| with the sign of direction (+ for zero).
    if direction >= 0
        value = abs(magnitude);
    else
        value = -abs(magnitude);
    end
end
