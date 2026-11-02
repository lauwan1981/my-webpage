function spacecraftModel = buildSpacecraftModel(configuration, operatingPoint)
%BUILDSPACECRAFTMODEL Coupled hub and two cantilevered flexible arrays.
%   spacecraftModel = terra.buildSpacecraftModel(configuration,
%   operatingPoint) assembles the SDTlib-style free-floating spacecraft
%   for the frozen configuration theta given by operatingPoint, and
%   returns its physical second-order matrices and its system-level
%   complex modal expansion (manuscript Section 2.1(2)):
%
%       G(s) = R0 / s^2 + sum_k R_k / (s - lambda_k)   (torque -> attitude)
%
%   Construction
%     1. Rigid 6x6 mass of hub plus both arrays at the hub centre of mass.
%     2. Cantilever modal coupling L (6 modes x 6 hub DOF) transported
%        from each attachment point to the hub centre of mass.
%     3. Free-floating condensation of the hub translations (exact,
%        no forces act on them), leaving [rotation (3); modal (6)].
%     4. Elimination of the rigid rotation gives the flexible subsystem
%        (Mbar, C, K) driven by torque; its first-order form is
%        diagonalised to obtain complex modes and rank-one residues.
%   The cantilever modal damping is non-classical at system level, so
%   complex modes are used as allowed by the manuscript.
%
%   Output fields (SI units)
%     operatingPoint, rigidMassAtHub (6x6), modalCoupling (6x6),
%     cantileverFrequencies (6x1), cantileverDampingRatio,
%     condensedMass/Damping/Stiffness (9x9), condensedTorqueInput (9x3),
%     rigidInertia (3x3), rigidResidue R0 (3x3), flexible (struct),
%     systemModes (struct, sorted by natural frequency).

    structure = configuration.structure;
    unitConstants = terra.units();
    spatialDimension = 3;
    hubDegreesOfFreedom = 2 * spatialDimension;
    translationIndices = 1:spatialDimension;
    panelCount = numel(structure.panelAttachmentPointsMeters);
    modesPerPanel = numel(structure.cantileverModeFrequenciesRadiansPerSecond);
    cantileverModeCount = panelCount * modesPerPanel;

    %% Rigid hub at its centre of mass ------------------------------------
    hubInertia = structure.hubInertiaKilogramMetersSquared;
    for axisIndex = 1:spatialDimension
        hubInertia(axisIndex, axisIndex) = hubInertia(axisIndex, axisIndex) * ...
            operatingPoint.hubInertiaDiagonalScale(axisIndex);
    end
    hubMass = structure.hubMassKilograms * operatingPoint.hubMassScale;
    rigidMassAtHub = blkdiag(hubMass * eye(spatialDimension), hubInertia);

    modeFrequencies = reshape(structure.cantileverModeFrequenciesRadiansPerSecond, [], 1) .* ...
        reshape(operatingPoint.cantileverFrequencyScale, [], 1);
    cantileverFrequencies = repmat(modeFrequencies, panelCount, 1);
    modalCoupling = zeros(cantileverModeCount, hubDegreesOfFreedom);

    %% Arrays: rigid mass and modal participation at the hub --------------
    panelAngleRadians = operatingPoint.panelAngleDegrees * unitConstants.degreesToRadians;
    for panelIndex = 1:panelCount
        rotation = rotationAboutFirstAxis( ...
            structure.panelRotationSigns(panelIndex) * panelAngleRadians);
        panelFrame = structure.panelReferenceFrames{panelIndex} * rotation;
        attachmentPoint = structure.panelAttachmentPointsMeters{panelIndex};
        panelCenter = attachmentPoint + panelFrame * structure.panelCenterOfMassOffsetMeters;

        panelRigidMass = blkdiag(structure.panelMassKilograms * eye(spatialDimension), ...
            panelFrame * structure.panelInertiaAtCenterOfMassKilogramMetersSquared * ...
            panelFrame');
        centerTransport = spatialTransport(panelCenter - structure.hubCenterOfMassMeters);
        rigidMassAtHub = rigidMassAtHub + centerTransport' * panelRigidMass * centerTransport;

        frameTransform = blkdiag(panelFrame, panelFrame);
        attachmentTransport = spatialTransport(attachmentPoint - ...
            structure.hubCenterOfMassMeters);
        for localModeIndex = 1:modesPerPanel
            modeIndex = modesPerPanel * (panelIndex - 1) + localModeIndex;
            participation = structure.modalParticipationFactors(localModeIndex, :);
            modalCoupling(modeIndex, :) = participation * frameTransform' * ...
                attachmentTransport;
        end
    end

    %% Free-floating condensation of hub translations ---------------------
    fullMass = [rigidMassAtHub, modalCoupling'; ...
                modalCoupling, eye(cantileverModeCount)];
    retainedIndices = (translationIndices(end) + 1):size(fullMass, 1);
    condensedMass = fullMass(retainedIndices, retainedIndices) - ...
        fullMass(retainedIndices, translationIndices) * ...
        (fullMass(translationIndices, translationIndices) \ ...
         fullMass(translationIndices, retainedIndices));
    condensedMass = symmetrize(condensedMass);
    requirePositiveDefinite(condensedMass, 'condensed mass matrix');

    cantileverDampingRatio = structure.cantileverModeDampingRatio;
    rotationCount = spatialDimension;
    modalStiffness = diag(cantileverFrequencies .^ 2);
    modalDamping = diag(2 * cantileverDampingRatio * cantileverFrequencies);
    condensedStiffness = blkdiag(zeros(rotationCount), modalStiffness);
    condensedDamping = blkdiag(zeros(rotationCount), modalDamping);
    condensedTorqueInput = [eye(rotationCount); zeros(cantileverModeCount, rotationCount)];

    %% Rigid / flexible separation ----------------------------------------
    rotationBlock = 1:rotationCount;
    modalBlock = rotationCount + (1:cantileverModeCount);
    rigidInertia = symmetrize(condensedMass(rotationBlock, rotationBlock));
    couplingRotationModal = condensedMass(rotationBlock, modalBlock);
    flexibleMass = symmetrize(condensedMass(modalBlock, modalBlock) - ...
        couplingRotationModal' * (rigidInertia \ couplingRotationModal));
    requirePositiveDefinite(flexibleMass, 'flexible-subsystem mass matrix');

    flexible.mass = flexibleMass;
    flexible.damping = modalDamping;
    flexible.stiffness = modalStiffness;
    flexible.torqueInput = -(couplingRotationModal' / rigidInertia);
    flexible.attitudeOutput = -(rigidInertia \ couplingRotationModal);
    flexible.stateMatrix = [zeros(cantileverModeCount), eye(cantileverModeCount); ...
        -(flexibleMass \ modalStiffness), -(flexibleMass \ modalDamping)];
    flexible.inputMatrix = [zeros(cantileverModeCount, rotationCount); ...
        flexibleMass \ flexible.torqueInput];
    flexible.outputMatrix = [flexible.attitudeOutput, ...
        zeros(rotationCount, cantileverModeCount)];

    %% Complex modal expansion ---------------------------------------------
    systemModes = computeComplexModes(flexible, configuration.model);

    spacecraftModel.operatingPoint = operatingPoint;
    spacecraftModel.rigidMassAtHub = symmetrize(rigidMassAtHub);
    spacecraftModel.modalCoupling = modalCoupling;
    spacecraftModel.cantileverFrequencies = cantileverFrequencies;
    spacecraftModel.cantileverDampingRatio = cantileverDampingRatio;
    spacecraftModel.condensedMass = condensedMass;
    spacecraftModel.condensedDamping = condensedDamping;
    spacecraftModel.condensedStiffness = condensedStiffness;
    spacecraftModel.condensedTorqueInput = condensedTorqueInput;
    spacecraftModel.rigidInertia = rigidInertia;
    spacecraftModel.rigidResidue = symmetrize(rigidInertia \ eye(rotationCount));
    spacecraftModel.flexible = flexible;
    spacecraftModel.systemModes = systemModes;
end

function systemModes = computeComplexModes(flexible, modelSettings)
%COMPUTECOMPLEXMODES Eigen-decompose the flexible subsystem.
%   Complex-conjugate pairs are represented by the member with positive
%   imaginary part; the conjugate member's residue is conj(residue).
    [rightVectors, eigenvalueMatrix] = eig(flexible.stateMatrix);
    eigenvalues = diag(eigenvalueMatrix);
    leftVectors = rightVectors \ eye(size(rightVectors));
    stateCount = numel(eigenvalues);

    isRealMode = abs(imag(eigenvalues)) <= ...
        modelSettings.realEigenvalueRelativeTolerance * abs(eigenvalues);
    isRepresentative = isRealMode | imag(eigenvalues) > 0;
    representativeIndices = find(isRepresentative);
    [~, frequencyOrder] = sort(abs(eigenvalues(representativeIndices)));
    representativeIndices = representativeIndices(frequencyOrder);

    modeCount = numel(representativeIndices);
    axisCount = size(flexible.outputMatrix, 1);
    residues = zeros(axisCount, axisCount, modeCount);
    outputDirections = zeros(axisCount, modeCount);
    inputDirections = zeros(modeCount, axisCount);
    dominantCantilever = zeros(modeCount, 1);
    cantileverCount = stateCount / 2;
    for modeIndex = 1:modeCount
        eigenIndex = representativeIndices(modeIndex);
        outputDirection = flexible.outputMatrix * rightVectors(:, eigenIndex);
        inputDirection = leftVectors(eigenIndex, :) * flexible.inputMatrix;
        outputDirections(:, modeIndex) = outputDirection;
        inputDirections(modeIndex, :) = inputDirection;
        residues(:, :, modeIndex) = outputDirection * inputDirection;
        [~, dominantCantilever(modeIndex)] = ...
            max(abs(rightVectors(1:cantileverCount, eigenIndex)));
    end

    representativeEigenvalues = eigenvalues(representativeIndices);
    systemModes.eigenvalues = representativeEigenvalues;
    systemModes.residues = residues;
    systemModes.outputDirections = outputDirections;
    systemModes.inputDirections = inputDirections;
    systemModes.isReal = isRealMode(representativeIndices);
    systemModes.naturalFrequencies = abs(representativeEigenvalues);
    systemModes.dampingRatios = -real(representativeEigenvalues) ./ ...
        abs(representativeEigenvalues);
    systemModes.residueNorms = zeros(modeCount, 1);
    for modeIndex = 1:modeCount
        systemModes.residueNorms(modeIndex) = norm(residues(:, :, modeIndex), 2);
    end
    systemModes.dominantCantileverIndex = dominantCantilever;
    systemModes.eigenvectorCondition = cond(rightVectors);
    systemModes.reconstructionError = modalReconstructionError( ...
        flexible, systemModes, modelSettings.selfCheckFrequenciesRadiansPerSecond);
    if systemModes.reconstructionError > modelSettings.modalReconstructionTolerance
        error('terra:ModalReconstruction', ...
            ['Complex modal sum does not reproduce the flexible resolvent ' ...
             '(relative error %.3g > %.3g); modes may be nearly repeated.'], ...
            systemModes.reconstructionError, modelSettings.modalReconstructionTolerance);
    end
end

function relativeError = modalReconstructionError(flexible, systemModes, testFrequencies)
%MODALRECONSTRUCTIONERROR Compare residue sum with C (sI - A)^-1 B.
    relativeError = 0;
    stateCount = size(flexible.stateMatrix, 1);
    axisCount = size(flexible.outputMatrix, 1);
    for frequency = testFrequencies
        laplaceValue = 1i * frequency;
        resolventResponse = flexible.outputMatrix * ...
            ((laplaceValue * eye(stateCount) - flexible.stateMatrix) \ ...
            flexible.inputMatrix);
        modalResponse = zeros(axisCount);
        for modeIndex = 1:numel(systemModes.eigenvalues)
            residue = systemModes.residues(:, :, modeIndex);
            eigenvalue = systemModes.eigenvalues(modeIndex);
            modalResponse = modalResponse + residue / (laplaceValue - eigenvalue);
            if ~systemModes.isReal(modeIndex)
                modalResponse = modalResponse + conj(residue) / ...
                    (laplaceValue - conj(eigenvalue));
            end
        end
        scale = max(norm(resolventResponse, 'fro'), realmin);
        relativeError = max(relativeError, ...
            norm(modalResponse - resolventResponse, 'fro') / scale);
    end
end

function rotation = rotationAboutFirstAxis(angleRadians)
%ROTATIONABOUTFIRSTAXIS Rotation about the panel span (x) axis.
    rotation = [1, 0, 0; ...
                0, cos(angleRadians), -sin(angleRadians); ...
                0, sin(angleRadians), cos(angleRadians)];
end

function transport = spatialTransport(offsetMeters)
%SPATIALTRANSPORT Twist transport from the hub centre of mass to a point.
%   [v_P; w] = transport * [v_B; w], with v_P = v_B + w x r = v_B - [r x] w,
%   where [r x] is the cross-product (skew-symmetric) matrix of r.
    translationRows = 1:3;
    rotationColumns = 4:6;
    skew = [0, -offsetMeters(3), offsetMeters(2); ...
            offsetMeters(3), 0, -offsetMeters(1); ...
            -offsetMeters(2), offsetMeters(1), 0];
    transport = eye(numel(translationRows) + numel(rotationColumns));
    transport(translationRows, rotationColumns) = -skew;
end

function symmetricMatrix = symmetrize(matrix)
%SYMMETRIZE Remove round-off asymmetry from a symmetric matrix.
    symmetricMatrix = (matrix + matrix') / 2;
end

function requirePositiveDefinite(matrix, description)
%REQUIREPOSITIVEDEFINITE Abort on a physically invalid mass matrix.
    if min(eig(matrix)) <= 0
        error('terra:InvalidMassMatrix', 'The %s is not positive definite.', description);
    end
end
