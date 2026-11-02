function caption = plotDecisionFigure(results, figureDirectory)
%PLOTDECISIONFIGURE Figure S2: verified band minima of every decision rule.
%   caption = terra.plotDecisionFigure(results, figureDirectory) plots, per
%   case, the full-model band minimum of the unchanged controller, of the
%   exhaustive optimum over all declared moves, of the primary-rule and
%   conventional decisions (equal budget) and of the decision taken on
%   the design model, plus the exact common-delay margin of the unchanged
%   loop.

    configuration = results.configuration;
    figures = configuration.figures;
    unitConstants = terra.units();
    caseResults = results.caseResults;
    caseNumbers = 1:numel(caseResults);
    unchanged = zeros(size(caseNumbers));
    oracle = zeros(size(caseNumbers));
    primary = zeros(size(caseNumbers));
    conventional = zeros(size(caseNumbers));
    designDecision = zeros(size(caseNumbers));
    delayMargins = zeros(size(caseNumbers));
    for caseIndex = caseNumbers
        item = caseResults(caseIndex);
        unchanged(caseIndex) = item.fullSummary.minimumValue;
        oracle(caseIndex) = item.oracle.value;
        primary(caseIndex) = item.selections.(item.primaryField).value;
        conventional(caseIndex) = item.selections.(item.conventionalField).value;
        designDecision(caseIndex) = item.designDecision.fullModelValue;
        delayMargins(caseIndex) = item.stabilityFull.delayMarginSeconds * ...
            unitConstants.secondsToMilliseconds;
    end
    caseLimits = [1 - figures.categoryAxisPadding, numel(caseNumbers) + figures.categoryAxisPadding];
    legendReserve = figures.layout.legendColumnCentimeters;
    figureHandle = terra.createStudyFigure(configuration, figures.standardHeightCentimeters);

    marginAxes = terra.createPanelAxes(figureHandle, configuration, 1, 1, 2, 1, 1, legendReserve);
    hold(marginAxes, 'on');
    handles = [ ...
        plot(marginAxes, caseNumbers, unchanged, '-o', 'Color', figures.colors.unchanged), ...
        plot(marginAxes, caseNumbers, oracle, '-', 'Color', figures.colors.oracleMove, ...
            'LineWidth', 2 * figures.lineWidth), ...
        plot(marginAxes, caseNumbers, primary, '--^', 'Color', figures.colors.methodMove), ...
        plot(marginAxes, caseNumbers, conventional, ':s', 'Color', figures.colors.baselineMove), ...
        plot(marginAxes, caseNumbers, designDecision, '-.d', 'Color', figures.colors.designMove), ...
        plot(marginAxes, caseLimits, configuration.requirements.diskMarginRequirement * [1, 1], ...
            '-.', 'Color', figures.colors.requirement)];
    dataLineCount = numel(handles) - 1;
    set(handles(1:dataLineCount), 'MarkerSize', figures.markerSize - 1);
    terra.styleAxes(marginAxes, configuration, '(a) verified full-model band minimum per decision', ...
        '', 'b_{W,\Omega}');
    terra.styleCaseAxis(marginAxes, configuration, results.cases, false);
    moveCount = numel(results.moves);
    remediation = configuration.remediation;
    terra.addLegendPanel(figureHandle, configuration, marginAxes, handles, {'unchanged', ...
        sprintf('best of %d (benchmark)', moveCount), ...
        sprintf('%s top-%d', strrep(remediation.primaryRule, '_', '-'), remediation.primaryBudget), ...
        sprintf('%s top-%d', strrep(remediation.conventionalRule, '_', '-'), ...
        remediation.primaryBudget), ...
        'decided on design model', 'requirement 1/\gamma'});

    delayAxes = terra.createPanelAxes(figureHandle, configuration, 2, 1, 2, 1, 1, legendReserve);
    plot(delayAxes, caseNumbers, delayMargins, '-o', 'Color', figures.colors.full, ...
        'MarkerSize', figures.markerSize - 1);
    terra.styleAxes(delayAxes, configuration, '(b) exact common-delay margin, unchanged controller', ...
        '', '\tau_{dm} (ms)');
    terra.styleCaseAxis(delayAxes, configuration, results.cases, true);
    terra.exportStudyFigure(figureHandle, figureDirectory, 'FigS2_decisions', configuration);

    labels = cell(1, numel(caseResults));
    for caseIndex = caseNumbers
        labels{caseIndex} = sprintf('%d = %s', caseIndex, caseResults(caseIndex).label);
    end
    caption = sprintf(['Figure S2. Every decision is verified by a full-band re-search on the full ' ...
        'model; the best-of-%d curve evaluates all moves and serves only as a benchmark. Cases: %s.'], ...
        numel(results.moves), strjoin(labels, ', '));
end
