function caption = plotBranchFigure(results, figureDirectory)
%PLOTBRANCHFIGURE Figure 2: branches b_k, envelope, switches, one-sided secants.
%   caption = terra.plotBranchFigure(results, figureDirectory) shows, for
%   the drive-angle path and the delay path, every tracked valley branch,
%   the lower envelope b_W,Omega for the primary scaling, the envelope for
%   the alternate scaling, and switch markers (filled: confirmed dominant
%   switch; open: candidate branch equality). The bottom panels compare
%   one-sided secants with the predicted one-sided derivatives at the
%   first confirmed switch of each path, scaled by the declared steps h
%   so that every curve is a first-order margin change D.

    configuration = results.configuration;
    figures = configuration.figures;
    unitConstants = terra.units();
    pathSettings = struct( ...
        'pathName', {'panel_angle', 'loop_delay'}, ...
        'axisScale', {1, unitConstants.secondsToMilliseconds}, ...
        'axisUnit', {'deg', 'ms'}, ...
        'axisLabel', {'Drive angle \theta (deg)', 'Loop delay \tau (ms)'}, ...
        'title', {'(a) drive-angle path', '(b) delay path'});
    figureHandle = terra.createStudyFigure(configuration, figures.tallHeightCentimeters);
    switchSummaries = cell(1, numel(pathSettings));
    legendFontSize = figures.fontSize - figures.legendFontReduction;

    for pathIndex = 1:numel(pathSettings)
        setting = pathSettings(pathIndex);
        pathName = setting.pathName;
        axisScale = setting.axisScale;
        entry = results.paths.(pathName);
        axesHandle = terra.createPanelAxes(figureHandle, configuration, 1, pathIndex, 2, 2);
        hold(axesHandle, 'on');
        tracks = entry.primary.tracks;
        for branchIndex = 1:tracks.branchCount
            plot(axesHandle, axisScale * tracks.pathValues, tracks.value(:, branchIndex)', '-', ...
                'Color', figures.colors.branch, 'LineWidth', figures.thinLineWidth);
        end
        envelope = plot(axesHandle, axisScale * entry.primary.scan.pathValues, ...
            entry.primary.scan.minimumValues, '-', 'Color', figures.colors.envelope, ...
            'LineWidth', 2 * figures.lineWidth);
        alternate = plot(axesHandle, axisScale * entry.alternate.scan.pathValues, ...
            entry.alternate.scan.minimumValues, '--', 'Color', figures.colors.alternate, ...
            'LineWidth', figures.lineWidth);
        requirementValue = configuration.requirements.diskMarginRequirement;
        pathLimits = axisScale * entry.primary.scan.pathValues([1, end]);
        plot(axesHandle, pathLimits, requirementValue * [1, 1], '-.', ...
            'Color', figures.colors.requirement);
        switchSummaries{pathIndex} = drawSwitches(axesHandle, entry.primary.switches, ...
            axisScale, setting.axisUnit, figures, 'o', figures.colors.confirmed);
        drawSwitches(axesHandle, entry.alternate.switches, axisScale, setting.axisUnit, ...
            figures, 'd', figures.colors.alternate);
        lowestValue = min([entry.primary.scan.minimumValues, entry.alternate.scan.minimumValues]);
        lowerLimit = min(figures.branchAxisLowerLimit, ...
            figures.branchAxisPadding * floor(lowestValue / figures.branchAxisPadding) - ...
            figures.branchAxisPadding);
        ylim(axesHandle, [lowerLimit, figures.branchAxisUpperLimit]);
        xlim(axesHandle, pathLimits);
        text(pathLimits(2) - figures.textInsetFraction * diff(pathLimits), requirementValue, ...
            'requirement 1/\gamma', 'Parent', axesHandle, 'Color', figures.colors.requirement, ...
            'FontSize', legendFontSize, 'VerticalAlignment', 'top', 'HorizontalAlignment', 'right');
        terra.styleAxes(axesHandle, configuration, setting.title, setting.axisLabel, ...
            'b_k and b_{W,\Omega}');
        legend(axesHandle, [envelope, alternate], {'b_{W,\Omega}, primary W_u', ...
            'b_{W,\Omega}, alternate W_u'}, 'Location', 'SouthWest', 'FontSize', legendFontSize);
        noteText = '';
        if isempty(entry.primary.switches)
            noteText = 'no change of the active branch';
        elseif all(isnan([entry.primary.switches.parameterValue]))
            noteText = 'active-branch change not resolved';
        end
        if ~isempty(noteText)
            text(figures.textInsetFraction, 1 - figures.textInsetFraction, noteText, ...
                'Units', 'normalized', 'Parent', axesHandle, 'VerticalAlignment', 'top');
        end
    end

    secantPanels = struct('pathName', {'panel_angle', 'loop_delay'}, ...
        'title', {'(c) one-sided secants at the angle switch', ...
                  '(d) one-sided secants at the delay switch'});
    for panelIndex = 1:numel(secantPanels)
        axesHandle = terra.createPanelAxes(figureHandle, configuration, 2, panelIndex, 2, 2);
        validation = firstSwitchValidation(results.derivativeValidation, ...
            secantPanels(panelIndex).pathName);
        if isempty(validation)
            axis(axesHandle, 'off');
            text(figures.textInsetFraction, 1 - figures.textInsetFraction, ...
                'no confirmed switch: secant check not applicable', ...
                'Units', 'normalized', 'Parent', axesHandle, 'VerticalAlignment', 'top');
            continue;
        end
        terra.styleAxes(axesHandle, configuration, secantPanels(panelIndex).title, ...
            'secant step / largest step', 'h_i \times one-sided secant');
        drawSecants(figureHandle, axesHandle, validation, configuration);
    end
    terra.exportStudyFigure(figureHandle, figureDirectory, 'Fig2_branches_switches', configuration);

    caption = sprintf(['Figure 2. (a, b) Tracked valley branches b_k (thin), lower envelope ' ...
        'b_W,Omega for the primary W_u (thick) and the alternate W_u (dashed); filled red ' ...
        'circles = confirmed dominant switch for the primary W_u (global-minimum equality, ' ...
        'transversal crossing, swap of the lowest branch, non-degenerate valleys), filled grey ' ...
        'diamonds = the same for the alternate W_u, open orange = candidate branch equality. %s %s ' ...
        '(c, d) One-sided secants (solid +d, dashed -d) multiplied by the declared step h_i ' ...
        'converge to the predicted one-sided changes D (dotted); +d and -d differ at a switch.'], ...
        switchSummaries{1}, switchSummaries{2});
