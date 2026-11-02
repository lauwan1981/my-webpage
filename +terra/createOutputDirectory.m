function outputDirectory = createOutputDirectory(directoryPrefix)
%CREATEOUTPUTDIRECTORY New time-stamped output folder; never overwrites.
%   outputDirectory = terra.createOutputDirectory(directoryPrefix) creates
%   <pwd>/<prefix>_<yyyymmdd_HHMMSS>[_n] and returns its path.

    folderExistCode = 7;
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    baseDirectory = fullfile(pwd, [directoryPrefix, '_', timestamp]);
    outputDirectory = baseDirectory;
    suffix = 0;
    while exist(outputDirectory, 'dir') == folderExistCode
        suffix = suffix + 1;
        outputDirectory = sprintf('%s_%d', baseDirectory, suffix);
    end
    terra.ensureDirectory(outputDirectory);
end
