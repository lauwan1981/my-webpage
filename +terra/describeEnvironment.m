function environment = describeEnvironment()
%DESCRIBEENVIRONMENT Software and hardware facts for the reproducibility record.
%   environment = terra.describeEnvironment() returns the interpreter and
%   version, the platform string, the processor description and logical
%   processor count, and the time stamp. The processor fields come from
%   the Windows environment variables PROCESSOR_IDENTIFIER and
%   NUMBER_OF_PROCESSORS; on other systems they read "not exposed".

    notExposed = 'not exposed';
    environment.isOctave = exist('OCTAVE_VERSION', 'builtin') ~= 0;
    if environment.isOctave
        environment.interpreter = 'GNU Octave';
    else
        environment.interpreter = 'MATLAB';
    end
    environment.version = version();
    environment.platform = computer();
    environment.processor = getenv('PROCESSOR_IDENTIFIER');
    environment.processorCount = getenv('NUMBER_OF_PROCESSORS');
    if isempty(environment.processor)
        environment.processor = notExposed;
    end
    if isempty(environment.processorCount)
        environment.processorCount = notExposed;
    end
    environment.startedAt = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    environment.toolboxesRequired = 'none (base MATLAB R2015a or later)';
end
