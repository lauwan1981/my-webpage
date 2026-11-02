function caption = plotResidualPathFigure(results, figureDirectory)
%PLOTRESIDUALPATHFIGURE Figure S4: residual-mode path and delay margins.
%   caption = terra.plotResidualPathFigure(results, figureDirectory) shows
%   (a) valley branches and envelope when the third cantilever mode moves
%   over the source's uncertainty range, and (b, c) the exact
%   common-delay margin along the drive-angle and residual-mode paths.

    configuration = results.configuration;
    figures = configuration.figures;
    unitConstants = terra.units();
    formats = terra.outputFormats();
    entry = results.paths.mode3_frequency.primary;
    legendFontSize = figures.fontSize - figures.legendFontReduction;
    figureHandle = terra.createStudyFigure(configuration, figures.standardHeightCentimeters);

    branchAxes = terra.createPanelAxes(figureHandle, configuration, 1, 1, 2, 2, 2);
    hold(branchAxes, 'on');
    branchHandle = [];
    for branchIndex = 1:entry.tracks.branchCount
        branchHandle = plot(branchAxes, entry.tracks.pathValues, ...
            entry.tracks.value(:, branchIndex)', '-', 'Color', figures.colors.branch, ...
            'LineWidth', figures.thinLineWidth);
    end
    envelopeHandle = plot(branchAxes, entry.scan.pathValues, entry.scan.minimumValues, '-', ...
        'Color', figures.colors.envelope, 'LineWidth', 2 * figures.lineWidth);
    requirementHandle = plot(branchAxes, entry.scan.pathValues([1, end]), ...
        configuration.requirements.diskMarginRequirement * [1, 1], '-.', ...
        'Color', figures.colors.requirement);
    statusParts = {};
    for switchIndex = 1:numel(entry.switches)
        item = entry.switches(switchIndex);
        if strcmp(item.status, 'confirmed_dominant_switch')
            plot(branchAxes, item.parameterValue, item.value, 'o', 'Color', figures.colors.confirmed, ...
                'MarkerFaceColor', figures.colors.confirmed);
        elseif ~isnan(item.parameterValue)
            plot(branchAxes, item.parameterValue, item.value, 'o', 'Color', figures.colors.candidate);
        end
        if isnan(item.parameterValue)
            statusParts{end + 1} = sprintf('%s in [%.6g, %.6g] rad/s', ...
                strrep(item.status, '_', ' '), item.interval(1), item.interval(2)); %#ok<AGROW>
        else
            statusParts{end + 1} = sprintf('%s at %.6g rad/s', strrep(item.status, '_', ' '), ...
                item.parameterValue); %#ok<AGROW>
        end
    end
    xlim(branchAxes, entry.scan.pathValues([1, end]));
    ylim(branchAxes, [figures.branchAxisLowerLimit, figures.branchAxisUpperLimit]);
    nominalPoint = configuration.operatingPoint;
    terra.styleAxes(branchAxes, configuration, sprintf(['(a) third cantilever mode frequency ' ...
        'path (\\theta = %g deg, \\tau = %g ms)'], nominalPoint.panelAngleDegrees, ...
        nominalPoint.delaySeconds * unitConstants.secondsToMilliseconds), ...
        '\omega_3 (rad/s)', 'b_k and b_{W,\Omega}');
    legendHandles = [envelopeHandle, requirementHandle];
    legendLabels = {'b_{W,\Omega}', 'requirement 1/\gamma'};
    if ~isempty(branchHandle)
        legendHandles = [branchHandle, legendHandles];
        legendLabels = [{'valley branches b_k'}, legendLabels];
    end
    legend(branchAxes, legendHandles, legendLabels, 'Location', 'SouthEast', ...
        'FontSize', legendFontSize);

    angleEntry = results.paths.panel_angle.primary;
    angleAxes = terra.createPanelAxes(figureHandle, configuration, 2, 1, 2, 2);
    plot(angleAxes, angleEntry.scan.pathValues, ...
        angleEntry.scan.delayMarginSeconds * unitConstants.secondsToMilliseconds, '-o', ...
        'Color', figures.colors.full, 'MarkerSize', figures.markerSize - 2);
    xlim(angleAxes, angleEntry.scan.pathValues([1, end]));
    terra.styleAxes(angleAxes, configuration, '(b) delay margin vs drive angle', ...
        '\theta (deg)', '\tau_{dm} (ms)');

    modeAxes = terra.createPanelAxes(figureHandle, configuration, 2, 2, 2, 2);
    plot(modeAxes, entry.scan.pathValues, ...
        entry.scan.delayMarginSeconds * unitConstants.secondsToMilliseconds, '-o', ...
        'Color', figures.colors.full, 'MarkerSize', figures.markerSize - 2);
    xlim(modeAxes, entry.scan.pathValues([1, end]));
    terra.styleAxes(modeAxes, configuration, '(c) delay margin vs \omega_3', ...
        '\omega_3 (rad/s)', '\tau_{dm} (ms)');
    terra.exportStudyFigure(figureHandle, figureDirectory, 'FigS4_residual_mode_path', configuration);

    if isempty(statusParts)
        switchText = 'No switch observed.';
    else
        switchText = [strjoin(statusParts, '; '), '.'];
    end
    caption = sprintf(['Figure S4. Out-of-sample structural path: the third cantilever mode of ' ...
        'both arrays is moved over %.4g-%.4g rad/s (source uncertainty +-%g %%). %s The exact ' ...
        'common-delay margin uses the eigen-loci crossing condition with certified tails.'], ...
        min(entry.scan.pathValues), max(entry.scan.pathValues), ...
        formats.fractionToPercent * configuration.structure.modeFrequencyRelativeUncertainty, ...
        switchText);
end
