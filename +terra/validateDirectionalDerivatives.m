function validation = validateDirectionalDerivatives(configuration, location)
%VALIDATEDIRECTIONALDERIVATIVES One-sided secant convergence study.
%   validation = terra.validateDirectionalDerivatives(configuration,
%   location) compares, at location.operatingPoint, the predicted
%   one-sided envelope derivatives d+ and d- (manuscript Section 3.2)
%   with one-sided secants (b(p +- h) - b(p)) / h for decreasing h along
%   the same physical direction (Section 4.3). Each secant point re-runs
%   the full-band adaptive discovery. In a smooth region the error must
%   shrink linearly with h; at a switch the two one-sided derivatives
%   differ and each secant must converge to its own side.
%
%   location fields: label, operatingPoint, parameterNames (cell)
%   Output: label, rows (struct array: parameterName, direction, step,
%   predicted, secant, absoluteError), observedOrders, activeCount

    controller = terra.nominalController(configuration);
    scale = configuration.scaling.primaryActuatorScale;
    derivativeSettings = configuration.derivatives;
    baseContext = terra.createOperatingContext(configuration, location.operatingPoint, ...
        controller, 'full', scale);
    baseValleys = terra.runAdaptiveDiscovery(baseContext);
    crossover = terra.findMainCrossover(baseContext, baseValleys);
    unitStep = 1;
    rows = struct('parameterName', {}, 'direction', {}, 'step', {}, 'predicted', {}, ...
        'secant', {}, 'absoluteError', {});
    observedOrders = struct();

    for parameterIndex = 1:numel(location.parameterNames)
        parameterName = location.parameterNames{parameterIndex};
        sensitivity = terra.computeEnvelopeSensitivity(baseContext, baseValleys, ...
            parameterName, unitStep, crossover.valleyIndex);
        nominalValue = terra.getParameterValue(configuration, location.operatingPoint, ...
            controller, parameterName);
        baseStep = derivativeSettings.secantBaseSteps.(parameterName);
        for direction = [1, -1]
            if direction > 0
                predicted = sensitivity.unitDerivativePositive;
            else
                predicted = sensitivity.unitDerivativeNegative;
            end
            errors = zeros(1, numel(derivativeSettings.secantStepFractions));
            steps = baseStep * derivativeSettings.secantStepFractions;
            for stepIndex = 1:numel(steps)
                step = steps(stepIndex);
                [operatingPoint, movedController] = terra.setParameterValue(configuration, ...
                    location.operatingPoint, controller, parameterName, ...
                    nominalValue + direction * step);
                movedContext = terra.createOperatingContext(configuration, operatingPoint, ...
                    movedController, 'full', scale);
                movedValleys = terra.runAdaptiveDiscovery(movedContext);
                secant = (movedValleys.minimumValue - baseValleys.minimumValue) / step;
                row.parameterName = parameterName;
                row.direction = direction;
                row.step = step;
                row.predicted = predicted;
                row.secant = secant;
                row.absoluteError = abs(secant - predicted);
                rows(end + 1) = row; %#ok<AGROW>
                errors(stepIndex) = row.absoluteError;
            end
            orderField = sprintf('%s_%s', parameterName, directionName(direction));
            observedOrders.(orderField) = log(errors(end - 1) / errors(end)) / ...
                log(steps(end - 1) / steps(end));
        end
    end
    validation.label = location.label;
    validation.operatingPoint = location.operatingPoint;
    validation.baseValue = baseValleys.minimumValue;
    validation.activeCount = numel(baseValleys.activeIndices);
    validation.activeFrequencies = baseValleys.frequencies(baseValleys.activeIndices);
    validation.rows = rows;
    validation.observedOrders = observedOrders;
end

function name = directionName(direction)
%DIRECTIONNAME 'plus' or 'minus' for field names.
    if direction > 0
        name = 'plus';
    else
        name = 'minus';
    end
end
