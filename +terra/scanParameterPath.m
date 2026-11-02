function scan = scanParameterPath(configuration, pathName, pathValues, actuatorScale, options)
%SCANPARAMETERPATH Full-band valley search and stability along one path.
%   scan = terra.scanParameterPath(configuration, pathName, pathValues,
%   actuatorScale, options) moves one physical parameter (pathName, a
%   name from terra.parameterCatalogue) through pathValues, keeps all
%   others nominal, and at every point
%     - rebuilds the full model (frozen configuration),
%     - re-searches the whole band (no warm start, Section 3.3),
%     - if options.checkStability, checks closed-loop stability with the
%       exact delay (zero-delay eigenvalues and common-delay margin).
%
%   Output fields
%       pathName, pathValues, actuatorScale, valleys (cell), minimumValues,
%       minimumFrequencies, systemModeFrequencies (P x modes),
%       stabilityStatus (cell), delayMarginSeconds, evaluationCount,
%       elapsedSeconds

    if nargin < 5
        options = struct();
    end
    if ~isfield(options, 'checkStability')
        options.checkStability = true;
    end
    pathTimer = tic;
    controller = terra.nominalController(configuration);
    nominalPoint = terra.nominalOperatingPoint(configuration);
    pointCount = numel(pathValues);

    scan.pathName = pathName;
    scan.pathValues = reshape(pathValues, 1, []);
    scan.actuatorScale = reshape(actuatorScale, [], 1);
    scan.valleys = cell(1, pointCount);
    scan.minimumValues = zeros(1, pointCount);
    scan.minimumFrequencies = zeros(1, pointCount);
    scan.stabilityStatus = cell(1, pointCount);
    scan.delayMarginSeconds = nan(1, pointCount);
    scan.evaluationCount = 0;
    for pointIndex = 1:pointCount
        operatingPoint = terra.setParameterValue(configuration, nominalPoint, controller, ...
            pathName, pathValues(pointIndex));
        context = terra.createOperatingContext(configuration, operatingPoint, controller, ...
            'full', actuatorScale);
        valleys = terra.runAdaptiveDiscovery(context);
        scan.valleys{pointIndex} = valleys;
        scan.minimumValues(pointIndex) = valleys.minimumValue;
        scan.minimumFrequencies(pointIndex) = valleys.minimumFrequency;
        scan.evaluationCount = scan.evaluationCount + valleys.evaluationCount;
        modeFrequencies = context.spacecraftModel.systemModes.naturalFrequencies';
        if pointIndex == 1
            scan.systemModeFrequencies = nan(pointCount, numel(modeFrequencies));
        end
        scan.systemModeFrequencies(pointIndex, 1:numel(modeFrequencies)) = modeFrequencies;
        if options.checkStability
            stability = terra.assessClosedLoopStability(context.plant, controller, ...
                configuration, operatingPoint.delaySeconds, struct('computeRoots', false));
            scan.stabilityStatus{pointIndex} = stability.status;
            scan.delayMarginSeconds(pointIndex) = stability.delayMarginSeconds;
        else
            scan.stabilityStatus{pointIndex} = 'not_checked';
        end
    end
    scan.elapsedSeconds = toc(pathTimer);
end
