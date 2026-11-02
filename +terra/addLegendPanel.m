function panelAxes = addLegendPanel(figureHandle, configuration, anchorAxes, lineHandles, ...
        labels, placement)
%ADDLEGENDPANEL Legend drawn with plain line and text objects.
%   panelAxes = terra.addLegendPanel(figureHandle, configuration,
%   anchorAxes, lineHandles, labels) draws one row per entry, a short
%   sample of lineHandles(k) (colour, line style, line width and marker)
%   followed by labels{k} (TeX interpreter), in an invisible axes placed
%   in the column kept free by terra.createPanelAxes(...,
%   rightReserveCentimeters), top aligned with anchorAxes.
%
%   panelAxes = terra.addLegendPanel(..., placement) chooses the place:
%       'right'             (default) the reserved column described above
%       'insideBottomLeft'  inside anchorAxes, bottom left; the caller
%                           keeps that band free of data by choosing the
%                           y limits with terra.legendHeightFraction
%
%   The legend is built from ordinary graphics objects, so it sits at the
%   same place in MATLAB and in every Octave toolkit. A legend object
%   would not: 'EastOutside' shrinks the axes, and Octave's gnuplot
%   toolkit ignores a legend 'Position'.

    if nargin < 6
        placement = 'right';
    end
    figures = configuration.figures;
    layout = figures.layout;
    paperSize = get(figureHandle, 'PaperSize');
    anchorPosition = get(anchorAxes, 'Position');
    entryCount = numel(lineHandles);
    panelHeight = min(entryCount * layout.legendRowCentimeters / paperSize(2), anchorPosition(4));

    switch placement
        case 'right'
            panelWidthCentimeters = layout.legendColumnCentimeters - layout.legendGapCentimeters;
            panelLeft = anchorPosition(1) + anchorPosition(3) + ...
                layout.legendGapCentimeters / paperSize(1);
            panelBottom = anchorPosition(2) + anchorPosition(4) - panelHeight;
        case 'insideBottomLeft'
            insetCentimeters = layout.legendGapCentimeters;
            panelWidthCentimeters = anchorPosition(3) * paperSize(1) - 2 * insetCentimeters;
            panelLeft = anchorPosition(1) + insetCentimeters / paperSize(1);
            panelBottom = anchorPosition(2) + insetCentimeters / paperSize(2);
        otherwise
            error('terra:UnknownPlacement', 'Unknown legend placement "%s".', placement);
    end
    % Horizontal data units of the panel are centimetres.
    panelAxes = axes('Parent', figureHandle, ...
        'Position', [panelLeft, panelBottom, panelWidthCentimeters / paperSize(1), panelHeight], ...
        'XLim', [0, panelWidthCentimeters], 'YLim', [0, entryCount], 'Visible', 'off');

    % Row k is centred at y = entryCount - k + 1/2 (first entry on top).
    rowCentreOffset = 0.5;
    sampleStart = layout.legendSampleStartCentimeters;
    sampleEnd = layout.legendSampleEndCentimeters;
    sampleCentre = (sampleStart + sampleEnd) / 2;
    legendFontSize = figures.fontSize - figures.legendFontReduction;
    for entryIndex = 1:entryCount
        source = lineHandles(entryIndex);
        rowCentre = entryCount - entryIndex + rowCentreOffset;
        line([sampleStart, sampleEnd], [rowCentre, rowCentre], 'Parent', panelAxes, ...
            'Color', get(source, 'Color'), 'LineStyle', get(source, 'LineStyle'), ...
            'LineWidth', get(source, 'LineWidth'), 'Marker', 'none');
        if ~strcmp(get(source, 'Marker'), 'none')
            line(sampleCentre, rowCentre, 'Parent', panelAxes, 'Color', get(source, 'Color'), ...
                'LineStyle', 'none', 'Marker', get(source, 'Marker'), ...
                'MarkerSize', get(source, 'MarkerSize'), 'LineWidth', get(source, 'LineWidth'), ...
                'MarkerFaceColor', get(source, 'MarkerFaceColor'));
        end
        text(layout.legendTextStartCentimeters, rowCentre, labels{entryIndex}, ...
            'Parent', panelAxes, 'FontSize', legendFontSize, 'Interpreter', 'tex', ...
            'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle');
    end
end
