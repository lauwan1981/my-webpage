function caption = plotRemediationFigure(results, figureDirectory)
%PLOTREMEDIATIONFIGURE Figure 3: conventional versus active-branch adjustment.
%   caption = terra.plotRemediationFigure(results, figureDirectory) uses
%   one column per showcase (physical and delay perturbation). When the
%   conventional single-crossover adjustment and the active-branch
%   adjustment differ verifiably, the column shows f_W on the flexible
%   band, the attitude response and the command (same orbital torque
%   step, same saturation limits) and the rightmost exact-delay roots.
%   Otherwise the column shows the equal-budget screening cost of the two
%   rules and of verifying every move. Role order: terra.figureRoles.
%   The caption describes only what is drawn.

    configuration = results.configuration;
    figures = configuration.figures;
    unitConstants = terra.units();
    formats = terra.outputFormats();
    roles = terra.figureRoles();
    entries = results.showcase.figure3;
    columnCount = numel(entries);
    panelRows.curve = 1;
    panelRows.attitude = 2;
    panelRows.command = 3;
    panelRows.roots = 4;
    rowCount = numel(fieldnames(panelRows));
    roleColors = cell(1, roles.count);
    roleColors{roles.unchanged} = figures.colors.unchanged;
    roleColors{roles.conventional} = figures.colors.baselineMove;
    roleColors{roles.method} = figures.colors.methodMove;
    roleStyles = cell(1, roles.count);
    roleStyles{roles.unchanged} = '-';
    roleStyles{roles.conventional} = '--';
    roleStyles{roles.method} = '-';
    rootMarkers = cell(1, roles.count);
    rootMarkers{roles.unchanged} = 'x';
    rootMarkers{roles.conventional} = 'o';
    rootMarkers{roles.method} = '+';
    legendFontSize = figures.fontSize - figures.legendFontReduction;
    displaySeconds = min(figures.timeResponseDisplaySeconds, ...
        configuration.response.simulationDurationSeconds);
    zoomTicks = figures.remediationZoomTicksRadiansPerSecond;
    zoomTickLabels = arrayfun(@(tick) sprintf('%g', tick), zoomTicks, 'UniformOutput', false);
    figureHandle = terra.createStudyFigure(configuration, figures.pageHeightCentimeters);
    captionParts = cell(1, columnCount);
    isResponseColumn = [entries.isVerifiablyDifferent];

    for column = 1:columnCount
        entry = entries(column);
        if ~entry.isVerifiablyDifferent
            axesHandle = terra.createPanelAxes(figureHandle, configuration, panelRows.curve, ...
                column, rowCount, columnCount);
            drawCostFallback(axesHandle, results, entry, configuration, ...
                panelLetter(panelRows.curve, column, columnCount));
            for row = (panelRows.curve + 1):rowCount
                axis(terra.createPanelAxes(figureHandle, configuration, row, column, ...
                    rowCount, columnCount), 'off');
            end
            captionParts{column} = sprintf(['%s: no verifiably different decision (conventional ' ...
                '"%s", active-branch "%s"); the equal-budget screening cost is shown.'], ...
                entry.label, entry.moveLabels{roles.conventional}, entry.moveLabels{roles.method});
            continue;
        end
        legendLabels = cell(1, roles.count);
        legendLabels{roles.unchanged} = 'unchanged controller';
        legendLabels{roles.conventional} = sprintf('single-crossover: %s', ...
            entry.moveLabels{roles.conventional});
        legendLabels{roles.method} = sprintf('active-branch: %s', entry.moveLabels{roles.method});

        curveAxes = terra.createPanelAxes(figureHandle, configuration, panelRows.curve, column, ...
            rowCount, columnCount);
        hold(curveAxes, 'on');
        for rolePosition = 1:roles.count
            curve = entry.curves{rolePosition};
            semilogx(curveAxes, curve.frequencies, curve.values, roleStyles{rolePosition}, ...
                'Color', roleColors{rolePosition});
        end
        semilogx(curveAxes, configuration.search.bandRadiansPerSecond, ...
            configuration.requirements.diskMarginRequirement * [1, 1], '-.', ...
            'Color', figures.colors.requirement);
        set(curveAxes, 'XScale', 'log', 'XTick', zoomTicks, 'XTickLabel', zoomTickLabels);
        xlim(curveAxes, figures.remediationZoomBandRadiansPerSecond);
        ylim(curveAxes, figures.returnDifferenceAxisLimits);
        terra.styleAxes(curveAxes, configuration, sprintf('(%s) %s: f_W', ...
            panelLetter(panelRows.curve, column, columnCount), entry.label), ...
            '\omega (rad/s)', 'f_W');

        attitudeAxes = terra.createPanelAxes(figureHandle, configuration, panelRows.attitude, ...
            column, rowCount, columnCount);
        hold(attitudeAxes, 'on');
        attitudeHandles = [];
        for rolePosition = 1:roles.count
            simulation = entry.simulations{rolePosition};
            attitudeNorm = sqrt(sum(simulation.attitudeRadians .^ 2, 1));
            attitudeHandles(end + 1) = plot(attitudeAxes, simulation.timeSeconds, ...
                attitudeNorm * unitConstants.radiansToMicroradians, roleStyles{rolePosition}, ...
                'Color', roleColors{rolePosition}); %#ok<AGROW>
        end
        xlim(attitudeAxes, [0, displaySeconds]);
        terra.styleAxes(attitudeAxes, configuration, sprintf('(%s) pointing error', ...
            panelLetter(panelRows.attitude, column, columnCount)), 't (s)', ...
            '||\theta||_2 (\murad)');
        legend(attitudeAxes, attitudeHandles, legendLabels, 'Location', 'SouthEast', ...
            'FontSize', legendFontSize, 'Interpreter', 'none');

        commandAxes = terra.createPanelAxes(figureHandle, configuration, panelRows.command, ...
            column, rowCount, columnCount);
        hold(commandAxes, 'on');
        ratedTorque = configuration.actuator.ratedTorqueNewtonMeters(:);
        for rolePosition = 1:roles.count
            simulation = entry.simulations{rolePosition};
            commandRatio = max(abs(simulation.commandNewtonMeters) ./ ...
                repmat(ratedTorque, 1, numel(simulation.timeSeconds)), [], 1);
            plot(commandAxes, simulation.timeSeconds, commandRatio, roleStyles{rolePosition}, ...
                'Color', roleColors{rolePosition});
        end
        xlim(commandAxes, [0, displaySeconds]);
        terra.styleAxes(commandAxes, configuration, sprintf('(%s) command / rated torque', ...
            panelLetter(panelRows.command, column, columnCount)), 't (s)', ...
            'max_i |u_i| / u_{rated}');

        rootAxes = terra.createPanelAxes(figureHandle, configuration, panelRows.roots, column, ...
            rowCount, columnCount);
        hold(rootAxes, 'on');
        for rolePosition = 1:roles.count
            rootValues = entry.roots{rolePosition};
            shown = real(rootValues) > figures.rootPlotRealPartFloor & ...
                abs(imag(rootValues)) <= figures.rootPlotImaginaryLimit;
            plot(rootAxes, real(rootValues(shown)), imag(rootValues(shown)), ...
                rootMarkers{rolePosition}, 'Color', roleColors{rolePosition}, ...
                'MarkerSize', figures.markerSize);
        end
        plot(rootAxes, [0, 0], figures.rootPlotImaginaryLimit * [-1, 1], ':', ...
            'Color', figures.colors.requirement);
        % Right-half-plane roots (an unstable unchanged loop) stay visible.
        allRoots = vertcat(entry.roots{:});
        shownRoots = allRoots(abs(imag(allRoots)) <= figures.rootPlotImaginaryLimit);
        rightmostShown = max([0; real(shownRoots(:))]);
        upperRealLimit = 0;
        if rightmostShown > 0
            upperRealLimit = rightmostShown + figures.textInsetFraction * ...
                (rightmostShown - figures.rootPlotRealPartFloor);
        end
        xlim(rootAxes, [figures.rootPlotRealPartFloor, upperRealLimit]);
        ylim(rootAxes, figures.rootPlotImaginaryLimit * [-1, 1]);
        terra.styleAxes(rootAxes, configuration, sprintf('(%s) rightmost exact-delay roots', ...
            panelLetter(panelRows.roots, column, columnCount)), 'Re \lambda (1/s)', ...
            'Im \lambda (rad/s)');

        captionParts{column} = sprintf(['%s (%s): b = %.5f unchanged, %.5f single-crossover ' ...
            '"%s", %.5f active-branch "%s"; closed loop %s / %s / %s.'], entry.label, ...
            entry.caseLabel, entry.bandMinimum(roles.unchanged), ...
            entry.bandMinimum(roles.conventional), entry.moveLabels{roles.conventional}, ...
            entry.bandMinimum(roles.method), entry.moveLabels{roles.method}, ...
            entry.status{roles.unchanged}, entry.status{roles.conventional}, ...
            entry.status{roles.method});
    end
    terra.exportStudyFigure(figureHandle, figureDirectory, 'Fig3_remediation', configuration);

    if any(isResponseColumn)
        responseText = sprintf(['Unchanged controller (dark grey), conventional ' ...
            'single-crossover adjustment (dashed orange) and active-branch adjustment (blue), ' ...
            'each verified on the full model with the exact delay. Same orbital torque step ' ...
            'T_ext = %s N m at t = %g s and the same command saturation at %s N m; the first ' ...
            '%g s of the %g s simulation are shown. Curves that coincide within the line width ' ...
            'mean the adjustment has no visible effect on that output. '], ...
            mat2str(configuration.requirements.orbitalDisturbanceTorqueNewtonMeters', ...
            formats.shortVectorDigits), configuration.response.disturbanceOnsetSeconds, ...
            mat2str(configuration.actuator.ratedTorqueNewtonMeters', formats.shortVectorDigits), ...
            displaySeconds, configuration.response.simulationDurationSeconds);
    else
        responseText = '';
    end
    caption = ['Figure 3. ', responseText, strjoin(captionParts, ' ')];
end

function letter = panelLetter(row, column, columnCount)
%PANELLETTER Panel letter a, b, c, ... in row-major order.
    letter = char('a' + (row - 1) * columnCount + column - 1);
end

function drawCostFallback(axesHandle, results, entry, configuration, letter)
%DRAWCOSTFALLBACK Equal-budget screening cost of the two rules for one case.
%   Accounted f_W evaluations of the primary and the conventional rule
%   (same budget) and of verifying every move on the full model.
    caseIndex = find(strcmp({results.caseResults.label}, entry.caseLabel), 1);
    caseResult = results.caseResults(caseIndex);
    primary = caseResult.selections.(caseResult.primaryField);
    conventional = caseResult.selections.(caseResult.conventionalField);
    pipelineLabels = {'active-branch', 'single-crossover', 'all moves'};
    costs = [primary.accountedEvaluations, conventional.accountedEvaluations, ...
        caseResult.costs.exhaustiveEvaluations];
    bar(axesHandle, costs);
    set(axesHandle, 'XTick', 1:numel(pipelineLabels), 'XTickLabel', pipelineLabels);
    terra.styleAxes(axesHandle, configuration, sprintf('(%s) %s: equal-budget screening cost', ...
        letter, entry.label), '', 'f_W evaluations');
end
