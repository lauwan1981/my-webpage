function margin = computeCommonDelayMargin(plant, controller, configuration)
%COMPUTECOMMONDELAYMARGIN Exact common-delay margin from loop eigen-loci.
%   margin = terra.computeCommonDelayMargin(plant, controller,
%   configuration) computes the largest tau_dm such that the loop with
%   the same transport delay in all three command channels is stable
%   for every tau in [0, tau_dm), given that the zero-delay loop is
%   stable. Because det(I + L0(s) e^{-s tau}) = prod_i (1 + lambda_i(s)
%   e^{-s tau}) and L0 is strictly proper, closed-loop roots can reach
%   the imaginary axis only at frequencies where an eigenvalue of
%   L0(j omega) has unit modulus; the smallest delay that aligns its
%   phase with -1 is tau_c = mod(arg(lambda) - pi, 2 pi) / omega.
%
%   The unit-modulus search runs on a grid (log grid plus modal points)
%   whose band is extended until the analytic tail bounds exclude
%   crossings outside it. Sorted eigenvalue moduli are continuous in
%   omega, so each sign change of |lambda|_(m) - 1 is refined with fzero.
%
%   Output fields
%       delayMarginSeconds, criticalFrequency, crossingFrequencies,
%       crossingPhaseMargins (rad), crossingDelays (s), searchBand,
%       isBandCertified, tails, evaluationCount

    stability = configuration.stability;
    tailSettings = configuration.tails;
    lowEdge = configuration.search.bandRadiansPerSecond(1);
    highEdge = configuration.search.bandRadiansPerSecond(2);
    axisCount = size(plant.rigidResidue, 1);
    unitScale = ones(axisCount, 1);
    tails = terra.computeTailBounds(plant, controller, configuration, lowEdge, highEdge, unitScale);
    extensionCount = 0;
    while ~(tails.excludesLowUnitCrossing && tails.excludesHighUnitCrossing) && ...
            extensionCount < tailSettings.maximumExtensionCount
        extensionCount = extensionCount + 1;
        if ~tails.excludesLowUnitCrossing
            lowEdge = lowEdge / tailSettings.extensionFactor;
        end
        if ~tails.excludesHighUnitCrossing
            highEdge = highEdge * tailSettings.extensionFactor;
        end
        tails = terra.computeTailBounds(plant, controller, configuration, lowEdge, highEdge, unitScale);
    end

    frequencies = terra.buildFrequencyGrid([lowEdge, highEdge], ...
        stability.delayMarginGridPointCount, plant, configuration);
    sortedModuli = sortedEigenvalueModuli(plant, controller, configuration, frequencies);
    evaluationCount = numel(frequencies);

    crossingFrequencies = zeros(1, 0);
    crossingPhaseMargins = zeros(1, 0);
    for modulusRank = 1:size(sortedModuli, 1)
        excess = sortedModuli(modulusRank, :) - 1;
        signChanges = find(excess(1:end - 1) .* excess(2:end) < 0);
        for changeIndex = signChanges
            excessFunction = @(logFrequency) rankedModulus(plant, controller, ...
                configuration, exp(logFrequency), modulusRank) - 1;
            logBracket = log(frequencies(changeIndex:changeIndex + 1));
            fzeroOptions = optimset('TolX', terra.fzeroTolerance( ...
                stability.delayMarginRootTolerance, logBracket), 'Display', 'off');
            logRoot = fzero(excessFunction, logBracket, fzeroOptions);
            crossingFrequency = exp(logRoot);
            eigenvalues = loopEigenvalues(plant, controller, configuration, crossingFrequency);
            [~, closestIndex] = min(abs(abs(eigenvalues) - 1));
            phaseToMinusOne = mod(angle(eigenvalues(closestIndex)) - pi, 2 * pi);
            crossingFrequencies(end + 1) = crossingFrequency; %#ok<AGROW>
            crossingPhaseMargins(end + 1) = phaseToMinusOne; %#ok<AGROW>
        end
    end

    crossingDelays = crossingPhaseMargins ./ crossingFrequencies;
    margin.crossingFrequencies = crossingFrequencies;
    margin.crossingPhaseMargins = crossingPhaseMargins;
    margin.crossingDelays = crossingDelays;
    if isempty(crossingDelays)
        margin.delayMarginSeconds = Inf;
        margin.criticalFrequency = NaN;
    else
        [margin.delayMarginSeconds, criticalIndex] = min(crossingDelays);
        margin.criticalFrequency = crossingFrequencies(criticalIndex);
    end
    margin.searchBand = [lowEdge, highEdge];
    margin.isBandCertified = tails.excludesLowUnitCrossing && tails.excludesHighUnitCrossing;
    margin.tails = tails;
    margin.evaluationCount = evaluationCount;
end

function moduli = sortedEigenvalueModuli(plant, controller, configuration, frequencies)
%SORTEDEIGENVALUEMODULI |eig(L0(j w))| sorted ascending per frequency.
    loop = terra.evaluateLoopResponse(plant, controller, configuration, frequencies, 0);
    pointCount = numel(frequencies);
    moduli = zeros(size(loop.loopResponse, 1), pointCount);
    for pointIndex = 1:pointCount
        moduli(:, pointIndex) = sort(abs(eig(loop.loopResponse(:, :, pointIndex))));
    end
end

function modulus = rankedModulus(plant, controller, configuration, frequency, modulusRank)
%RANKEDMODULUS modulusRank-th smallest eigenvalue modulus of L0(j w).
    eigenvalues = loopEigenvalues(plant, controller, configuration, frequency);
    sortedValues = sort(abs(eigenvalues));
    modulus = sortedValues(modulusRank);
end

function eigenvalues = loopEigenvalues(plant, controller, configuration, frequency)
%LOOPEIGENVALUES Eigenvalues of the delay-free loop at one frequency.
    loop = terra.evaluateLoopResponse(plant, controller, configuration, frequency, 0);
    eigenvalues = eig(loop.loopResponse(:, :, 1));
end
