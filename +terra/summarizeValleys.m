function summary = summarizeValleys(valleys)
%SUMMARIZEVALLEYS Compact record of a valley set for tables and reports.
%   summary = terra.summarizeValleys(valleys) extracts the band minimum
%   b_W,Omega, its frequency omega*, kind, spectral gap, error bound,
%   the second-lowest candidate (value, frequency, gap to the minimum),
%   the near-active set, strict ordering and counts.

    kinds = terra.valleyKinds();
    summary.minimumValue = valleys.minimumValue;
    summary.minimumFrequency = valleys.minimumFrequency;
    summary.minimumKind = valleys.minimumKind;
    summary.spectralGap = valleys.spectralGaps(1);
    summary.errorBound = valleys.errorBounds(1);
    summary.curvature = valleys.curvatures(1);
    summary.isNondegenerate = valleys.isNondegenerate(1);
    if numel(valleys.values) > 1
        summary.secondValue = valleys.values(2);
        summary.secondFrequency = valleys.frequencies(2);
        summary.gapToSecond = valleys.values(2) - valleys.values(1);
    else
        summary.secondValue = NaN;
        summary.secondFrequency = NaN;
        summary.gapToSecond = NaN;
    end
    summary.activeFrequencies = valleys.frequencies(valleys.activeIndices);
    summary.activeCount = numel(valleys.activeIndices);
    summary.isStrictlyLowest = valleys.isStrictlyLowest;
    summary.interiorCount = sum(valleys.kinds == kinds.interior);
    summary.unresolvedCount = sum(valleys.isUnresolved);
    summary.edgeDescendingCount = sum(valleys.isBoundaryDescending);
    summary.evaluationCount = valleys.evaluationCount;
end
