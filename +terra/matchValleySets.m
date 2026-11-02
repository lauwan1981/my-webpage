function matching = matchValleySets(referenceValleys, candidateValleys, ...
        frequencyToleranceLog, valueTolerance)
%MATCHVALLEYSETS Detection statistics of interior valleys against a reference.
%   matching = terra.matchValleySets(referenceValleys, candidateValleys,
%   frequencyToleranceLog, valueTolerance) greedily pairs every interior
%   reference valley with the closest unused interior candidate valley
%   that lies within frequencyToleranceLog in |log(omega)| and within
%   valueTolerance in value (use Inf to ignore values).
%
%   Output fields
%       matchedCount, missedCount, extraCount, referenceCount,
%       detectionRate, minimumValueError, minimumFrequencyErrorLog

    kinds = terra.valleyKinds();
    referenceInterior = find(referenceValleys.kinds == kinds.interior);
    candidateInterior = find(candidateValleys.kinds == kinds.interior);
    isUsed = false(size(candidateInterior));
    matchedCount = 0;
    for referenceSlot = referenceInterior
        if isempty(candidateInterior)
            break;
        end
        distances = abs(log(candidateValleys.frequencies(candidateInterior) / ...
            referenceValleys.frequencies(referenceSlot)));
        distances(isUsed) = Inf;
        [closestDistance, closestPosition] = min(distances);
        valueError = abs(candidateValleys.values(candidateInterior(closestPosition)) - ...
            referenceValleys.values(referenceSlot));
        if closestDistance <= frequencyToleranceLog && valueError <= valueTolerance
            matchedCount = matchedCount + 1;
            isUsed(closestPosition) = true;
        end
    end
    matching.referenceCount = numel(referenceInterior);
    matching.matchedCount = matchedCount;
    matching.missedCount = numel(referenceInterior) - matchedCount;
    matching.extraCount = sum(~isUsed);
    if matching.referenceCount > 0
        matching.detectionRate = matchedCount / matching.referenceCount;
    else
        matching.detectionRate = 1;
    end
    matching.minimumValueError = abs(candidateValleys.minimumValue - referenceValleys.minimumValue);
    matching.minimumFrequencyErrorLog = abs(log(candidateValleys.minimumFrequency / ...
        referenceValleys.minimumFrequency));
end
