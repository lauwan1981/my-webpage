function writeCsvTable(fileName, header, rows)
%WRITECSVTABLE Write a header row and a cell matrix as RFC-4180 CSV.
%   terra.writeCsvTable(fileName, header, rows) writes header (1xC cell of
%   column names) and rows (RxC cell). Numbers and numeric arrays use the
%   csvDigits significant digits of terra.outputFormats, logicals 0/1,
%   NaN/Inf literally; text is quoted when it contains a comma, a quote
%   or a line break.

    fileIdentifier = fopen(fileName, 'wt');
    if fileIdentifier < 0
        error('terra:OutputFile', 'Cannot open %s for writing.', fileName);
    end
    closer = onCleanup(@() fclose(fileIdentifier)); %#ok<NASGU>
    fprintf(fileIdentifier, '%s\n', strjoin(cellfun(@formatCell, header, ...
        'UniformOutput', false), ','));
    for rowIndex = 1:size(rows, 1)
        formatted = cellfun(@formatCell, rows(rowIndex, :), 'UniformOutput', false);
        fprintf(fileIdentifier, '%s\n', strjoin(formatted, ','));
    end
end

function text = formatCell(value)
%FORMATCELL One CSV field.
    formats = terra.outputFormats();
    lineFeed = char(10);
    carriageReturn = char(13);
    if ischar(value)
        text = value;
        needsQuotes = any(text == ',') || any(text == '"') || any(text == lineFeed) || ...
            any(text == carriageReturn);
        if needsQuotes
            text = ['"', strrep(text, '"', '""'), '"'];
        end
    elseif islogical(value) && isscalar(value)
        text = sprintf('%d', value);
    elseif isnumeric(value) && isscalar(value)
        text = sprintf('%.*g', formats.csvDigits, value);
    elseif isempty(value)
        text = '';
    elseif isnumeric(value)
        text = ['"', mat2str(value, formats.csvDigits), '"'];
    else
        error('terra:CsvValue', 'Unsupported CSV value of class %s.', class(value));
    end
end
