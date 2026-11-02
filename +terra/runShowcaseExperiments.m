function showcase = runShowcaseExperiments(configuration, results)
%RUNSHOWCASEEXPERIMENTS Table 1 rows and the Figure 3 comparison.
%   showcase = terra.runShowcaseExperiments(configuration, results)
%   assembles the predeclared Table 1 rows (manuscript Section 4.2):
%     1 full model, nominal          2 design model, same controller
%     3 physical perturbation        4 feasible adjustment after 3
%     5 delay perturbation           6 feasible adjustment after 5
%   For every row it collects omega*, b, spectral gap, directed changes
%   D+-, closed-loop status with the exact delay, pointing and command
%   indicators and a time-domain response to the orbital torque bound.
%   For Figure 3 it compares, at the physical and the delay showcase, the
%   unchanged controller, the conventional single-crossover adjustment and
%   the active-branch adjustment (primary rule), and decides per showcase
%   whether the two adjustments differ verifiably; if not, that column of
%   Figure 3 shows the equal-budget screening cost of the two rules and
%   of verifying every move instead (terra.plotRemediationFigure).

    controller = terra.nominalController(configuration);
    scale = configuration.scaling.primaryActuatorScale;
    catalogue = terra.parameterCatalogue(configuration);
    nominalIndex = findCase(results.cases, 'angle', configuration.operatingPoint.panelAngleDegrees, ...
        configuration.operatingPoint.delaySeconds);
    physicalIndex = findCase(results.cases, 'angle', configuration.cases.showcasePhysicalAngleDegrees, ...
        configuration.operatingPoint.delaySeconds);
    delayIndex = findCase(results.cases, 'delay', configuration.operatingPoint.panelAngleDegrees, ...
        configuration.cases.showcaseDelaySeconds);

    rowSpecifications = [ ...
        rowSpecification('Full model, nominal', nominalIndex, 'full', 'unchanged', 'panel_angle'), ...
        rowSpecification('Design model, same controller', nominalIndex, 'design', 'unchanged', ...
            'panel_angle'), ...
        rowSpecification('Physical perturbation', physicalIndex, 'full', 'unchanged', 'panel_angle'), ...
        rowSpecification('Feasible adjustment (physical)', physicalIndex, 'full', 'primary', ...
            'panel_angle'), ...
        rowSpecification('Delay perturbation', delayIndex, 'full', 'unchanged', 'loop_delay'), ...
        rowSpecification('Feasible adjustment (delay)', delayIndex, 'full', 'primary', 'loop_delay')];

    simulationCache = struct('key', {}, 'simulation', {});
    rows = struct([]);
    for rowIndex = 1:numel(rowSpecifications)
        specification = rowSpecifications(rowIndex);
        rowLabel = specification.label;
        caseIndex = specification.caseIndex;
        modeSet = specification.modeSet;
        decisionKind = specification.decisionKind;
        rowParameter = specification.rowParameter;
        caseResult = results.caseResults(caseIndex);
        caseDefinition = results.cases(caseIndex);
        if strcmp(decisionKind, 'primary')
            position = caseResult.selections.(caseResult.primaryField).position;
        else
            position = 0;
        end
        movedController = movedControllerFor(controller, results.moves, position, configuration);
        context = terra.createOperatingContext(configuration, caseDefinition.operatingPoint, ...
            movedController, modeSet, scale);
        valleys = terra.runAdaptiveDiscovery(context);
        crossover = terra.findMainCrossover(context, valleys);
        rowStep = catalogue(strcmp({catalogue.name}, rowParameter)).stepSize;
        driftSensitivity = terra.computeEnvelopeSensitivity(context, valleys, rowParameter, ...
            rowStep, crossover.valleyIndex);
        stability = terra.assessClosedLoopStability(context.plant, movedController, ...
            configuration, caseDefinition.operatingPoint.delaySeconds);
        metrics = terra.evaluateResponseMetrics(context.plant, movedController, configuration, ...
            caseDefinition.operatingPoint.delaySeconds);
        [simulation, simulationCache] = cachedSimulation(simulationCache, ...
            sprintf('%s|%s|%d', caseDefinition.label, modeSet, position), context.plant, ...
            movedController, configuration, caseDefinition.operatingPoint.delaySeconds);

        row.label = rowLabel;
        row.caseLabel = caseDefinition.label;
        row.modeSet = modeSet;
        row.moveLabel = moveLabelFor(results.moves, position);
        row.summary = terra.summarizeValleys(valleys);
        row.rowParameter = rowParameter;
        row.rowStep = rowStep;
        row.driftChangePositive = driftSensitivity.changePositive;
        row.driftChangeNegative = driftSensitivity.changeNegative;
        if position > 0
            adjustedParameter = results.moves(position).parameterName;
            screening = caseResult.fullSensitivities.(adjustedParameter);
            row.adjustedParameter = adjustedParameter;
            row.screeningChangePositive = screening.changePositive;
            row.screeningChangeNegative = screening.changeNegative;
        else
            row.adjustedParameter = '';
            row.screeningChangePositive = NaN;
            row.screeningChangeNegative = NaN;
        end
        row.stability = stability;
        row.guaranteedMargins = terra.guaranteedMultiloopMargins(valleys.minimumValue);
        row.metrics = metrics;
        row.simulation = simulation;
        row.residualFrequencies = context.modeSelection.residualFrequencies;
        row.plantStateCount = context.plant.stateCount;
        if isempty(rows)
            rows = row;
        else
            rows(end + 1) = row; %#ok<AGROW>
        end
    end
    showcase.table1Rows = rows;

    showcaseIndices = [physicalIndex, delayIndex];
    showcaseLabels = {'physical perturbation', 'delay perturbation'};
    roles = terra.figureRoles();
    comparisons = struct([]);
    for showcasePosition = 1:numel(showcaseIndices)
        caseIndex = showcaseIndices(showcasePosition);
        caseResult = results.caseResults(caseIndex);
        caseDefinition = results.cases(caseIndex);
        positions = zeros(1, roles.count);
        positions(roles.unchanged) = 0;
        positions(roles.conventional) = caseResult.selections.(caseResult.conventionalField).position;
        positions(roles.method) = caseResult.selections.(caseResult.primaryField).position;
        roleNames = roles.names;
        entry.label = showcaseLabels{showcasePosition};
        entry.caseLabel = caseDefinition.label;
        entry.roles = roleNames;
        entry.positions = positions;
        entry.moveLabels = cell(1, numel(positions));
        entry.bandMinimum = zeros(1, numel(positions));
        entry.curves = cell(1, numel(positions));
        entry.simulations = cell(1, numel(positions));
        entry.roots = cell(1, numel(positions));
        entry.status = cell(1, numel(positions));
        entry.errorBounds = zeros(1, numel(positions));
        for rolePosition = 1:numel(positions)
            position = positions(rolePosition);
            movedController = movedControllerFor(controller, results.moves, position, configuration);
            context = terra.createOperatingContext(configuration, caseDefinition.operatingPoint, ...
                movedController, 'full', scale);
            valleys = terra.runAdaptiveDiscovery(context);
            plotFrequencies = terra.buildFrequencyGrid(configuration.search.bandRadiansPerSecond, ...
                configuration.figures.curveGridPointCount, context.plant, configuration);
            spectrum = terra.evaluateDiagnosticSpectrum(context, plotFrequencies);
            stability = terra.assessClosedLoopStability(context.plant, movedController, ...
                configuration, caseDefinition.operatingPoint.delaySeconds);
            [simulation, simulationCache] = cachedSimulation(simulationCache, ...
                sprintf('%s|full|%d', caseDefinition.label, position), context.plant, ...
                movedController, configuration, caseDefinition.operatingPoint.delaySeconds);
            entry.moveLabels{rolePosition} = moveLabelFor(results.moves, position);
            entry.bandMinimum(rolePosition) = valleys.minimumValue;
            entry.errorBounds(rolePosition) = valleys.errorBounds(1);
            entry.curves{rolePosition} = struct('frequencies', plotFrequencies, ...
                'values', spectrum(end, :), 'valleyFrequencies', valleys.frequencies, ...
                'valleyValues', valleys.values);
            entry.simulations{rolePosition} = simulation;
            entry.roots{rolePosition} = stability.roots.verifiedRoots;
            entry.status{rolePosition} = stability.status;
        end
        conventionalValue = entry.bandMinimum(roles.conventional);
        methodValue = entry.bandMinimum(roles.method);
        bothStable = strcmp(entry.status{roles.conventional}, 'stable_exact_delay') && ...
            strcmp(entry.status{roles.method}, 'stable_exact_delay');
        separation = abs(methodValue - conventionalValue);
        entry.isVerifiablyDifferent = positions(roles.conventional) ~= positions(roles.method) && ...
            bothStable && separation > entry.errorBounds(roles.conventional) + ...
            entry.errorBounds(roles.method) + configuration.remediation.decisionEqualityTolerance;
        entry.marginDifference = methodValue - conventionalValue;
        if isempty(comparisons)
            comparisons = entry;
        else
            comparisons(end + 1) = entry; %#ok<AGROW>
        end
    end
    showcase.figure3 = comparisons;
