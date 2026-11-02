function formats = outputFormats()
%OUTPUTFORMATS Significant digits used when numbers are written as text.
%   formats = terra.outputFormats() is the single place that fixes how
%   many significant digits the report, tables, captions and manifest
%   print, so that no output function contains a bare precision literal.

    % Short vectors such as rated torques, W_u entries and T_ext.
    formats.shortVectorDigits = 3;
    % Inertia diagonals (kg m^2), compared with the controller reference.
    formats.inertiaDigits = 6;
    % Lists of mode frequencies (rad/s).
    formats.frequencyListDigits = 5;
    % Numeric cells of the CSV tables (same precision as '%.10g').
    formats.csvDigits = 10;
    % Numeric cells of tables.md.
    formats.markdownDigits = 4;
    % Configuration dump of the reproducibility manifest.
    formats.manifestDigits = 12;
    % Conversion of a fraction to percent.
    formats.fractionToPercent = 100;
end
