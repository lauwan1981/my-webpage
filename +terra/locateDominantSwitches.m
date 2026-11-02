function switches = locateDominantSwitches(scan, tracks, configuration)
%LOCATEDOMINANTSWITCHES Locate and qualify dominant risk-frequency switches.
%   switches = terra.locateDominantSwitches(scan, tracks, configuration)
%   examines every path interval in which the active branch changes and
%   applies manuscript Sections 3.1 and 4.3:
%     1. root of b_i(theta) - b_j(theta) by fzero to the absolute
%        tolerance configuration.paths.switchRootTolerance, where each
%        branch value is a Brent refinement around its tracked frequency
%        (branch identity preserved, window
%        configuration.paths.localBranchWindowLog);
%     2. full-band re-search at the root: it must resolve both branch
%        valleys, and they must be the two lowest valleys
%        (b_i = b_j <= b_l for every other l, beyond the error bounds);
%     3. transversality: d(b_i - b_j)/dtheta ~= 0 (central differences);
%     4. the lowest branch must swap in the observed direction: a full
%        re-search at theta* - Delta returns branch i and one at
%        theta* + Delta returns branch j;
%     5. both valleys interior and non-degenerate (d2f/dlogw2 > 0).
%   status: 'confirmed_dominant_switch' when all checks pass,
%   'candidate_branch_equality' otherwise (reasons listed), and
%   'unresolved' when the interval cannot be analysed: the band minimum
%   lies at a band edge on one side, an active branch is born or dies
%   inside the interval, b_i - b_j has the same sign at both ends, or a
%   branch leaves its search window. Other errors are not caught.
%   evaluationCount counts every f_W evaluation spent on the record.

    actuatorScale = scan.actuatorScale;
    pathName = scan.pathName;
    paths = configuration.paths;
    absoluteRootTolerance = paths.switchRootTolerance.(pathName);
    transversalStep = paths.transversalityStep.(pathName);
    switches = repmat(emptyRecord(pathName, [NaN, NaN], [0, 0]), 1, 0);

    for pointIndex = 1:(numel(tracks.pathValues) - 1)
        leftBranch = tracks.activeBranch(pointIndex);
        rightBranch = tracks.activeBranch(pointIndex + 1);
        if leftBranch == rightBranch
            continue;
        end
        interval = tracks.pathValues(pointIndex:pointIndex + 1);
        record = emptyRecord(pathName, interval, [leftBranch, rightBranch]);
        if leftBranch == 0 || rightBranch == 0
            record.reasons = 'the band minimum lies at a band edge on one side of the interval';
            switches(end + 1) = record; %#ok<AGROW>
            continue;
        end
        frequencyEnds = tracks.frequency(pointIndex:pointIndex + 1, [leftBranch, rightBranch]);
        if any(isnan(frequencyEnds(:)))
            record.reasons = 'an active branch is born or dies inside the interval';
            switches(end + 1) = record; %#ok<AGROW>
            continue;
        end

        % fzero calls the difference through a function handle, so the
        % f_W evaluations are accumulated in a handle object.
        evaluationCounter = containers.Map({'evaluations'}, {0});
        difference = @(parameter) branchDifference(configuration, pathName, parameter, ...
            interval, frequencyEnds, actuatorScale, evaluationCounter);
        try
            differenceAtStart = difference(interval(1));
            differenceAtEnd = difference(interval(2));
            if sign(differenceAtStart) * sign(differenceAtEnd) > 0
                record.reasons = 'b_i - b_j has the same sign at both ends of the interval';
            else
                rootOptions = optimset('TolX', terra.fzeroTolerance(absoluteRootTolerance, ...
                    interval), 'Display', 'off');
                root = fzero(difference, interval, rootOptions);
                record = qualifyRoot(record, configuration, pathName, root, interval, ...
                    frequencyEnds, actuatorScale, transversalStep, evaluationCounter);
            end
        catch failure
            if ~strcmp(failure.identifier, 'terra:BranchLost')
                rethrow(failure);
            end
            record.status = 'unresolved';
            record.reasons = failure.message;
        end
        record.evaluationCount = evaluationCounter('evaluations');
        switches(end + 1) = record; %#ok<AGROW>
    end
end

function record = qualifyRoot(record, configuration, pathName, root, interval, ...
        frequencyEnds, actuatorScale, transversalStep, evaluationCounter)
