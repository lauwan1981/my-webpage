function totals = summarizeDenseBaseline(results)
%SUMMARIZEDENSEBASELINE Aggregate Table 2 quantities over all cases.
%   totals = terra.summarizeDenseBaseline(results) returns detection
%   counts, maximum band-minimum errors, median costs of the adaptive
%   method and of the equal-error plain dense grid (cases where no rung
%   of the ladder reached the target are counted in denseFailures and
%   reported with their largest rung), switch-location errors,
%   tail-certificate counts and the single-crossover check record.

    unitConstants = terra.units();
    toMilliseconds = unitConstants.secondsToMilliseconds;
    comparisons = results.denseBaseline;
    caseCount = numel(comparisons);
    methodMatchings = [comparisons.method];
    denseMatchings = [comparisons.dense];
    reached = [comparisons.denseReachedTarget];

    totals.caseCount = caseCount;
    totals.referenceValleys = sum([comparisons.referenceInteriorCount]);
    totals.methodMatched = sum([methodMatchings.matchedCount]);
    totals.methodExtra = sum([methodMatchings.extraCount]);
    totals.methodMaximumError = max([methodMatchings.minimumValueError]);
    totals.denseMatched = sum([denseMatchings.matchedCount]);
    totals.denseExtra = sum([denseMatchings.extraCount]);
    totals.denseMaximumError = max([denseMatchings.minimumValueError]);
    totals.denseFailures = sum(~reached);
    densePoints = [comparisons.denseGridPointCount];
    totals.denseMedianPoints = median(densePoints);
    totals.denseMinimumPoints = min(densePoints);
    totals.denseMaximumPoints = max(densePoints);
    totals.methodMedianEvaluations = median([comparisons.methodEvaluations]);
    totals.denseMedianEvaluations = median([comparisons.denseEvaluations]);
    totals.methodMedianMilliseconds = median([comparisons.methodSeconds]) * toMilliseconds;
    totals.denseMedianMilliseconds = median([comparisons.denseSeconds]) * toMilliseconds;
    totals.medianEvaluationRatio = median([comparisons.evaluationRatio]);
    totals.medianTimeRatio = median([comparisons.timeRatio]);
    totals.modelMedianMilliseconds = median([comparisons.modelSeconds]) * toMilliseconds;
    totals.edgesVerified = sum([comparisons.bandEdgesVerified]);
    crossovers = [comparisons.crossover];
    totals.crossoverMissCount = sum(~[crossovers.identifiesActiveValley]);
    totals.crossoverMaximumOverestimate = max([crossovers.marginOverestimate]);

    switchComparisons = results.switchComparison;
    catalogue = terra.parameterCatalogue(results.configuration);
    if isempty(switchComparisons)
        totals.methodSwitchErrorText = 'no confirmed switch';
        totals.denseSwitchErrorText = 'no confirmed switch';
    else
        totals.methodSwitchErrorText = describeSwitchErrors(switchComparisons, 'methodError', ...
            catalogue);
        totals.denseSwitchErrorText = describeSwitchErrors(switchComparisons, 'denseError', ...
            catalogue);
    end
end

function description = describeSwitchErrors(switchComparisons, fieldName, catalogue)
%DESCRIBESWITCHERRORS One entry per switch, in the unit of its path.
    parts = cell(1, numel(switchComparisons));
    for switchIndex = 1:numel(switchComparisons)
        item = switchComparisons(switchIndex);
        unit = catalogue(strcmp({catalogue.name}, item.pathName)).unit;
        parts{switchIndex} = sprintf('%s %.2e %s', item.pathName, item.(fieldName), unit);
    end
    description = strjoin(parts, '; ');
end
