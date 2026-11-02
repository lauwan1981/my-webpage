function context = createOperatingContext(configuration, operatingPoint, controller, ...
        modeSet, actuatorScale)
%CREATEOPERATINGCONTEXT Model, plant and diagnostic context for one theta.
%   context = terra.createOperatingContext(configuration, operatingPoint,
%   controller, modeSet, actuatorScale) builds the spacecraft for the
%   frozen configuration operatingPoint, applies the predeclared
%   truncation rule, and returns a modal diagnostic context (see
%   terra.createDiagnosticContext) with extra fields
%       operatingPoint, modeSet ('full' or 'design'), spacecraftModel,
%       modeSelection, frequencyGrid (initial grid of the adaptive method)
%   so that physical-parameter derivatives can rebuild the model.

    spacecraftModel = terra.buildSpacecraftModel(configuration, operatingPoint);
    modeSelection = terra.selectDesignModes(spacecraftModel, configuration);
    switch modeSet
        case 'full'
            retainedIndices = modeSelection.allIndices;
        case 'design'
            retainedIndices = modeSelection.designIndices;
        otherwise
            error('terra:UnknownModeSet', 'Mode set must be "full" or "design".');
    end
    plant = terra.buildPlantModel(spacecraftModel, retainedIndices, modeSet);
    context = terra.createDiagnosticContext(plant, controller, configuration, ...
        operatingPoint.delaySeconds, actuatorScale, 'modal', modeSet);
    context.operatingPoint = operatingPoint;
    context.modeSet = modeSet;
    context.spacecraftModel = spacecraftModel;
    context.modeSelection = modeSelection;
    context.frequencyGrid = terra.buildFrequencyGrid( ...
        configuration.search.bandRadiansPerSecond, ...
        configuration.search.initialGridPointCount, plant, configuration);
end