%QUALIFYROOT Checks 2-5 at a located root.
    paths = configuration.paths;
    kinds = terra.valleyKinds();
    reasons = {};
    [leftValue, leftFrequency] = localBranchValue(configuration, pathName, root, ...
        interval, frequencyEnds(:, 1), actuatorScale, evaluationCounter);
    [rightValue, rightFrequency] = localBranchValue(configuration, pathName, root, ...
        interval, frequencyEnds(:, 2), actuatorScale, evaluationCounter);
    record.parameterValue = root;
    record.value = (leftValue + rightValue) / 2;
    record.frequencies = [leftFrequency, rightFrequency];
    record.equalityError = abs(leftValue - rightValue);
    if record.equalityError > paths.switchEqualityTolerance
        reasons{end + 1} = 'branch values not equal at the root';
    end

    % Check 2: both branch valleys resolved and strictly the two lowest.
    rootValleys = fullSearch(configuration, pathName, root, actuatorScale, evaluationCounter);
    [leftSlot, rightSlot] = matchSlots(rootValleys, record.frequencies);
    slotDistances = abs(log(rootValleys.frequencies([leftSlot, rightSlot]) ./ ...
        record.frequencies));
    if leftSlot == rightSlot || any(slotDistances > paths.localBranchWindowLog)
        reasons{end + 1} = 'the full-band search does not resolve both branch valleys';
    end
    record.errorBounds = rootValleys.errorBounds([leftSlot, rightSlot]);
    otherSlots = setdiff(1:numel(rootValleys.values), [leftSlot, rightSlot]);
    if isempty(otherSlots)
        record.thirdValleyGap = Inf;
        thirdValleyErrorBound = 0;
    else
        [thirdValue, thirdPosition] = min(rootValleys.values(otherSlots));
        record.thirdValleyGap = thirdValue - record.value;
        thirdValleyErrorBound = rootValleys.errorBounds(otherSlots(thirdPosition));
    end
    if record.thirdValleyGap <= max(record.errorBounds) + thirdValleyErrorBound
        reasons{end + 1} = 'a third valley is not strictly higher';
    end

    % Check 5: interior, non-degenerate valleys.
    record.nondegenerate = rootValleys.isNondegenerate([leftSlot, rightSlot]) & ...
        rootValleys.kinds([leftSlot, rightSlot]) == kinds.interior;
    if ~all(record.nondegenerate)
        reasons{end + 1} = 'a valley is degenerate or not interior';
    end

    % Check 3: transversal crossing.
    leftUpper = localBranchValue(configuration, pathName, root + transversalStep, ...
        interval, frequencyEnds(:, 1), actuatorScale, evaluationCounter);
    leftLower = localBranchValue(configuration, pathName, root - transversalStep, ...
        interval, frequencyEnds(:, 1), actuatorScale, evaluationCounter);
    rightUpper = localBranchValue(configuration, pathName, root + transversalStep, ...
        interval, frequencyEnds(:, 2), actuatorScale, evaluationCounter);
    rightLower = localBranchValue(configuration, pathName, root - transversalStep, ...
        interval, frequencyEnds(:, 2), actuatorScale, evaluationCounter);
    record.slopes = [(leftUpper - leftLower), (rightUpper - rightLower)] / (2 * transversalStep);
    record.slopeDifference = record.slopes(2) - record.slopes(1);
    if abs(record.slopeDifference) <= paths.minimumSlopeDifference
        reasons{end + 1} = 'branches are tangent (no transversal crossing)';
    end

    % Check 4: the lowest branch swaps from branch i (left) to branch j (right).
    leftBranchPosition = 1;
    rightBranchPosition = 2;
    swapOffset = paths.swapCheckStepMultiplier * transversalStep;
    beforeValleys = fullSearch(configuration, pathName, root - swapOffset, actuatorScale, ...
        evaluationCounter);
    afterValleys = fullSearch(configuration, pathName, root + swapOffset, actuatorScale, ...
        evaluationCounter);
    beforeBranch = nearestBranch(beforeValleys.minimumFrequency, record.frequencies);
    afterBranch = nearestBranch(afterValleys.minimumFrequency, record.frequencies);
    record.swapConfirmed = beforeBranch == leftBranchPosition && ...
        afterBranch == rightBranchPosition && ...
        beforeValleys.minimumKind == kinds.interior && afterValleys.minimumKind == kinds.interior;
    if ~record.swapConfirmed
        reasons{end + 1} = 'the band minimum does not swap from branch i to branch j';
    end

    if isempty(reasons)
        record.status = 'confirmed_dominant_switch';
        record.reasons = '';
    else
        record.status = 'candidate_branch_equality';
        record.reasons = strjoin(reasons, '; ');
    end
