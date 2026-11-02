function writeMarkdownTable(fileIdentifier, header, rows)
%WRITEMARKDOWNTABLE Append a Markdown table to an open text file.
%   terra.writeMarkdownTable(fileIdentifier, header, rows) writes header
%   (1xC cell) and rows (RxC cell). Numbers are printed with the
%   markdownDigits significant digits of terra.outputFormats; pass
%   pre-formatted text for anything that needs more.

    fprintf(fileIdentifier, '| %s |\n', strjoin(header, ' | '));
    fprintf(fileIdentifier, '|%s\n', repmat(' --- |', 1, numel(header)));
    for rowIndex = 1:size(rows, 1)
        formatted = cellfun(@formatCell, rows(rowIndex, :), 'UniformOutput', false);
        fprintf(fileIdentifier, '| %s |\n', strjoin(formatted, ' | '));
    end
    fprintf(fileIdentifier, '\n');
end

function text = formatCell(value)
%FORMATCELL One Markdown cell.
    formats = terra.outputFormats();
    if ischar(value)
        text = strrep(value, '|', '/');
    elseif islogical(value) && isscalar(value)
        if value
            text = 'yes';
        else
            text = 'no';
        end
    elseif isnumeric(value) && isscalar(value)
        text = sprintf('%.*g', formats.markdownDigits, value);
    elseif isempty(value)
        text = '-';
    else
        text = mat2str(value, formats.markdownDigits);
    end
end
