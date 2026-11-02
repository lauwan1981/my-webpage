function logProgress(configuration, formatString, varargin)
%LOGPROGRESS Time-stamped console progress message.
%   terra.logProgress(configuration, formatString, ...) prints
%   '[HH:MM:SS] message' when configuration.output.consoleProgress is true.

    if configuration.output.consoleProgress
        fprintf('[%s] %s\n', datestr(now, 'HH:MM:SS'), sprintf(formatString, varargin{:}));
    end
end
