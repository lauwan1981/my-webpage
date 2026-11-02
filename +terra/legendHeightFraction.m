function fraction = legendHeightFraction(figureHandle, configuration, anchorAxes, entryCount)
%LEGENDHEIGHTFRACTION Share of an axes height used by an inside legend.
%   fraction = terra.legendHeightFraction(figureHandle, configuration,
%   anchorAxes, entryCount) returns the fraction of the height of
%   anchorAxes taken by terra.addLegendPanel(..., 'insideBottomLeft')
%   with entryCount rows, including the inset below it and the same gap
%   above it. Callers set the lower y limit so that no data fall in this
%   band:  lower = (dataMinimum - fraction * upper) / (1 - fraction).
%   An error is raised when the band would exceed
%   configuration.figures.layout.maximumLegendHeightFraction of the axes.

    layout = configuration.figures.layout;
    formats = terra.outputFormats();
    paperSize = get(figureHandle, 'PaperSize');
    anchorPosition = get(anchorAxes, 'Position');
    axesHeightCentimeters = anchorPosition(4) * paperSize(2);
    bandCentimeters = entryCount * layout.legendRowCentimeters + 2 * layout.legendGapCentimeters;
    fraction = bandCentimeters / axesHeightCentimeters;
    if fraction > layout.maximumLegendHeightFraction
        error('terra:LegendTooTall', ['A %d-row legend needs %.0f %% of the axes height ' ...
            '(at most %.0f %% allowed); use fewer entries or a taller panel.'], entryCount, ...
            formats.fractionToPercent * fraction, ...
            formats.fractionToPercent * layout.maximumLegendHeightFraction);
    end
end
