function axesHandle = createPanelAxes(figureHandle, configuration, rowIndex, columnIndex, ...
        rowCount, columnCount, columnSpan, rightReserveCentimeters)
%CREATEPANELAXES Axes at a fixed grid position defined in centimetres.
%   axesHandle = terra.createPanelAxes(figureHandle, configuration,
%   rowIndex, columnIndex, rowCount, columnCount) places panel
%   (rowIndex, columnIndex) of a rowCount x columnCount grid using the
%   margins and gaps of configuration.figures.layout. Optional:
%       columnSpan               number of grid columns the panel spans
%       rightReserveCentimeters  width kept free at the right edge of the
%                                figure (legends placed beside the axes)
%   Fixed positions keep tick labels, axis labels and titles of
%   neighbouring panels apart in every graphics back end, unlike the
%   default subplot spacing. Never use 'Location', '...Outside' legends
%   on these axes: they resize the axes; use terra.addLegendPanel.

    if nargin < 7
        columnSpan = 1;
    end
    if nargin < 8
        rightReserveCentimeters = 0;
    end
    layout = configuration.figures.layout;
    paperSize = get(figureHandle, 'PaperSize');
    widthCentimeters = paperSize(1);
    heightCentimeters = paperSize(2);

    usableWidth = widthCentimeters - layout.leftMarginCentimeters - ...
        layout.rightMarginCentimeters - rightReserveCentimeters;
    panelWidth = (usableWidth - (columnCount - 1) * layout.horizontalGapCentimeters) / columnCount;
    panelHeight = (heightCentimeters - layout.topMarginCentimeters - ...
        layout.bottomMarginCentimeters - (rowCount - 1) * layout.verticalGapCentimeters) / rowCount;
    left = layout.leftMarginCentimeters + (columnIndex - 1) * ...
        (panelWidth + layout.horizontalGapCentimeters);
    bottom = layout.bottomMarginCentimeters + (rowCount - rowIndex) * ...
        (panelHeight + layout.verticalGapCentimeters);
    width = columnSpan * panelWidth + (columnSpan - 1) * layout.horizontalGapCentimeters;

    position = [left / widthCentimeters, bottom / heightCentimeters, ...
        width / widthCentimeters, panelHeight / heightCentimeters];
    axesHandle = axes('Parent', figureHandle, 'Position', position);
end
