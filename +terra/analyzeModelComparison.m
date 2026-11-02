function comparison = analyzeModelComparison(configuration, operatingPoint, label)
%ANALYZEMODELCOMPARISON Full versus design model at one configuration (Fig. 1).
%   comparison = terra.analyzeModelComparison(configuration,
%   operatingPoint, label) evaluates, with the same controller, scaling
%   W_u and band (manuscript Sections 2.1(3), 3.3, 4.2):
%     f_W(omega) for G_full and G_des on a dense plotting grid,
%     E_res(omega) = f_W,des - f_W,full at the same physical frequency,
%     every detected candidate valley of both models,
%     closed-loop status of both models with the exact delay, and
%     single-mode-pair removal counterfactuals (full minus one mode),
%   which is reported as counterfactual evidence, not as attribution.

    controller = terra.nominalController(configuration);
    scale = configuration.scaling.primaryActuatorScale;

    fullContext = terra.createOperatingContext(configuration, operatingPoint, controller, ...
        'full', scale);
    designContext = terra.createOperatingContext(configuration, operatingPoint, controller, ...
        'design', scale);
    plotFrequencies = terra.buildFrequencyGrid(configuration.search.bandRadiansPerSecond, ...
        configuration.figures.curveGridPointCount, fullContext.plant, configuration);
    fullSpectrum = terra.evaluateDiagnosticSpectrum(fullContext, plotFrequencies);
    designSpectrum = terra.evaluateDiagnosticSpectrum(designContext, plotFrequencies);

    comparison.label = label;
    comparison.operatingPoint = operatingPoint;
    comparison.frequencies = plotFrequencies;
    comparison.fullCurve = fullSpectrum(end, :);
    comparison.designCurve = designSpectrum(end, :);
    comparison.residualDifference = comparison.designCurve - comparison.fullCurve;
    comparison.fullValleys = terra.runAdaptiveDiscovery(fullContext);
    comparison.designValleys = terra.runAdaptiveDiscovery(designContext);
    comparison.fullStability = terra.assessClosedLoopStability(fullContext.plant, controller, ...
        configuration, operatingPoint.delaySeconds);
    comparison.designStability = terra.assessClosedLoopStability(designContext.plant, ...
        controller, configuration, operatingPoint.delaySeconds);
    comparison.modeSelection = fullContext.modeSelection;
    comparison.systemModes = fullContext.spacecraftModel.systemModes;
    comparison.fullMeasurementEnd = terra.evaluateMeasurementEndDiagnostic( ...
        fullContext.plant, controller, configuration, operatingPoint.delaySeconds);

    % One row per removed mode: [removed mode frequency (rad/s), band
    % minimum frequency (rad/s), band minimum value] of the reduced model.
    allIndices = fullContext.modeSelection.allIndices;
    counterfactualColumns = {'removedModeFrequency', 'minimumFrequency', 'minimumValue'};
    counterfactual = zeros(numel(allIndices), numel(counterfactualColumns));
    for position = 1:numel(allIndices)
        retained = setdiff(allIndices, allIndices(position));
        reducedPlant = terra.buildPlantModel(fullContext.spacecraftModel, retained, 'counterfactual');
        reducedValleys = terra.runAdaptiveDiscovery(terra.withPlant(fullContext, reducedPlant));
        counterfactual(position, :) = [comparison.systemModes.naturalFrequencies(position), ...
            reducedValleys.minimumFrequency, reducedValleys.minimumValue];
    end
    comparison.singleModeRemoval = counterfactual;
    comparison.singleModeRemovalColumns = counterfactualColumns;
end
