function comparison = compareSwitchLocations(configuration, switchRecord, denseGridPointCount)
%COMPARESWITCHLOCATIONS Switch-location error of method and dense baseline.
%   comparison = terra.compareSwitchLocations(configuration, switchRecord,
%   denseGridPointCount) bisects the bracket theta* -/+ Delta (where the
%   swap was confirmed) twice:
%     reference  branch values from the independent state-space evaluator
%                with golden-section refinement in narrow branch windows;
%     dense      band minimum from the plain dense grid of the
%                equal-error size, deciding which branch is lowest;
%   and reports |theta_method - theta_ref| and |theta_dense - theta_ref|
%   (manuscript Section 3.3, "switch parameter error"). Only confirmed
%   switches of the primary W_u scaling are compared (both evaluators use
%   configuration.scaling.primaryActuatorScale). The dense grid is built
%   once outside the timer; denseSeconds covers the bisection only.

    pathName = switchRecord.pathName;
    paths = configuration.paths;
    baseline = configuration.baseline;
    halfBracket = paths.swapCheckStepMultiplier * paths.transversalityStep.(pathName);
    tolerance = baseline.switchBisectionTolerances.(pathName);
    bracket = switchRecord.parameterValue + [-halfBracket, halfBracket];
    branchFrequencies = switchRecord.frequencies;

    referenceTimer = tic;
    [referenceRoot, referenceEvaluations] = bisectSwitch(bracket, tolerance, ...
        baseline.switchBisectionMaximumIterations, @(parameter) referenceLeftIsLower( ...
        configuration, pathName, parameter, branchFrequencies));
    referenceSeconds = toc(referenceTimer);

    if isempty(denseGridPointCount) || isnan(denseGridPointCount)
        denseRoot = NaN;
        denseEvaluations = NaN;
        denseSeconds = NaN;
    else
        % The dense grid does not depend on the path value: built once,
        % outside the timer, as a dense-only study would do.
        denseGrid = terra.buildFrequencyGrid(configuration.search.bandRadiansPerSecond, ...
            denseGridPointCount, [], configuration);
        denseTimer = tic;
        [denseRoot, denseEvaluations] = bisectSwitch(bracket, tolerance, ...
            baseline.switchBisectionMaximumIterations, @(parameter) denseLeftIsLower( ...
            configuration, pathName, parameter, branchFrequencies, denseGrid));
        denseSeconds = toc(denseTimer);
    end

    comparison.pathName = pathName;
    comparison.methodRoot = switchRecord.parameterValue;
    comparison.referenceRoot = referenceRoot;
    comparison.denseRoot = denseRoot;
    comparison.methodError = abs(switchRecord.parameterValue - referenceRoot);
    comparison.denseError = abs(denseRoot - referenceRoot);
    comparison.referenceEvaluations = referenceEvaluations;
    comparison.denseEvaluations = denseEvaluations;
    comparison.referenceSeconds = referenceSeconds;
    comparison.denseSeconds = denseSeconds;
    comparison.methodEvaluations = switchRecord.evaluationCount;
end

function [root, evaluationCount] = bisectSwitch(bracket, tolerance, maximumIterations, leftIsLower)
%BISECTSWITCH Bisection on the identity of the lowest branch.
%   leftIsLower(parameter) returns [isLeftBranchLowest, evaluationsUsed].
%   The bracket ends must hold the left branch (lower end) and the right
%   branch (upper end) as the lowest one; this is verified first.
    [isLeftAtLower, lowerCount] = leftIsLower(bracket(1));
    [isLeftAtUpper, upperCount] = leftIsLower(bracket(2));
    if ~isLeftAtLower || isLeftAtUpper
        error('terra:SwitchNotBracketed', ['The lowest branch does not change from left ' ...
            'to right across [%.12g, %.12g].'], bracket(1), bracket(2));
    end
    lowerBound = bracket(1);
    upperBound = bracket(2);
    evaluationCount = lowerCount + upperCount;
    iteration = 0;
    while (upperBound - lowerBound) > tolerance && iteration < maximumIterations
        iteration = iteration + 1;
        midpoint = (lowerBound + upperBound) / 2;
        [isLeftLowest, evaluationsUsed] = leftIsLower(midpoint);
        evaluationCount = evaluationCount + evaluationsUsed;
        if isLeftLowest
            lowerBound = midpoint;
        else
            upperBound = midpoint;
        end
    end
    if (upperBound - lowerBound) > tolerance
        error('terra:BisectionNotConverged', ['Switch bisection stopped after %d iterations ' ...
            'with a bracket of %.3g (tolerance %.3g).'], maximumIterations, ...
            upperBound - lowerBound, tolerance);
    end
    root = (lowerBound + upperBound) / 2;
