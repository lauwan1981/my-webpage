function crossover = findMainCrossover(context, valleys)
%FINDMAINCROSSOVER Main (rigid-body) gain crossover and its valley.
%   crossover = terra.findMainCrossover(context, valleys) returns the
%   lowest frequency in the band at which sigma_max(L(j omega)) falls
%   through 1, and the interior valley closest to it in log-frequency.
%   This is the information a conventional "single main crossover"
%   check uses; it is reported next to the band-wide result (Table 2)
%   and drives the conventional remediation rule.
%
%   Output fields
%       frequency, valleyIndex (into valleys), valleyFrequency,
%       valleyValue, identifiesActiveValley, marginOverestimate

    kinds = terra.valleyKinds();
    band = context.configuration.search.bandRadiansPerSecond;
    frequencies = logspace(log10(band(1)), log10(band(2)), ...
        context.configuration.search.initialGridPointCount);
    loop = terra.evaluateLoopResponse(context.plant, context.controller, ...
        context.configuration, frequencies, 0);
    largestGain = zeros(size(frequencies));
    for pointIndex = 1:numel(frequencies)
        largestGain(pointIndex) = norm(loop.loopResponse(:, :, pointIndex), 2);
    end
    firstBelow = find(largestGain < 1, 1, 'first');
    if isempty(firstBelow) || firstBelow == 1
        crossover.frequency = NaN;
    else
        gainExcess = @(logFrequency) largestLoopGain(context, exp(logFrequency)) - 1;
        logBracket = log(frequencies([firstBelow - 1, firstBelow]));
        rootOptions = optimset('TolX', terra.fzeroTolerance( ...
            context.configuration.search.refinementToleranceLogFrequency, logBracket), ...
            'Display', 'off');
        logCrossover = fzero(gainExcess, logBracket, rootOptions);
        crossover.frequency = exp(logCrossover);
    end

    interiorIndices = find(valleys.kinds == kinds.interior);
    if isempty(interiorIndices) || isnan(crossover.frequency)
        crossover.valleyIndex = NaN;
        crossover.valleyFrequency = NaN;
        crossover.valleyValue = NaN;
        crossover.identifiesActiveValley = false;
        crossover.marginOverestimate = NaN;
        return;
    end
    [~, nearest] = min(abs(log(valleys.frequencies(interiorIndices) / crossover.frequency)));
    crossover.valleyIndex = interiorIndices(nearest);
    crossover.valleyFrequency = valleys.frequencies(crossover.valleyIndex);
    crossover.valleyValue = valleys.values(crossover.valleyIndex);
    crossover.identifiesActiveValley = any(valleys.activeIndices == crossover.valleyIndex);
    crossover.marginOverestimate = crossover.valleyValue - valleys.minimumValue;
end

function gain = largestLoopGain(context, frequency)
%LARGESTLOOPGAIN sigma_max of the delay-free loop at one frequency.
    loop = terra.evaluateLoopResponse(context.plant, context.controller, ...
        context.configuration, frequency, 0);
    gain = norm(loop.loopResponse(:, :, 1), 2);
end
