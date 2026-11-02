function plant = buildPlantModel(spacecraftModel, retainedModeIndices, label)
%BUILDPLANTMODEL Plant G (torque -> attitude) for a subset of system modes.
%   plant = terra.buildPlantModel(spacecraftModel, retainedModeIndices,
%   label) returns the modal plant used for frequency responses and its
%   real state-space realization (manuscript Section 2.1(2)):
%
%       x_p' = A x_p + B tau,   attitude = C_att x_p,
%       rate = C_rate x_p + D_rate tau
%
%   where tau is the total body torque (wheel torque plus disturbance).
%   retainedModeIndices selects system modes (see terra.selectDesignModes);
%   the full model uses every index, the design model uses M_des.
%
%   Output fields
%       label, retainedModeIndices, rigidResidue (R0), eigenvalues,
%       residues, isReal, naturalFrequencies, dampingRatios,
%       stateMatrix, inputMatrix, attitudeOutputMatrix, rateOutputMatrix,
%       rateFeedthrough, stateCount, stateDescription

    modes = spacecraftModel.systemModes;
    retainedModeIndices = reshape(retainedModeIndices, [], 1);
    axisCount = 3;

    plant.label = label;
    plant.retainedModeIndices = retainedModeIndices;
    plant.rigidResidue = spacecraftModel.rigidResidue;
    plant.eigenvalues = modes.eigenvalues(retainedModeIndices);
    plant.residues = modes.residues(:, :, retainedModeIndices);
    plant.isReal = modes.isReal(retainedModeIndices);
    plant.naturalFrequencies = modes.naturalFrequencies(retainedModeIndices);
    plant.dampingRatios = modes.dampingRatios(retainedModeIndices);

    %% Rigid body: attitude and rate states --------------------------------
    rigidStateMatrix = [zeros(axisCount), eye(axisCount); zeros(axisCount, 2 * axisCount)];
    rigidInputMatrix = [zeros(axisCount); spacecraftModel.rigidResidue];
    rigidAttitudeOutput = [eye(axisCount), zeros(axisCount)];
    rigidRateOutput = [zeros(axisCount), eye(axisCount)];

    %% Flexible modes in real block-modal form ----------------------------
    blockMatrices = {};
    blockInputs = {};
    blockAttitudeOutputs = {};
    blockRateOutputs = {};
    rateFeedthrough = zeros(axisCount);
    for position = 1:numel(retainedModeIndices)
        modeIndex = retainedModeIndices(position);
        eigenvalue = modes.eigenvalues(modeIndex);
        outputDirection = modes.outputDirections(:, modeIndex);
        inputDirection = modes.inputDirections(modeIndex, :);
        if modes.isReal(modeIndex)
            blockMatrices{end + 1} = real(eigenvalue); %#ok<AGROW>
            blockInputs{end + 1} = real(inputDirection); %#ok<AGROW>
            blockAttitudeOutputs{end + 1} = real(outputDirection); %#ok<AGROW>
            blockRateOutputs{end + 1} = real(outputDirection * eigenvalue); %#ok<AGROW>
            rateFeedthrough = rateFeedthrough + real(outputDirection * inputDirection);
        else
            decayRate = real(eigenvalue);
            dampedFrequency = imag(eigenvalue);
            blockMatrices{end + 1} = [decayRate, -dampedFrequency; ...
                                      dampedFrequency, decayRate]; %#ok<AGROW>
            blockInputs{end + 1} = [real(inputDirection); imag(inputDirection)]; %#ok<AGROW>
            blockAttitudeOutputs{end + 1} = 2 * [real(outputDirection), ...
                -imag(outputDirection)]; %#ok<AGROW>
            rateDirection = outputDirection * eigenvalue;
            blockRateOutputs{end + 1} = 2 * [real(rateDirection), ...
                -imag(rateDirection)]; %#ok<AGROW>
            rateFeedthrough = rateFeedthrough + ...
                2 * real(outputDirection * inputDirection);
        end
    end

    if isempty(blockMatrices)
        flexibleStateMatrix = zeros(0);
        flexibleInputMatrix = zeros(0, axisCount);
        flexibleAttitudeOutput = zeros(axisCount, 0);
        flexibleRateOutput = zeros(axisCount, 0);
    else
        flexibleStateMatrix = blkdiag(blockMatrices{:});
        flexibleInputMatrix = vertcat(blockInputs{:});
        flexibleAttitudeOutput = horzcat(blockAttitudeOutputs{:});
        flexibleRateOutput = horzcat(blockRateOutputs{:});
    end

    plant.stateMatrix = blkdiag(rigidStateMatrix, flexibleStateMatrix);
    plant.inputMatrix = [rigidInputMatrix; flexibleInputMatrix];
    plant.attitudeOutputMatrix = [rigidAttitudeOutput, flexibleAttitudeOutput];
    plant.rateOutputMatrix = [rigidRateOutput, flexibleRateOutput];
    plant.rateFeedthrough = rateFeedthrough;
    plant.stateCount = size(plant.stateMatrix, 1);
    plant.stateDescription = sprintf(['%d rigid-body states (attitude, rate) ' ...
        'and %d flexible states in real block-modal coordinates'], ...
        2 * axisCount, size(flexibleStateMatrix, 1));
end
