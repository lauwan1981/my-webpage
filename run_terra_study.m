function results = run_terra_study(runMode, options)
%RUN_TERRA_STUDY Entry point of the Terra active-valley margin study (v4).
%   results = run_terra_study()          full, publication-grade run
%   results = run_terra_study('quick')   smoke test on reduced grids
%   results = run_terra_study('check')   model self-checks only
%   results = run_terra_study(mode, options) with optional fields
%       resumeDirectory    continue an interrupted run from its folder
%       timeBudgetSeconds  pause cleanly at the next checkpoint after
%                          this much wall time (resume later)
%
%   Requirements: MATLAB R2015a or later, base MATLAB only (no toolbox).
%   The same code runs on GNU Octave (the archived results in
%   results_octave_full were produced with GNU Octave 10.3.0).
%   Outputs are written to a new time-stamped folder in the current
%   directory (see README.md for the file list and the mapping between
%   manuscript sections, functions and output files).

    if nargin < 1
        runMode = 'full';
    end
    if nargin < 2
        options = struct();
    end
    addpath(fileparts(mfilename('fullpath')));
    results = terra.runStudy(runMode, options);
end
