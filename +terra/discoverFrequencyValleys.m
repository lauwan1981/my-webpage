function valleys = discoverFrequencyValleys(context, frequencies, options)
%DISCOVERFREQUENCYVALLEYS Find, refine and qualify every local valley.
%   valleys = terra.discoverFrequencyValleys(context, frequencies,
%   options) implements manuscript Sections 3.1, 3.3 and 4.3:
%     1. evaluate f_W on the whole predeclared grid (no warm start);
%     2. take every sampled interior local minimum as a candidate and
%        keep both band edges as separate candidates;
%     3. refine interior candidates locally (options.refinement):
%          'brent'   Brent's method in log-frequency (adaptive method,
%                    terra.brentMinimize)
%          'golden'  golden section, linear frequency (independent reference)
%          'none'    keep the grid value        (plain dense baseline)
%     4. if options.computeDiagnostics, qualify each candidate: a
%        numerical error bound epsilon_k from an independent second
%        (golden-section) refinement, which also replaces the point when
%        it is lower; then, at that final point, the full singular
%        spectrum and spectral gap and the log-frequency curvature
%        (non-degeneracy d2f/dlogw2 > 0); "unresolved" flags, edge
%        descent flags, near-active set and strict ordering.
%
%   options fields
%       refinement          'brent', 'golden' or 'none' (required)
%       computeDiagnostics  default true
%       relativeTolerance, maximumIterations   golden-section settings,
%                           required for 'golden'
%
%   Output (struct of rows sorted by ascending value)
%       frequencies, values, kinds (terra.valleyKinds), sampledValues,
%       refinementDeltas, singularValues (3xK), spectralGaps, curvatures,
%       isNondegenerate, errorBounds, isUnresolved, isBoundaryDescending,
%       valueGapToNext, minimumValue, minimumFrequency, minimumKind,
%       nearActiveTolerance, activeIndices, isStrictlyLowest,
%       evaluationCount, gridPointCount, timing (struct), refinement

    kinds = terra.valleyKinds();
    search = context.configuration.search;
    totalTimer = tic;
    if ~isfield(options, 'computeDiagnostics')
        options.computeDiagnostics = true;
    end
    if ~any(strcmp(options.refinement, {'brent', 'golden', 'none'}))
        error('terra:UnknownRefinement', 'Unknown refinement "%s".', options.refinement);
    end
    % Candidate slots 1 and 2 hold the band edges; interior valleys follow.
    edgeSlotCount = 2;
    firstInteriorSlot = edgeSlotCount + 1;
    % Qualification evaluates the spectrum once and f_W twice (curvature).
    qualificationEvaluationsPerValley = 3;

    frequencies = unique(reshape(frequencies, 1, []));
    pointCount = numel(frequencies);
    logFrequencies = log(frequencies);
    [gridSpectrum, gridTiming] = terra.evaluateDiagnosticSpectrum(context, frequencies);
    sampledValues = gridSpectrum(end, :);
    evaluationCount = pointCount;

    interiorIndices = find(sampledValues(2:end - 1) < sampledValues(1:end - 2) & ...
        sampledValues(2:end - 1) <= sampledValues(3:end)) + 1;
    interiorCount = numel(interiorIndices);
    candidateCount = interiorCount + edgeSlotCount;

    candidateFrequencies = zeros(1, candidateCount);
    candidateValues = zeros(1, candidateCount);
    candidateKinds = zeros(1, candidateCount);
    candidateSampled = zeros(1, candidateCount);
    candidateGridIndex = zeros(1, candidateCount);
    isBoundaryDescending = false(1, candidateCount);

    lowerEdgeSlot = 1;
    upperEdgeSlot = 2;
    candidateFrequencies(lowerEdgeSlot) = frequencies(1);
    candidateValues(lowerEdgeSlot) = sampledValues(1);
    candidateKinds(lowerEdgeSlot) = kinds.lowerEdge;
    candidateSampled(lowerEdgeSlot) = sampledValues(1);
    candidateGridIndex(lowerEdgeSlot) = 1;
    isBoundaryDescending(lowerEdgeSlot) = sampledValues(1) < sampledValues(2);
    candidateFrequencies(upperEdgeSlot) = frequencies(end);
    candidateValues(upperEdgeSlot) = sampledValues(end);
    candidateKinds(upperEdgeSlot) = kinds.upperEdge;
    candidateSampled(upperEdgeSlot) = sampledValues(end);
    candidateGridIndex(upperEdgeSlot) = pointCount;
    isBoundaryDescending(upperEdgeSlot) = sampledValues(end) < sampledValues(end - 1);

    %% Local refinement of interior candidates ---------------------------------
    objectiveLog = @(logFrequency) terra.evaluateMinimumSingularValue(context, ...
        exp(logFrequency));
    objectiveLinear = @(frequency) terra.evaluateMinimumSingularValue(context, frequency);
    refinementTimer = tic;
    for position = 1:interiorCount
        gridIndex = interiorIndices(position);
        slot = position + edgeSlotCount;
        candidateKinds(slot) = kinds.interior;
        candidateSampled(slot) = sampledValues(gridIndex);
        candidateGridIndex(slot) = gridIndex;
        switch options.refinement
            case 'brent'
                [logOptimum, valueOptimum, brentCount] = terra.brentMinimize(objectiveLog, ...
                    logFrequencies(gridIndex - 1), logFrequencies(gridIndex + 1), ...
                    search.refinementToleranceLogFrequency, search.brentMaximumIterations);
                frequencyOptimum = exp(logOptimum);
                evaluationCount = evaluationCount + brentCount;
            case 'golden'
                [frequencyOptimum, valueOptimum, goldenCount] = terra.goldenSectionMinimize( ...
                    objectiveLinear, frequencies(gridIndex - 1), frequencies(gridIndex + 1), ...
                    options.relativeTolerance, options.maximumIterations);
                evaluationCount = evaluationCount + goldenCount;
            case 'none'
                frequencyOptimum = frequencies(gridIndex);
                valueOptimum = sampledValues(gridIndex);
            otherwise
                error('terra:UnknownRefinement', 'Unknown refinement "%s".', options.refinement);
        end
        if valueOptimum > sampledValues(gridIndex)
            frequencyOptimum = frequencies(gridIndex);
            valueOptimum = sampledValues(gridIndex);
        end
        candidateFrequencies(slot) = frequencyOptimum;
        candidateValues(slot) = valueOptimum;
    end
    refinementSeconds = toc(refinementTimer);

    %% Qualification of every candidate ----------------------------------------
    diagnosticsTimer = tic;
    singularValues = nan(size(gridSpectrum, 1), candidateCount);
    curvatures = nan(1, candidateCount);
    errorBounds = search.valueErrorFloor * ones(1, candidateCount);
    isNondegenerate = false(1, candidateCount);
    isUnresolved = false(1, candidateCount);
    if options.computeDiagnostics
        singularValues(:, lowerEdgeSlot) = gridSpectrum(:, 1);
        singularValues(:, upperEdgeSlot) = gridSpectrum(:, end);
        curvatureStep = search.curvatureStepLogFrequency;
        for slot = firstInteriorSlot:candidateCount
            % Independent second refinement first: it sets the error bound
            % and, when lower, the final valley point.
            gridIndex = candidateGridIndex(slot);
            localCellLog = (logFrequencies(gridIndex + 1) - logFrequencies(gridIndex - 1)) / 2;
            bracketHalfWidth = search.secondaryBracketGridCells * localCellLog;
            refinedLog = log(candidateFrequencies(slot));
            [secondaryFrequency, secondaryValue, secondaryCount] = terra.goldenSectionMinimize( ...
                objectiveLinear, exp(refinedLog - bracketHalfWidth), ...
                exp(refinedLog + bracketHalfWidth), ...
                search.secondaryRefinementRelativeTolerance, ...
                search.goldenSectionMaximumIterations);
            errorBounds(slot) = abs(secondaryValue - candidateValues(slot)) + ...
                search.valueErrorFloor;
            if secondaryValue < candidateValues(slot)
                candidateValues(slot) = secondaryValue;
                candidateFrequencies(slot) = secondaryFrequency;
            end

            % Spectrum, spectral gap and curvature at the final valley point.
            finalLog = log(candidateFrequencies(slot));
            spectrumAtValley = terra.evaluateDiagnosticSpectrum(context, ...
                candidateFrequencies(slot));
            singularValues(:, slot) = spectrumAtValley;
            valueLeft = objectiveLog(finalLog - curvatureStep);
            valueRight = objectiveLog(finalLog + curvatureStep);
            curvatures(slot) = (valueLeft - 2 * spectrumAtValley(end) + valueRight) / ...
                curvatureStep ^ 2;
            isNondegenerate(slot) = curvatures(slot) > search.curvatureFloor;
            evaluationCount = evaluationCount + secondaryCount + qualificationEvaluationsPerValley;
        end
        isUnresolved = flagUnresolvedValleys(candidateFrequencies, candidateKinds, ...
            candidateGridIndex, logFrequencies, search);
    end
    diagnosticsSeconds = toc(diagnosticsTimer);

    %% Sort by value and derive set-level quantities ------------------------------
    [sortedValues, order] = sort(candidateValues);
    valleys.frequencies = candidateFrequencies(order);
    valleys.values = sortedValues;
    valleys.kinds = candidateKinds(order);
    valleys.sampledValues = candidateSampled(order);
    valleys.refinementDeltas = candidateSampled(order) - sortedValues;
    valleys.singularValues = singularValues(:, order);
    valleys.spectralGaps = singularValues(end - 1, order) - singularValues(end, order);
    valleys.curvatures = curvatures(order);
    valleys.isNondegenerate = isNondegenerate(order);
    valleys.errorBounds = errorBounds(order);
    valleys.isUnresolved = isUnresolved(order);
    valleys.isBoundaryDescending = isBoundaryDescending(order);
    valleys.valueGapToNext = [diff(sortedValues), Inf];

    valleys.minimumValue = sortedValues(1);
    valleys.minimumFrequency = valleys.frequencies(1);
    valleys.minimumKind = valleys.kinds(1);
    valleys.nearActiveTolerance = max(search.nearActiveEngineeringResolution, ...
        search.nearActiveErrorMultiplier * max(valleys.errorBounds));
    valleys.activeIndices = find(sortedValues <= sortedValues(1) + valleys.nearActiveTolerance);
    if numel(sortedValues) > 1
        valleys.isStrictlyLowest = sortedValues(1) + valleys.errorBounds(1) < ...
            sortedValues(2) - valleys.errorBounds(2);
    else
        valleys.isStrictlyLowest = true;
    end

    valleys.evaluationCount = evaluationCount;
    valleys.gridPointCount = pointCount;
    valleys.refinement = options.refinement;
    valleys.timing.frequencyResponseSeconds = gridTiming.frequencyResponseSeconds;
    valleys.timing.singularValueSeconds = gridTiming.singularValueSeconds;
    valleys.timing.refinementSeconds = refinementSeconds;
    valleys.timing.diagnosticsSeconds = diagnosticsSeconds;
    valleys.timing.totalSeconds = toc(totalTimer);
end

function isUnresolved = flagUnresolvedValleys(candidateFrequencies, candidateKinds, ...
        candidateGridIndex, logFrequencies, search)
%FLAGUNRESOLVEDVALLEYS Mark interior valleys closer than grid/model resolution.
    kinds = terra.valleyKinds();
    isUnresolved = false(size(candidateFrequencies));
    interiorSlots = find(candidateKinds == kinds.interior);
    modelResolutionLog = log(1 + search.modelFrequencyResolutionRelative);
    for slot = interiorSlots
        others = setdiff(interiorSlots, slot);
        if isempty(others)
            continue;
        end
        separation = min(abs(log(candidateFrequencies(others) / candidateFrequencies(slot))));
        gridIndex = candidateGridIndex(slot);
        localCellLog = (logFrequencies(gridIndex + 1) - logFrequencies(gridIndex - 1)) / 2;
        threshold = max(search.unresolvedGridCellCount * localCellLog, modelResolutionLog);
        isUnresolved(slot) = separation < threshold;
    end
end
