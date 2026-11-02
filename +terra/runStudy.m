function results = runStudy(runMode, options)
%RUNSTUDY Execute the complete, predeclared study and write all outputs.
%   results = terra.runStudy(runMode) with runMode 'full', 'quick' or
%   'check' (see terra.applyRunMode). Steps, in the manuscript's order:
%     0. configuration validation and model self-checks
%     1. full/design comparison at the nominal and perturbed angle (Fig. 1)
%     2. parameter paths, branch tracking and switch qualification (Fig. 2)
%        for the primary and the alternate actuator scaling
%     3. one-sided derivative validation (smooth region and switches)
%     4. drift-risk derivatives of the physical parameters
%     5. remediation cases with equal-budget screening rules
%     6. equal-error dense baseline per case (Table 2)
%     7. switch-location errors of method and dense baseline (Table 2)
%     8. Table 1 rows, time-domain responses and Figure 3 decision
%     9. tables, figures, report, data and reproducibility manifest
%
%   results = terra.runStudy(runMode, options) with optional fields
%     resumeDirectory    output folder of an interrupted run; the run
%                        continues from its checkpoint file
%     timeBudgetSeconds  stop cleanly at the next checkpoint once this
%                        much wall time has been used in this session
%                        (default Inf)
%   A checkpoint is written after every step and every case, so a long
%   run can be interrupted and resumed without repeating finished work.
%   A run must be resumed with the interpreter, version and platform it
%   was started with (Table 2 compares wall times within one run).
%   results.isComplete tells whether all steps have finished.

    if nargin < 1
        runMode = 'full';
    end
    if nargin < 2
        options = struct();
    end
    options = completeOptions(options);

    if isempty(options.resumeDirectory)
        configuration = terra.applyRunMode(terra.defaultConfiguration(), runMode);
        terra.validateConfiguration(configuration);
        results.configuration = configuration;
        results.environment = terra.describeEnvironment();
        results.resumeCount = 0;
        results.completedSteps = {};
        results.accumulatedSeconds = 0;
        results.sessionSeconds = 0;
        results.lastCheckpointTime = now;
        terra.logProgress(configuration, 'Self-checks of the model and interconnection');
        results.selfChecks = terra.verifyModelConsistency(configuration);
        results.outputDirectory = terra.createOutputDirectory(configuration.output.directoryPrefix);
        if strcmp(runMode, 'check')
            terra.writeStudyOutputs(results);
            terra.writeManifest(fullfile(results.outputDirectory, 'manifest.txt'), results);
            results.isComplete = true;
            terra.logProgress(configuration, 'Self-checks passed; output in %s', ...
                results.outputDirectory);
            return;
        end
    else
        results = loadCheckpoint(options.resumeDirectory);
        configuration = results.configuration;
        if ~strcmp(configuration.metadata.runMode, runMode)
            error('terra:ResumeMismatch', 'Checkpoint was written by a "%s" run, not "%s".', ...
                configuration.metadata.runMode, runMode);
        end
        requireSameEnvironment(results.environment, terra.describeEnvironment());
        results.resumeCount = results.resumeCount + 1;
        terra.logProgress(configuration, 'Resuming %s after: %s', results.outputDirectory, ...
            strjoin(results.completedSteps, ', '));
    end

    steps = {'modelComparison', 'paths', 'derivativeValidation', 'driftRisk', 'cases', ...
        'denseBaseline', 'switchComparison', 'showcase'};
    for stepIndex = 1:numel(steps)
        stepName = steps{stepIndex};
        if any(strcmp(results.completedSteps, stepName))
            continue;
        end
        [results, isStepFinished] = runStep(stepName, configuration, results, options);
        if isStepFinished
            results.completedSteps{end + 1} = stepName;
        end
        results = saveCheckpoint(results);
        isLastStep = stepIndex == numel(steps);
        if ~isStepFinished || (~isLastStep && isOverBudget(results, options))
            results.isComplete = false;
            terra.logProgress(configuration, ['Paused after %.1f s of computation; resume with ' ...
                'run_terra_study(''%s'', struct(''resumeDirectory'', ''%s''))'], ...
                results.accumulatedSeconds, runMode, results.outputDirectory);
            return;
        end
    end

    results = updateClock(results);
    results.elapsedSeconds = results.accumulatedSeconds;
    terra.logProgress(configuration, 'Writing tables, figures and report');
    terra.writeStudyOutputs(results);
    terra.plotStudyFigures(results);
    deleteCheckpoint(results);
    terra.writeManifest(fullfile(results.outputDirectory, 'manifest.txt'), results);
    results.isComplete = true;
    terra.logProgress(configuration, 'Done in %.1f s of computation; output in %s', ...
        results.elapsedSeconds, results.outputDirectory);
