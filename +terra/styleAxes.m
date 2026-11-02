function styleAxes(axesHandle, configuration, titleText, xLabelText, yLabelText)
%STYLEAXES Grid, box, labels and title in the house style.
%   terra.styleAxes(axesHandle, configuration, titleText, xLabelText,
%   yLabelText) applies the common formatting; empty strings are skipped.

    figures = configuration.figures;
    set(axesHandle, 'FontSize', figures.fontSize, 'Box', 'on', 'TickDir', 'out', ...
        'XGrid', 'on', 'YGrid', 'on');
    if ~isempty(titleText)
        title(axesHandle, titleText, 'FontSize', figures.titleFontSize, 'FontWeight', 'normal');
    end
    if ~isempty(xLabelText)
        xlabel(axesHandle, xLabelText);
    end
    if ~isempty(yLabelText)
        ylabel(axesHandle, yLabelText);
    end
end
