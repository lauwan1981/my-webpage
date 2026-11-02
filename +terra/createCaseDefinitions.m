function cases = createCaseDefinitions(configuration)
%CREATECASEDEFINITIONS Predeclared case families (manuscript Section 4.1).
%   cases = terra.createCaseDefinitions(configuration) returns a struct
%   array with fields label, family and operatingPoint for
%     angle       drive angles at the nominal delay (physical perturbation)
%     delay       loop delays at the nominal angle (delay perturbation)
%     structural  out-of-sample corners of the source's 20 % ranges:
%                 third cantilever mode frequency x0.8 / x1.2 and hub
%                 inertia diagonal x0.8, each at 0 and 90 degrees
%   The list is fixed before any result is computed.

    unitConstants = terra.units();
    caseSettings = configuration.cases;
    nominalPoint = terra.nominalOperatingPoint(configuration);
    axisCount = numel(nominalPoint.hubInertiaDiagonalScale);
    % The structural family perturbs the third cantilever mode (the mode
    % whose coupled pair forms the residual dynamics of the design model).
    perturbedCantileverMode = 3;
    cases = repmat(struct('label', '', 'family', '', 'operatingPoint', nominalPoint), 1, 0);

    for caseAngle = caseSettings.angleFamilyAnglesDegrees
        operatingPoint = nominalPoint;
        operatingPoint.panelAngleDegrees = caseAngle;
        cases(end + 1) = makeCase(sprintf('angle %g deg', caseAngle), 'angle', ...
            operatingPoint); %#ok<AGROW>
    end
    for delay = caseSettings.delayFamilyDelaysSeconds
        operatingPoint = nominalPoint;
        operatingPoint.delaySeconds = delay;
        cases(end + 1) = makeCase(sprintf('delay %g ms', ...
            delay * unitConstants.secondsToMilliseconds), 'delay', operatingPoint); %#ok<AGROW>
    end
    for caseAngle = caseSettings.structuralFamilyAnglesDegrees
        for modeScale = caseSettings.structuralFamilyMode3Scales
            operatingPoint = nominalPoint;
            operatingPoint.panelAngleDegrees = caseAngle;
            operatingPoint.cantileverFrequencyScale(perturbedCantileverMode) = modeScale;
            cases(end + 1) = makeCase(sprintf('mode%d x%.2f, %g deg', perturbedCantileverMode, ...
                modeScale, caseAngle), 'structural', operatingPoint); %#ok<AGROW>
        end
        operatingPoint = nominalPoint;
        operatingPoint.panelAngleDegrees = caseAngle;
        operatingPoint.hubInertiaDiagonalScale = caseSettings.structuralFamilyHubInertiaScale * ...
            ones(axisCount, 1);
        cases(end + 1) = makeCase(sprintf('hub inertia x%.2f, %g deg', ...
            caseSettings.structuralFamilyHubInertiaScale, caseAngle), 'structural', ...
            operatingPoint); %#ok<AGROW>
    end
end

function caseDefinition = makeCase(label, family, operatingPoint)
%MAKECASE One case record.
    caseDefinition.label = label;
    caseDefinition.family = family;
    caseDefinition.operatingPoint = operatingPoint;
end