end

function [results, isStepFinished] = runStep(stepName, configuration, results, options)
%RUNSTEP Execute one study step; looping steps may stop early on budget.
    isStepFinished = true;
    nominalPoint = terra.nominalOperatingPoint(configuration);
    physicalPoint = nominalPoint;
    physicalPoint.panelAngleDegrees = configuration.cases.showcasePhysicalAngleDegrees;
    switch stepName
        case 'modelComparison'
            terra.logProgress(configuration, 'Step 1: full versus design model');
            results.modelComparison = [ ...
                terra.analyzeModelComparison(configuration, nominalPoint, 'nominal'), ...
                terra.analyzeModelComparison(configuration, physicalPoint, 'physical perturbation')];
        case 'paths'
            terra.logProgress(configuration, 'Step 2: parameter paths and switches');
            results.paths = runPathStudies(configuration);
        case 'derivativeValidation'
            terra.logProgress(configuration, 'Step 3: directional-derivative validation');
            results.derivativeValidation = runDerivativeValidation(configuration, results.paths);
        case 'driftRisk'
            terra.logProgress(configuration, 'Step 4: drift-risk derivatives');
            results.driftRisk = [ ...
                terra.computeDriftRisk(configuration, nominalPoint, 'nominal'), ...
                terra.computeDriftRisk(configuration, physicalPoint, 'physical perturbation')];
        case 'cases'
            terra.logProgress(configuration, 'Step 5: remediation cases');
            [results, isStepFinished] = runCaseLoop(configuration, results, options, ...
                'caseResults', @analyzeCase);
        case 'denseBaseline'
            terra.logProgress(configuration, 'Step 6: equal-error dense baseline');
            [results, isStepFinished] = runCaseLoop(configuration, results, options, ...
                'denseBaseline', @compareCase);
        case 'switchComparison'
            terra.logProgress(configuration, 'Step 7: switch-location errors');
            results.switchComparison = runSwitchComparison(configuration, results.paths, ...
                results.denseBaseline);
        case 'showcase'
            terra.logProgress(configuration, 'Step 8: Table 1 rows and Figure 3 experiments');
            results.showcase = terra.runShowcaseExperiments(configuration, results);
        otherwise
            error('terra:UnknownStep', 'Unknown study step "%s".', stepName);
    end
end

function [results, isFinished] = runCaseLoop(configuration, results, options, ...
        resultField, caseFunction)
%RUNCASELOOP Per-case loop with a checkpoint after every case.
    if ~isfield(results, 'cases')
        results.cases = terra.createCaseDefinitions(configuration);
        results.moves = terra.createMoveCatalogue(configuration);
    end
    progressField = [resultField, 'Completed'];
    if ~isfield(results, progressField)
        results.(progressField) = 0;
    end
    caseCount = numel(results.cases);
    isFinished = false;
    for caseIndex = (results.(progressField) + 1):caseCount
        terra.logProgress(configuration, '  case %d of %d: %s', caseIndex, caseCount, ...
            results.cases(caseIndex).label);
        caseResult = caseFunction(configuration, results, caseIndex);
        if caseIndex == 1
            results.(resultField) = repmat(caseResult, 1, caseCount);
        else
            results.(resultField)(caseIndex) = caseResult;
        end
        results.(progressField) = caseIndex;
        if caseIndex < caseCount
            results = saveCheckpoint(results);
            if isOverBudget(results, options)
                return;
            end
        end
    end
    isFinished = true;
