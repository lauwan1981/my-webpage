function checks = verifyModelConsistency(configuration)
%VERIFYMODELCONSISTENCY Self-checks that must pass before any study result.
%   checks = terra.verifyModelConsistency(configuration) verifies, at the
%   declared test angles and frequencies, that
%     (a) the complex modal plant reproduces the SDTlib dynamic-mass form
%         G = [inv(M - sum_k l_k' l_k s^2/D_k(s))]_rot / s^2;
%     (b) G_full = G_des + G_res holds exactly (additive truncation);
%     (b') the fast diagnostic kernel equals the loop response with W_u
%         scaling (checked with the alternate, non-identity W_u);
%     (c) the modal loop equals the state-space interconnection loop
%         (independent code paths, also validates feedback signs);
%     (d) the frequency-domain disturbance transfer at zero delay equals
%         C_theta (sI - A_cl)^-1 B_d of the closed state-space loop;
%     (e) the band minimum is periodic in the drive angle with period
%         configuration.paths.angularPeriodDegrees (180 deg here).
%   Any failure raises an error; the numbers are written to the summary.

    tolerance = configuration.model.selfCheckTolerance;
    testFrequencies = configuration.model.selfCheckFrequenciesRadiansPerSecond;
    testAngles = configuration.paths.periodicityCheckAnglesDegrees;
    controller = terra.nominalController(configuration);
    nominalPoint = terra.nominalOperatingPoint(configuration);

    checks.dynamicMassError = 0;
    checks.additivityError = 0;
    checks.kernelError = 0;
    checks.stateSpaceLoopError = 0;
    checks.closedLoopTransferError = 0;
    checks.periodicityError = 0;
    for testAngle = testAngles
        operatingPoint = nominalPoint;
        operatingPoint.panelAngleDegrees = testAngle;
        model = terra.buildSpacecraftModel(configuration, operatingPoint);
        selection = terra.selectDesignModes(model, configuration);
        fullPlant = terra.buildPlantModel(model, selection.allIndices, 'full');
        designPlant = terra.buildPlantModel(model, selection.designIndices, 'design');
        residualPlant = terra.buildPlantModel(model, selection.residualIndices, 'residual');
        % The residual part carries no rigid-body term (it is in G_des).
        residualPlant.rigidResidue = zeros(size(fullPlant.rigidResidue));

        laplaceValues = 1i * testFrequencies;
        fullResponse = terra.evaluatePlantResponse(fullPlant, laplaceValues);
        designResponse = terra.evaluatePlantResponse(designPlant, laplaceValues);
        residualResponse = terra.evaluatePlantResponse(residualPlant, laplaceValues);
        for pointIndex = 1:numel(testFrequencies)
            reference = dynamicMassResponse(model, laplaceValues(pointIndex));
            checks.dynamicMassError = max(checks.dynamicMassError, ...
                relativeDifference(fullResponse(:, :, pointIndex), reference));
            checks.additivityError = max(checks.additivityError, relativeDifference( ...
                designResponse(:, :, pointIndex) + residualResponse(:, :, pointIndex), ...
                fullResponse(:, :, pointIndex)));
        end

        for plantVariant = {fullPlant, designPlant}
            plant = plantVariant{1};
            interconnection = terra.buildInterconnection(plant, controller, configuration);
            modalLoop = terra.evaluateLoopResponse(plant, controller, configuration, ...
                testFrequencies, operatingPoint.delaySeconds);
            stateSpaceLoop = terra.evaluateStateSpaceLoop(interconnection, testFrequencies, ...
                operatingPoint.delaySeconds);
            transfers = terra.evaluateClosedLoopTransfers(plant, controller, configuration, ...
                testFrequencies, 0);
            alternateScale = configuration.scaling.alternateActuatorScale;
            kernelContext = terra.createDiagnosticContext(plant, controller, configuration, ...
                operatingPoint.delaySeconds, alternateScale, 'modal', 'kernel check');
            kernelResponse = terra.evaluateWeightedReturnDifference(kernelContext, testFrequencies);
            referenceResponse = terra.applyActuatorScaling(modalLoop.returnDifference, alternateScale);
            for pointIndex = 1:numel(testFrequencies)
                checks.kernelError = max(checks.kernelError, relativeDifference( ...
                    kernelResponse(:, :, pointIndex), referenceResponse(:, :, pointIndex)));
                checks.stateSpaceLoopError = max(checks.stateSpaceLoopError, relativeDifference( ...
                    stateSpaceLoop(:, :, pointIndex), modalLoop.loopResponse(:, :, pointIndex)));
                laplaceValue = laplaceValues(pointIndex);
                closedLoopTransfer = interconnection.attitudeOutput * ((laplaceValue * ...
                    eye(interconnection.stateCount) - interconnection.zeroDelayClosedLoopMatrix) \ ...
                    interconnection.disturbanceInput);
                checks.closedLoopTransferError = max(checks.closedLoopTransferError, ...
                    relativeDifference(closedLoopTransfer, ...
                    transfers.disturbanceToPointing(:, :, pointIndex)));
            end
        end

        context = terra.createOperatingContext(configuration, operatingPoint, controller, ...
            'full', configuration.scaling.primaryActuatorScale);
        shiftedPoint = operatingPoint;
        shiftedPoint.panelAngleDegrees = testAngle - configuration.paths.angularPeriodDegrees;
        shiftedContext = terra.createOperatingContext(configuration, shiftedPoint, controller, ...
            'full', configuration.scaling.primaryActuatorScale);
        valleys = terra.runAdaptiveDiscovery(context);
        shiftedValleys = terra.runAdaptiveDiscovery(shiftedContext);
        checks.periodicityError = max(checks.periodicityError, ...
            abs(valleys.minimumValue - shiftedValleys.minimumValue));
    end

    nominalModel = terra.buildSpacecraftModel(configuration, nominalPoint);
    checks.modelRigidInertiaDiagonal = diag(nominalModel.rigidInertia);
    checks.controllerReferenceInertia = controller.referenceInertiaKilogramMetersSquared(:);
    checks.systemModeFrequencies = nominalModel.systemModes.naturalFrequencies;
    checks.systemModeDampingRatios = nominalModel.systemModes.dampingRatios;
    checks.modalReconstructionError = nominalModel.systemModes.reconstructionError;
    checks.tolerance = tolerance;

    failures = {};
    if checks.dynamicMassError > tolerance
        failures{end + 1} = 'modal plant differs from the dynamic-mass model';
    end
    if checks.additivityError > tolerance
        failures{end + 1} = 'G_full ~= G_des + G_res';
    end
    if checks.kernelError > tolerance
        failures{end + 1} = 'fast diagnostic kernel differs from the loop response';
    end
    if checks.stateSpaceLoopError > tolerance
        failures{end + 1} = 'state-space loop differs from the modal loop';
    end
    if checks.closedLoopTransferError > tolerance
        failures{end + 1} = 'closed-loop disturbance transfer mismatch';
    end
    if checks.periodicityError > tolerance
        failures{end + 1} = sprintf('band minimum is not %g-degree periodic', ...
            configuration.paths.angularPeriodDegrees);
    end
    checks.passed = isempty(failures);
    if ~checks.passed
        error('terra:SelfCheckFailed', 'Model self-check failed: %s.', strjoin(failures, '; '));
    end
end

function response = dynamicMassResponse(model, laplaceValue)
%DYNAMICMASSRESPONSE SDTlib form: invert the 6x6 dynamic mass at the hub.
    dynamicMass = model.rigidMassAtHub;
    for modeIndex = 1:numel(model.cantileverFrequencies)
        couplingRow = model.modalCoupling(modeIndex, :);
        frequency = model.cantileverFrequencies(modeIndex);
        denominator = laplaceValue ^ 2 + 2 * model.cantileverDampingRatio * frequency * ...
            laplaceValue + frequency ^ 2;
        dynamicMass = dynamicMass - (couplingRow' * couplingRow) * laplaceValue ^ 2 / denominator;
    end
    % Hub coordinates are [translations; rotations], one block per axis.
    hubCoordinateCount = size(model.rigidMassAtHub, 1);
    spatialDimension = hubCoordinateCount / 2;
    inverseMass = dynamicMass \ eye(hubCoordinateCount);
    rotationIndices = spatialDimension + (1:spatialDimension);
    response = inverseMass(rotationIndices, rotationIndices) / laplaceValue ^ 2;
end

function difference = relativeDifference(value, reference)
%RELATIVEDIFFERENCE Frobenius-norm relative difference.
    difference = norm(value - reference, 'fro') / max(norm(reference, 'fro'), realmin);
end
