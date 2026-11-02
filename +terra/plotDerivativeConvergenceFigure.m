function caption = plotDerivativeConvergenceFigure(results, figureDirectory)
%PLOTDERIVATIVECONVERGENCEFIGURE Figure S3: secant error versus step size.
%   caption = terra.plotDerivativeConvergenceFigure(results,
%   figureDirectory) shows |secant - predicted derivative| against the
%   secant step for every parameter and direction at the nominal point
%   (smooth region). First-order convergence appears as slope 1 on the
%   log-log axes; a slope-1 reference line is drawn below the data.
%   Axis limits are padded beyond the data so that the decade ticks at
%   the ends are labelled in every graphics back end.

    configuration = results.configuration;
    figures = configuration.figures;
    validation = results.derivativeValidation(1);
    parameterNames = unique({validation.rows.parameterName});
    catalogue = terra.parameterCatalogue(configuration);
    figureHandle = terra.createStudyFigure(configuration, figures.standardHeightCentimeters);
    panelCount = numel(parameterNames);
    rowCount = 2;
    columnCount = ceil(panelCount / rowCount);
    logPadding = figures.logAxisPaddingFactor;
    for parameterIndex = 1:panelCount
        rowIndex = ceil(parameterIndex / columnCount);
        columnIndex = parameterIndex - (rowIndex - 1) * columnCount;
        axesHandle = terra.createPanelAxes(figureHandle, configuration, rowIndex, columnIndex, ...
            rowCount, columnCount);
        hold(axesHandle, 'on');
        parameterName = parameterNames{parameterIndex};
        directionHandles = zeros(1, 2);
        allErrors = [];
        smallestStepErrors = zeros(1, 2);
        directions = [1, -1];
        for directionIndex = 1:numel(directions)
            direction = directions(directionIndex);
            selected = validation.rows(strcmp({validation.rows.parameterName}, parameterName) & ...
                [validation.rows.direction] == direction);
            if direction > 0
                style = '-o';
                color = figures.colors.methodMove;
            else
                style = '--s';
                color = figures.colors.baselineMove;
            end
            steps = [selected.step];
            errors = max([selected.absoluteError], realmin);
            directionHandles(directionIndex) = loglog(axesHandle, steps, errors, style, ...
                'Color', color, 'MarkerSize', figures.markerSize - 1);
            allErrors = [allErrors, errors]; %#ok<AGROW>
            [~, smallestStepIndex] = min(steps);
            smallestStepErrors(directionIndex) = errors(smallestStepIndex);
        end
        % Slope-1 reference through the smaller error at the smallest
        % step, shifted down so that it does not hide the data.
        [smallestStep, smallestStepIndex] = min(steps);
        referenceAnchor = min(smallestStepErrors) / figures.referenceSlopeOffsetFactor;
        referenceErrors = referenceAnchor * steps / smallestStep;
        referenceHandle = loglog(axesHandle, steps, referenceErrors, ':', ...
            'Color', figures.colors.requirement);
        allErrors = [allErrors, referenceErrors(smallestStepIndex)]; %#ok<AGROW>
        set(axesHandle, 'XScale', 'log', 'YScale', 'log');
        xlim(axesHandle, [min(steps) / logPadding, max(steps) * logPadding]);
        ylim(axesHandle, [min(allErrors) / logPadding, max(allErrors) * logPadding]);

        yLabelText = '';
        if columnIndex == 1
            yLabelText = '|secant - predicted|';
        end
        % Units differ per parameter, so every panel carries its x label.
        unit = catalogue(strcmp({catalogue.name}, parameterName)).unit;
        if strcmp(unit, '-')
            xLabelText = 'step (dimensionless)';
        else
            xLabelText = sprintf('step (%s)', unit);
        end
        terra.styleAxes(axesHandle, configuration, strrep(parameterName, '_', ' '), ...
            xLabelText, yLabelText);
        if parameterIndex == 1
            legend(axesHandle, [directionHandles, referenceHandle], ...
                {'+d', '-d', 'slope 1'}, 'Location', 'NorthWest', ...
                'FontSize', figures.fontSize - figures.legendFontReduction);
        end
    end
    terra.exportStudyFigure(figureHandle, figureDirectory, 'FigS3_derivative_convergence', ...
        configuration);
    caption = sprintf(['Figure S3. Smooth-region check at %s: error of one-sided secants (circles ' ...
        '+d, squares -d) against the predicted directional derivative; the dotted slope-1 line ' ...
        'is drawn %g times below the data. Steps are in the unit of each parameter (x labels).'], ...
        validation.label, figures.referenceSlopeOffsetFactor);
end