end

function caseResult = analyzeCase(configuration, results, caseIndex)
%ANALYZECASE Remediation analysis of one predeclared case.
    caseResult = terra.analyzeRemediationCase(configuration, results.cases(caseIndex), ...
        results.moves);
end

function comparison = compareCase(configuration, results, caseIndex)
%COMPARECASE Dense-baseline comparison of one predeclared case.
    comparison = terra.compareWithDenseBaseline(configuration, results.cases(caseIndex));
end

function paths = runPathStudies(configuration)
%RUNPATHSTUDIES Angle, delay and residual-mode paths, both scalings.
    pathSettings = configuration.paths;
    definitions = struct( ...
        'pathName', {'panel_angle', 'loop_delay', 'mode3_frequency'}, ...
        'pathValues', {pathSettings.panelAngleDegrees, pathSettings.delaySeconds, ...
            pathSettings.mode3FrequencyRadiansPerSecond}, ...
        'includeAlternate', {true, true, false});
    scales.primary = configuration.scaling.primaryActuatorScale;
    scales.alternate = configuration.scaling.alternateActuatorScale;
    paths = struct();
    for definitionIndex = 1:numel(definitions)
        pathName = definitions(definitionIndex).pathName;
        pathValues = definitions(definitionIndex).pathValues;
        scaleNames = {'primary'};
        if definitions(definitionIndex).includeAlternate
            scaleNames{end + 1} = 'alternate'; %#ok<AGROW>
        end
        for scaleIndex = 1:numel(scaleNames)
            scaleName = scaleNames{scaleIndex};
            terra.logProgress(configuration, '  path %s, %s scaling', pathName, scaleName);
            scan = terra.scanParameterPath(configuration, pathName, pathValues, ...
                scales.(scaleName), struct('checkStability', strcmp(scaleName, 'primary')));
            tracks = terra.trackValleyBranches(scan, configuration);
            switches = terra.locateDominantSwitches(scan, tracks, configuration);
            paths.(pathName).(scaleName).scan = scan;
            paths.(pathName).(scaleName).tracks = tracks;
            paths.(pathName).(scaleName).switches = switches;
        end
    end
end

function validations = runDerivativeValidation(configuration, paths)
%RUNDERIVATIVEVALIDATION Smooth-region and switch-point secant studies.
    derivativeSettings = configuration.derivatives;
    nominalPoint = terra.nominalOperatingPoint(configuration);
    locations(1).label = 'nominal (smooth region)';
    locations(1).operatingPoint = nominalPoint;
    locations(1).parameterNames = [derivativeSettings.smoothRegionControlParameters, ...
        derivativeSettings.smoothRegionPhysicalParameters];
    controller = terra.nominalController(configuration);
    for pathName = {'panel_angle', 'loop_delay'}
        switches = paths.(pathName{1}).primary.switches;
        for switchIndex = 1:numel(switches)
            if ~strcmp(switches(switchIndex).status, 'confirmed_dominant_switch')
                continue;
            end
            location.label = sprintf('%s switch at %.12g', pathName{1}, ...
                switches(switchIndex).parameterValue);
            location.operatingPoint = terra.setParameterValue(configuration, nominalPoint, ...
                controller, pathName{1}, switches(switchIndex).parameterValue);
            parameterNames = derivativeSettings.switchPointParameters;
            parameterNames(strcmp(parameterNames, 'path_parameter')) = pathName;
            location.parameterNames = parameterNames;
            locations(end + 1) = location; %#ok<AGROW>
        end
    end
    for locationIndex = 1:numel(locations)
        terra.logProgress(configuration, '  derivative check at %s', locations(locationIndex).label);
        validation = terra.validateDirectionalDerivatives(configuration, locations(locationIndex));
        if locationIndex == 1
            validations = repmat(validation, 1, numel(locations));
        end
        validations(locationIndex) = validation;
    end