end

function [isLeftLowest, evaluationCount] = referenceLeftIsLower(configuration, pathName, ...
        parameter, branchFrequencies)
%REFERENCELEFTISLOWER Independent evaluator, narrow golden-section windows.
    context = switchContext(configuration, pathName, parameter, 'state_space');
    window = configuration.baseline.switchReferenceWindowLog;
    objective = @(frequency) terra.evaluateMinimumSingularValue(context, frequency);
    branchValues = zeros(1, 2);
    evaluationCount = 0;
    for branchIndex = 1:2
        [~, branchValues(branchIndex), used] = terra.goldenSectionMinimize(objective, ...
            branchFrequencies(branchIndex) * exp(-window), ...
            branchFrequencies(branchIndex) * exp(window), ...
            configuration.baseline.referenceRefinementRelativeTolerance, ...
            configuration.search.goldenSectionMaximumIterations);
        evaluationCount = evaluationCount + used;
    end
    isLeftLowest = branchValues(1) < branchValues(2);
end

function [isLeftLowest, evaluationCount] = denseLeftIsLower(configuration, pathName, ...
        parameter, branchFrequencies, frequencies)
%DENSELEFTISLOWER Plain dense grid: which branch holds the band minimum.
%   Only the points of the dense grid that fall inside the two branch
%   windows are evaluated. Because every other valley is strictly higher
%   near the switch (third-valley gap checked by
%   terra.locateDominantSwitches), the band minimum of the full dense grid
%   lies in one of these windows, so the decision is identical to a
%   full-band dense evaluation at a fraction of the cost.
    context = switchContext(configuration, pathName, parameter, 'modal');
    window = configuration.baseline.switchReferenceWindowLog;
    branchMinima = zeros(1, 2);
    evaluationCount = 0;
    for branchIndex = 1:2
        insideWindow = abs(log(frequencies / branchFrequencies(branchIndex))) <= window;
        if ~any(insideWindow)
            error('terra:EmptyDenseWindow', ['No dense grid point lies within %g (log) of ' ...
                '%.6g rad/s.'], window, branchFrequencies(branchIndex));
        end
        spectrum = terra.evaluateDiagnosticSpectrum(context, frequencies(insideWindow));
        branchMinima(branchIndex) = min(spectrum(end, :));
        evaluationCount = evaluationCount + sum(insideWindow);
    end
    isLeftLowest = branchMinima(1) < branchMinima(2);
end

function context = switchContext(configuration, pathName, parameter, evaluatorKind)
%SWITCHCONTEXT Full model at one path value with the chosen evaluator.
    controller = terra.nominalController(configuration);
    operatingPoint = terra.setParameterValue(configuration, ...
        terra.nominalOperatingPoint(configuration), controller, pathName, parameter);
    spacecraftModel = terra.buildSpacecraftModel(configuration, operatingPoint);
    plant = terra.buildPlantModel(spacecraftModel, ...
        1:numel(spacecraftModel.systemModes.eigenvalues), 'full');
    context = terra.createDiagnosticContext(plant, controller, configuration, ...
        operatingPoint.delaySeconds, configuration.scaling.primaryActuatorScale, ...
        evaluatorKind, 'switch bisection');
end