end

function specification = rowSpecification(label, caseIndex, modeSet, decisionKind, rowParameter)
%ROWSPECIFICATION One predeclared Table 1 row.
%   decisionKind 'unchanged' uses the nominal controller, 'primary' the
%   decision of the predeclared primary screening rule; rowParameter is
%   the physical parameter whose directed changes D+- the row reports.
    specification.label = label;
    specification.caseIndex = caseIndex;
    specification.modeSet = modeSet;
    specification.decisionKind = decisionKind;
    specification.rowParameter = rowParameter;
end

function index = findCase(cases, family, angleDegrees, delaySeconds)
%FINDCASE Index of the predeclared case with the given family and values.
    index = 0;
    for caseIndex = 1:numel(cases)
        point = cases(caseIndex).operatingPoint;
        if strcmp(cases(caseIndex).family, family) && ...
                point.panelAngleDegrees == angleDegrees && point.delaySeconds == delaySeconds
            index = caseIndex;
            return;
        end
    end
    error('terra:MissingShowcaseCase', ...
        'No %s case at %g deg and %g s; add it to the predeclared case list.', ...
        family, angleDegrees, delaySeconds);
end

function controller = movedControllerFor(controller, moves, position, configuration)
%MOVEDCONTROLLERFOR Controller after the move at position (0 = unchanged).
    if position > 0
        controller = terra.applyControllerMove(controller, moves(position), configuration);
    end
end

function label = moveLabelFor(moves, position)
%MOVELABELFOR Display label of a move position.
    if position > 0
        label = moves(position).label;
    else
        label = 'unchanged';
    end
end

function [simulation, cache] = cachedSimulation(cache, key, plant, controller, ...
        configuration, delaySeconds)
%CACHEDSIMULATION Reuse a time-domain run that was already computed.
    for cacheIndex = 1:numel(cache)
        if strcmp(cache(cacheIndex).key, key)
            simulation = cache(cacheIndex).simulation;
            return;
        end
    end
    simulation = terra.simulateDisturbanceResponse(plant, controller, configuration, delaySeconds);
    cache(end + 1) = struct('key', key, 'simulation', simulation);
end