end

function difference = branchDifference(configuration, pathName, parameter, interval, ...
        frequencyEnds, actuatorScale, evaluationCounter)
%BRANCHDIFFERENCE b_left(theta) - b_right(theta) with branch identity kept.
    leftValue = localBranchValue(configuration, pathName, parameter, interval, ...
        frequencyEnds(:, 1), actuatorScale, evaluationCounter);
    rightValue = localBranchValue(configuration, pathName, parameter, interval, ...
        frequencyEnds(:, 2), actuatorScale, evaluationCounter);
    difference = leftValue - rightValue;
end

function [value, frequency] = localBranchValue(configuration, pathName, parameter, ...
        interval, frequencyEnds, actuatorScale, evaluationCounter)
%LOCALBRANCHVALUE Refine one branch inside a window around its track.
%   The guess interpolates the branch frequency log-linearly across the
%   interval; the window is the declared width or, if the branch itself
%   moves further across the interval, a multiple of that movement. The
%   Brent evaluations are added to evaluationCounter.
    paths = configuration.paths;
    fraction = (parameter - interval(1)) / (interval(2) - interval(1));
    logChange = log(frequencyEnds(2)) - log(frequencyEnds(1));
    guess = exp(log(frequencyEnds(1)) + fraction * logChange);
    window = max(paths.localBranchWindowLog, paths.branchWindowGrowth * abs(logChange));
    context = pathContext(configuration, pathName, parameter, actuatorScale);
    objective = @(logFrequency) terra.evaluateMinimumSingularValue(context, exp(logFrequency));
    [logOptimum, value, brentCount] = terra.brentMinimize(objective, log(guess) - window, ...
        log(guess) + window, configuration.search.refinementToleranceLogFrequency, ...
        configuration.search.brentMaximumIterations);
    addEvaluations(evaluationCounter, brentCount);
    frequency = exp(logOptimum);
    edgeFraction = abs(logOptimum - log(guess)) / window;
    if edgeFraction > 1 - paths.branchWindowEdgeFraction
        error('terra:BranchLost', ['Branch near %.4g rad/s left its search window ' ...
            'at %s = %.6g.'], guess, pathName, parameter);
    end
end

function valleys = fullSearch(configuration, pathName, parameter, actuatorScale, ...
        evaluationCounter)
%FULLSEARCH Adaptive full-band discovery at one path value (evaluations counted).
    valleys = terra.runAdaptiveDiscovery(pathContext(configuration, pathName, parameter, ...
        actuatorScale));
    addEvaluations(evaluationCounter, valleys.evaluationCount);
end

function addEvaluations(evaluationCounter, count)
%ADDEVALUATIONS Accumulate f_W evaluations in the shared counter.
    evaluationCounter('evaluations') = evaluationCounter('evaluations') + count; %#ok<NASGU>
end

function context = pathContext(configuration, pathName, parameter, actuatorScale)
%PATHCONTEXT Full-model context with one physical parameter set.
    controller = terra.nominalController(configuration);
    operatingPoint = terra.setParameterValue(configuration, ...
        terra.nominalOperatingPoint(configuration), controller, pathName, parameter);
    context = terra.createOperatingContext(configuration, operatingPoint, controller, ...
        'full', actuatorScale);
end

function [firstSlot, secondSlot] = matchSlots(valleys, targetFrequencies)
%MATCHSLOTS Valleys of a full search closest to the two branch frequencies.
    [~, firstSlot] = min(abs(log(valleys.frequencies / targetFrequencies(1))));
    [~, secondSlot] = min(abs(log(valleys.frequencies / targetFrequencies(2))));
end

function branchIndex = nearestBranch(frequency, branchFrequencies)
%NEARESTBRANCH 1 or 2: which branch frequency is closer in log scale.
    [~, branchIndex] = min(abs(log(branchFrequencies / frequency)));
end

function record = emptyRecord(pathName, interval, branchIds)
%EMPTYRECORD Switch record with every field present.
    record.pathName = pathName;
    record.interval = interval;
    record.parameterValue = NaN;
    record.value = NaN;
    record.frequencies = [NaN, NaN];
    record.branchIds = branchIds;
    record.equalityError = NaN;
    record.thirdValleyGap = NaN;
    record.slopes = [NaN, NaN];
    record.slopeDifference = NaN;
    record.swapConfirmed = false;
    record.nondegenerate = [false, false];
    record.errorBounds = [NaN, NaN];
    record.status = 'unresolved';
    record.reasons = '';
    record.evaluationCount = 0;
end
