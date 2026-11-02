function writeManifest(fileName, results)
%WRITEMANIFEST Reproducibility manifest: environment, configuration, files.
%   terra.writeManifest(fileName, results) records the interpreter,
%   platform and processor, the complete configuration (every field and
%   value, recursively) and the list of files in the output directory
%   (the manifest itself is listed without a size, because it is still
%   being written).

    fileIdentifier = fopen(fileName, 'wt');
    if fileIdentifier < 0
        error('terra:OutputFile', 'Cannot open %s for writing.', fileName);
    end
    closer = onCleanup(@() fclose(fileIdentifier)); %#ok<NASGU>
    environment = results.environment;
    fprintf(fileIdentifier, 'REPRODUCIBILITY MANIFEST\n');
    fprintf(fileIdentifier, 'interpreter: %s %s\nplatform: %s\nprocessor: %s\n', ...
        environment.interpreter, environment.version, environment.platform, environment.processor);
    fprintf(fileIdentifier, 'logical processors: %s\nstarted: %s\nresumed: %d time(s)\n', ...
        environment.processorCount, environment.startedAt, results.resumeCount);
    fprintf(fileIdentifier, 'toolboxes: %s\n\n', environment.toolboxesRequired);
    fprintf(fileIdentifier, 'CONFIGURATION\n');
    dumpStructure(fileIdentifier, 'configuration', results.configuration);
    fprintf(fileIdentifier, '\nFILES\n');
    [~, manifestName, manifestExtension] = fileparts(fileName);
    listFiles(fileIdentifier, results.outputDirectory, '', [manifestName, manifestExtension]);
end

function dumpStructure(fileIdentifier, prefix, value)
%DUMPSTRUCTURE Print every leaf as prefix.field = value.
%   Each line is assembled first and printed with a single '%s', because
%   MATLAB drops empty arguments (such as an empty char value) from a
%   format's value list.
    formats = terra.outputFormats();
    if isstruct(value)
        names = fieldnames(value);
        for nameIndex = 1:numel(names)
            dumpStructure(fileIdentifier, [prefix, '.', names{nameIndex}], value.(names{nameIndex}));
        end
    elseif iscell(value)
        for cellIndex = 1:numel(value)
            dumpStructure(fileIdentifier, sprintf('%s{%d}', prefix, cellIndex), value{cellIndex});
        end
    elseif ischar(value)
        fprintf(fileIdentifier, '%s\n', [prefix, ' = ''', value, '''']);
    elseif isnumeric(value) || islogical(value)
        fprintf(fileIdentifier, '%s\n', [prefix, ' = ', mat2str(value, formats.manifestDigits)]);
    else
        fprintf(fileIdentifier, '%s\n', [prefix, ' = <', class(value), '>']);
    end
end

function listFiles(fileIdentifier, directory, relativePrefix, manifestFileName)
%LISTFILES Recursive file list with sizes in bytes.
    entries = dir(directory);
    for entryIndex = 1:numel(entries)
        name = entries(entryIndex).name;
        if strcmp(name, '.') || strcmp(name, '..')
            continue;
        end
        relativeName = fullfile(relativePrefix, name);
        if entries(entryIndex).isdir
            listFiles(fileIdentifier, fullfile(directory, name), relativeName, manifestFileName);
        elseif isempty(relativePrefix) && strcmp(name, manifestFileName)
            fprintf(fileIdentifier, '%s (this file)\n', relativeName);
        else
            fprintf(fileIdentifier, '%s (%d bytes)\n', relativeName, entries(entryIndex).bytes);
        end
    end
end