end

function comparisons = runSwitchComparison(configuration, paths, denseBaseline)
%RUNSWITCHCOMPARISON Reference and dense locations of confirmed switches.
%   Every confirmed switch of every path under the primary scaling is
%   compared. The dense baseline bisects with the largest equal-error
%   grid found over all cases (the grid a dense-only study would have to
%   adopt).
    densePointCount = max([denseBaseline.denseGridPointCount]);
    comparisons = struct('pathName', {}, 'methodRoot', {}, 'referenceRoot', {}, ...
        'denseRoot', {}, 'methodError', {}, 'denseError', {}, 'referenceEvaluations', {}, ...
        'denseEvaluations', {}, 'referenceSeconds', {}, 'denseSeconds', {}, ...
        'methodEvaluations', {});
    for pathName = reshape(fieldnames(paths), 1, [])
        switches = paths.(pathName{1}).primary.switches;
        for switchIndex = 1:numel(switches)
            if strcmp(switches(switchIndex).status, 'confirmed_dominant_switch')
                comparisons(end + 1) = terra.compareSwitchLocations(configuration, ...
                    switches(switchIndex), densePointCount); %#ok<AGROW>
            end
        end
    end
end

function options = completeOptions(options)
%COMPLETEOPTIONS Defaults for the optional run controls.
    if ~isfield(options, 'resumeDirectory')
        options.resumeDirectory = '';
    end
    if ~isfield(options, 'timeBudgetSeconds')
        options.timeBudgetSeconds = Inf;
    end
end

function requireSameEnvironment(original, current)
%REQUIRESAMEENVIRONMENT Refuse to mix interpreters or platforms in one run.
%   Table 2 compares wall times measured within one run, so a resumed run
%   must use the same interpreter, version and platform as its start.
    isSame = strcmp(original.interpreter, current.interpreter) && ...
        strcmp(original.version, current.version) && strcmp(original.platform, current.platform);
    if ~isSame
        error('terra:ResumeEnvironmentMismatch', ['The checkpoint was written by %s %s on %s; ' ...
            'resume it there, or start a new run here.'], original.interpreter, ...
            original.version, original.platform);
    end
end

function isOver = isOverBudget(results, options)
%ISOVERBUDGET True once this session has used its wall-time budget.
    isOver = results.sessionSeconds >= options.timeBudgetSeconds;
end

function results = updateClock(results)
%UPDATECLOCK Add the wall time since the last checkpoint to the counters.
    unitConstants = terra.units();
    elapsed = (now - results.lastCheckpointTime) * unitConstants.secondsPerDay;
    results.accumulatedSeconds = results.accumulatedSeconds + elapsed;
    results.sessionSeconds = results.sessionSeconds + elapsed;
    results.lastCheckpointTime = now;
end

function results = saveCheckpoint(results)
%SAVECHECKPOINT Persist the partial results and the time spent so far.
    results = updateClock(results);
    checkpointFile = fullfile(results.outputDirectory, ...
        results.configuration.output.checkpointFileName);
    save(checkpointFile, 'results', '-v7');
end

function results = loadCheckpoint(directory)
%LOADCHECKPOINT Restore an interrupted run; the session clock restarts.
    defaults = terra.defaultConfiguration();
    checkpointFile = fullfile(directory, defaults.output.checkpointFileName);
    if exist(checkpointFile, 'file') ~= 2
        error('terra:MissingCheckpoint', 'No checkpoint found in %s.', directory);
    end
    stored = load(checkpointFile);
    results = stored.results;
    results.outputDirectory = directory;
    results.sessionSeconds = 0;
    results.lastCheckpointTime = now;
end

function deleteCheckpoint(results)
%DELETECHECKPOINT Remove the checkpoint once all outputs are written.
    checkpointFile = fullfile(results.outputDirectory, ...
        results.configuration.output.checkpointFileName);
    if exist(checkpointFile, 'file') == 2
        delete(checkpointFile);
    end
end
