function exportModelData(fileName, configuration)
%EXPORTMODELDATA Save raw state-space matrices and port definitions.
%   terra.exportModelData(fileName, configuration) stores, for the nominal
%   configuration, the full and design plants (A, B, C_attitude, C_rate,
%   D_rate), the complex modal data, the condensed mass/damping/stiffness
%   matrices and the full delay-free interconnection with named inputs,
%   outputs and states (manuscript Section 4.3 reproduction material).

    controller = terra.nominalController(configuration);
    operatingPoint = terra.nominalOperatingPoint(configuration);
    model = terra.buildSpacecraftModel(configuration, operatingPoint);
    selection = terra.selectDesignModes(model, configuration);
    plantVariants = {'full', selection.allIndices; 'design', selection.designIndices};
    export = struct();
    export.description = ['Nominal configuration. Inputs: v = delayed command (N m), ' ...
        'd = body disturbance torque (N m), n_star (rad), n_gyro (rad/s). Outputs: ' ...
        'u = command (N m), attitude (rad), rate (rad/s), wheel torque (N m). ' ...
        'Loop closure: v(t) = u(t - tau), tau = delaySeconds.'];
    export.delaySeconds = operatingPoint.delaySeconds;
    export.operatingPoint = operatingPoint;
    export.condensedMass = model.condensedMass;
    export.condensedDamping = model.condensedDamping;
    export.condensedStiffness = model.condensedStiffness;
    export.condensedTorqueInput = model.condensedTorqueInput;
    export.condensedCoordinates = sprintf(['rotation x y z (rad), cantilever modal ' ...
        'coordinates 1..%d (all modes of all arrays)'], numel(model.cantileverFrequencies));
    export.rigidMassAtHub = model.rigidMassAtHub;
    export.modalCoupling = model.modalCoupling;
    export.systemModeEigenvalues = model.systemModes.eigenvalues;
    export.systemModeResidues = model.systemModes.residues;
    export.rigidResidue = model.rigidResidue;
    export.truncationRule = selection.ruleDescription;
    for variantIndex = 1:size(plantVariants, 1)
        variantName = plantVariants{variantIndex, 1};
        plant = terra.buildPlantModel(model, plantVariants{variantIndex, 2}, variantName);
        interconnection = terra.buildInterconnection(plant, controller, configuration);
        export.(variantName).plant.A = plant.stateMatrix;
        export.(variantName).plant.B = plant.inputMatrix;
        export.(variantName).plant.C_attitude = plant.attitudeOutputMatrix;
        export.(variantName).plant.C_rate = plant.rateOutputMatrix;
        export.(variantName).plant.D_rate = plant.rateFeedthrough;
        export.(variantName).plant.stateDescription = plant.stateDescription;
        export.(variantName).interconnection.A = interconnection.stateMatrix;
        export.(variantName).interconnection.B_delayedCommand = interconnection.delayedCommandInput;
        export.(variantName).interconnection.B_disturbance = interconnection.disturbanceInput;
        export.(variantName).interconnection.B_starNoise = interconnection.starNoiseInput;
        export.(variantName).interconnection.B_gyroNoise = interconnection.gyroNoiseInput;
        export.(variantName).interconnection.C_command = interconnection.commandOutput;
        export.(variantName).interconnection.C_attitude = interconnection.attitudeOutput;
        export.(variantName).interconnection.C_rate = interconnection.rateOutput;
        export.(variantName).interconnection.D_rateDisturbance = ...
            interconnection.rateDisturbanceFeedthrough;
        export.(variantName).interconnection.C_wheelTorque = interconnection.wheelTorqueOutput;
        export.(variantName).interconnection.stateNames = interconnection.stateNames;
    end
    save(fileName, 'export', '-v7');
end