end

function summary = drawSwitches(axesHandle, switches, axisScale, axisUnit, figures, marker, ...
        confirmedColor)
%DRAWSWITCHES Confirmed switches filled, candidate equalities open.
%   Unresolved records (no located root) are not drawn but are listed in
%   the returned caption text with their interval.
    parts = {};
    for switchIndex = 1:numel(switches)
        item = switches(switchIndex);
        statusText = strrep(item.status, '_', ' ');
        if isnan(item.parameterValue)
            parts{end + 1} = sprintf('%s in [%.6g, %.6g] %s', statusText, ...
                axisScale * item.interval(1), axisScale * item.interval(2), axisUnit); %#ok<AGROW>
            continue;
        end
        if strcmp(item.status, 'confirmed_dominant_switch')
            plot(axesHandle, axisScale * item.parameterValue, item.value, marker, ...
                'Color', confirmedColor, 'MarkerFaceColor', confirmedColor, ...
                'MarkerSize', figures.markerSize + 1);
        else
            plot(axesHandle, axisScale * item.parameterValue, item.value, marker, ...
                'Color', figures.colors.candidate, 'MarkerSize', figures.markerSize + 1);
        end
        parts{end + 1} = sprintf('%s at %.6g %s (b = %.5f, %.3g <-> %.3g rad/s)', ...
            statusText, axisScale * item.parameterValue, axisUnit, item.value, ...
            item.frequencies(1), item.frequencies(2)); %#ok<AGROW>
    end
    if isempty(parts)
        summary = 'No change of the active branch on this path.';
    else
        summary = [strjoin(parts, '; '), '.'];
    end
end

function validation = firstSwitchValidation(validations, pathName)
%FIRSTSWITCHVALIDATION Derivative study at the first switch of a path.
    validation = [];
    for index = 1:numel(validations)
        if strncmp(validations(index).label, pathName, numel(pathName))
            validation = validations(index);
            return;
        end
    end
end

function drawSecants(figureHandle, axesHandle, validation, configuration)
%DRAWSECANTS h-scaled secants against relative step, with a key below the data.
%   The lower y limit is extended so that the key (one row per curve,
%   terra.addLegendPanel 'insideBottomLeft') never covers a curve, even
%   when two one-sided changes D are closer than a text line.
    figures = configuration.figures;
    catalogue = terra.parameterCatalogue(configuration);
    parameterNames = unique({validation.rows.parameterName});
    hold(axesHandle, 'on');
    secantHandles = [];
    labels = {};
    allValues = [];
    for parameterIndex = 1:numel(parameterNames)
        parameterName = parameterNames{parameterIndex};
        declaredStep = catalogue(strcmp({catalogue.name}, parameterName)).stepSize;
        color = figures.axisColors{mod(parameterIndex - 1, numel(figures.axisColors)) + 1};
        for direction = [1, -1]
            selected = validation.rows(strcmp({validation.rows.parameterName}, parameterName) & ...
                [validation.rows.direction] == direction);
            steps = [selected.step];
            relativeSteps = steps / max(steps);
            scaledSecants = declaredStep * [selected.secant];
            predictedChange = declaredStep * selected(1).predicted;
            if direction > 0
                style = '-o';
                directionText = '+d';
            else
                style = '--s';
                directionText = '-d';
            end
            secantHandles(end + 1) = plot(axesHandle, relativeSteps, scaledSecants, style, ...
                'Color', color, 'MarkerSize', figures.markerSize - 1); %#ok<AGROW>
            plot(axesHandle, [min(relativeSteps), max(relativeSteps)], predictedChange * [1, 1], ...
                ':', 'Color', color);
            labels{end + 1} = sprintf('%s %s: D = %+.4f', strrep(parameterName, '_', ' '), ...
                directionText, predictedChange); %#ok<AGROW>
            allValues = [allValues, scaledSecants, predictedChange]; %#ok<AGROW>
        end
    end
    set(axesHandle, 'XScale', 'log', 'XDir', 'reverse');
    % Every parameter uses the same declared step fractions.
    stepFractions = configuration.derivatives.secantStepFractions;
    xlim(axesHandle, [min(stepFractions) / figures.logAxisPaddingFactor, ...
        max(stepFractions) * figures.logAxisPaddingFactor]);
    valueRange = max(allValues) - min(allValues);
    padding = figures.secantAxisPaddingFraction * valueRange;
    upperLimit = max(allValues) + padding;
    lowestDataLevel = min(allValues) - padding;
    keyFraction = terra.legendHeightFraction(figureHandle, configuration, axesHandle, ...
        numel(secantHandles));
    lowerLimit = (lowestDataLevel - keyFraction * upperLimit) / (1 - keyFraction);
    ylim(axesHandle, [lowerLimit, upperLimit]);
    terra.addLegendPanel(figureHandle, configuration, axesHandle, secantHandles, labels, ...
        'insideBottomLeft');
end
