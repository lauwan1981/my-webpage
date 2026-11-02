function comparison = compareWithDenseBaseline(configuration, caseDefinition)
%COMPAREWITHDENSEBASELINE Equal-error comparison for Table 2.
%   comparison = terra.compareWithDenseBaseline(configuration,
%   caseDefinition) compares, for one case with the unchanged controller,
%   the full model and the primary scale (manuscript Sections 3.3, 4.2):
%     reference  independent dense reference (terra.runIndependentReference)
%     method     adaptive discovery (modal evaluator, grid + Brent + checks)
%     dense      plain dense grid, same evaluator, no local refinement;
%                the smallest N of the predeclared ladder that reaches the
%                same minimum-value error target and detects every
%                reference valley is used ("equal-error dense baseline");
%                if no rung reaches it, the largest rung is reported with
%                denseReachedTarget = false
%   Detection: method valleys are matched to the reference within
%   baseline.matchFrequencyToleranceLog and baseline.matchValueTolerance;
%   dense valleys within max(matchFrequencyToleranceLog,
%   search.secondaryBracketGridCells grid cells) and without a value
%   test, because a plain grid locates a valley only
%   to its cell and its value accuracy is what the error target measures.
%   Both competitors start from the same model; the model build (timed
%   once) is a shared fixed cost, and both grids are built outside the
%   timers. Method and dense times are medians of the declared repeats.
%   Also reported: band-edge (tail) certificates and the single main
%   crossover check (frequency, value, whether it finds the active valley).

    baseline = configuration.baseline;
    search = configuration.search;
    controller = terra.nominalController(configuration);
    scale = configuration.scaling.primaryActuatorScale;
    band = search.bandRadiansPerSecond;

    modelTimer = tic;
    context = terra.createOperatingContext(configuration, caseDefinition.operatingPoint, ...
        controller, 'full', scale);
    modelSeconds = toc(modelTimer);
    delaySeconds = caseDefinition.operatingPoint.delaySeconds;

    referenceTimer = tic;
    reference = terra.runIndependentReference(context.plant, controller, configuration, ...
        delaySeconds, scale, baseline.referenceGridPointCount);
    referenceSeconds = toc(referenceTimer);

    methodTimes = zeros(1, baseline.timingRepeatCount);
    for repeatIndex = 1:baseline.timingRepeatCount
        methodTimer = tic;
        methodValleys = terra.runAdaptiveDiscovery(context);
        methodTimes(repeatIndex) = toc(methodTimer);
    end
    methodMatching = terra.matchValleySets(reference, methodValleys, ...
        baseline.matchFrequencyToleranceLog, baseline.matchValueTolerance);

    denseOptions.refinement = 'none';
    denseOptions.computeDiagnostics = false;
    denseReachedTarget = false;
    for pointCount = baseline.denseGridLadder
        denseCount = pointCount;
        denseValleys = terra.discoverFrequencyValleys(context, ...
            terra.buildFrequencyGrid(band, pointCount, [], configuration), denseOptions);
        cellLog = log(band(2) / band(1)) / (pointCount - 1);
        detectionTolerance = max(baseline.matchFrequencyToleranceLog, ...
            search.secondaryBracketGridCells * cellLog);
        denseMatching = terra.matchValleySets(reference, denseValleys, detectionTolerance, Inf);
        if denseMatching.minimumValueError <= baseline.targetMinimumValueError && ...
                denseMatching.missedCount == 0
            denseReachedTarget = true;
            break;
        end
    end
    denseGrid = terra.buildFrequencyGrid(band, denseCount, [], configuration);
    denseTimes = zeros(1, baseline.timingRepeatCount);
    for repeatIndex = 1:baseline.timingRepeatCount
        denseTimer = tic;
        denseValleys = terra.discoverFrequencyValleys(context, denseGrid, denseOptions);
        denseTimes(repeatIndex) = toc(denseTimer);
    end

    tails = terra.computeTailBounds(context.plant, controller, configuration, band(1), ...
        band(2), scale);
    crossover = terra.findMainCrossover(context, methodValleys);

    comparison.label = caseDefinition.label;
    comparison.operatingPoint = caseDefinition.operatingPoint;
    comparison.referenceMinimum = reference.minimumValue;
    comparison.referenceFrequency = reference.minimumFrequency;
    comparison.referenceInteriorCount = methodMatching.referenceCount;
    comparison.referenceEvaluations = reference.evaluationCount;
    comparison.referenceSeconds = referenceSeconds;
    comparison.modelSeconds = modelSeconds;
    comparison.method = methodMatching;
    comparison.methodEvaluations = methodValleys.evaluationCount;
    comparison.methodSeconds = median(methodTimes);
    comparison.methodTiming = methodValleys.timing;
    comparison.methodErrorBound = methodValleys.errorBounds(1);
    comparison.denseGridPointCount = denseCount;
    comparison.denseReachedTarget = denseReachedTarget;
    comparison.dense = denseMatching;
    comparison.denseEvaluations = denseValleys.evaluationCount;
    comparison.denseTiming = denseValleys.timing;
    comparison.denseSeconds = median(denseTimes);
    comparison.evaluationRatio = comparison.denseEvaluations / comparison.methodEvaluations;
    comparison.timeRatio = comparison.denseSeconds / comparison.methodSeconds;
    comparison.tails = tails;
    comparison.bandEdgesVerified = tails.lowDiagnosticLowerBound > methodValleys.minimumValue && ...
        tails.highDiagnosticLowerBound > methodValleys.minimumValue;
    comparison.crossover = crossover;
end
