function tracks = trackValleyBranches(scan, configuration)
%TRACKVALLEYBRANCHES Connect interior valleys into branches b_k(theta).
%   tracks = terra.trackValleyBranches(scan, configuration) links interior
%   valleys of consecutive path points only when they are mutual nearest
%   neighbours in log-frequency within the declared gate. Unmatched
%   valleys start a new branch (birth); branches without a successor end
%   (death). Nothing is force-matched (manuscript Section 3.1). Branch
%   identity is a numerical continuation, not a physical mode claim.
%
%   Output fields
%       pathName, pathValues, frequency (P x B), value (P x B),
%       branchCount, activeBranch (1 x P, 0 when the band minimum is an
%       edge), ambiguousLinks, branchLabels (cell, geometric-mean
%       frequency of each branch)

    kinds = terra.valleyKinds();
    gate = configuration.paths.branchMatchGateLog;
    pointCount = numel(scan.pathValues);
    frequencyTable = nan(pointCount, 0);
    valueTable = nan(pointCount, 0);
    activeBranch = zeros(1, pointCount);
    ambiguousLinks = 0;
    previousFrequencies = zeros(1, 0);
    previousIds = zeros(1, 0);

    for pointIndex = 1:pointCount
        valleys = scan.valleys{pointIndex};
        interior = find(valleys.kinds == kinds.interior);
        currentFrequencies = valleys.frequencies(interior);
        currentValues = valleys.values(interior);
        currentIds = zeros(1, numel(interior));
        for position = 1:numel(interior)
            if isempty(previousFrequencies)
                break;
            end
            distances = abs(log(previousFrequencies / currentFrequencies(position)));
            [nearestDistance, nearestPrevious] = min(distances);
            if nearestDistance > gate
                continue;
            end
            reverseDistances = abs(log(currentFrequencies / previousFrequencies(nearestPrevious)));
            [~, reverseNearest] = min(reverseDistances);
            if reverseNearest == position
                currentIds(position) = previousIds(nearestPrevious);
            else
                ambiguousLinks = ambiguousLinks + 1;
            end
        end
        for position = 1:numel(interior)
            if currentIds(position) == 0
                currentIds(position) = size(frequencyTable, 2) + 1;
                frequencyTable(:, currentIds(position)) = nan(pointCount, 1);
                valueTable(:, currentIds(position)) = nan(pointCount, 1);
            end
            frequencyTable(pointIndex, currentIds(position)) = currentFrequencies(position);
            valueTable(pointIndex, currentIds(position)) = currentValues(position);
        end
        if valleys.minimumKind == kinds.interior
            minimumPosition = find(interior == 1, 1);
            activeBranch(pointIndex) = currentIds(minimumPosition);
        end
        previousFrequencies = currentFrequencies;
        previousIds = currentIds;
    end

    tracks.pathName = scan.pathName;
    tracks.pathValues = scan.pathValues;
    tracks.frequency = frequencyTable;
    tracks.value = valueTable;
    tracks.branchCount = size(frequencyTable, 2);
    tracks.activeBranch = activeBranch;
    tracks.ambiguousLinks = ambiguousLinks;
    tracks.branchLabels = cell(1, tracks.branchCount);
    for branchIndex = 1:tracks.branchCount
        branchFrequencies = frequencyTable(:, branchIndex);
        branchFrequencies = branchFrequencies(~isnan(branchFrequencies));
        geometricMeanFrequency = exp(mean(log(branchFrequencies)));
        tracks.branchLabels{branchIndex} = sprintf('valley near %.3g rad/s', ...
            geometricMeanFrequency);
    end
end
