function ensureDirectory(directory)
%ENSUREDIRECTORY Create a folder if it does not exist; fail loudly otherwise.
%   terra.ensureDirectory(directory) creates directory (and missing
%   parents) and raises terra:OutputDirectory if that is not possible.

    folderExistCode = 7;
    if exist(directory, 'dir') == folderExistCode
        return;
    end
    [isCreated, message] = mkdir(directory);
    if ~isCreated
        error('terra:OutputDirectory', 'Cannot create %s: %s', directory, message);
    end
end
