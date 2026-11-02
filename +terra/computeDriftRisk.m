function driftRisk = computeDriftRisk(configuration, operatingPoint, label)
%COMPUTEDRIFTRISK Directed drift-risk table for the physical parameters p.
%   driftRisk = terra.computeDriftRisk(configuration, operatingPoint,
%   label) evaluates, for every physical parameter of
%   terra.parameterCatalogue with its declared variation scale h
%   (manuscript Section 3.2):
%       d+-  unit one-sided envelope derivatives (near-active set)
%       D+-  = h d+-   first-order margin change for a step of size h
%       R+-  = max(0, -D+-)   first-order degradation
%   and verifies each first-order estimate by a finite step (full rebuild
%   and full-band re-search at p +- h). It records whether the finite step
%   moves the band minimum to another valley (bottleneck migration: the
%   base valley nearest in log frequency to the new band minimum is not
%   the base band minimum), in which case the local linear interpretation
%   does not apply.
%
%   Output: label, operatingPoint, baseValue, baseFrequency,
%   rows (struct array)

    controller = terra.nominalController(configuration);
    scale = configuration.scaling.primaryActuatorScale;
    catalogue = terra.parameterCatalogue(configuration);
    physicalEntries = catalogue(strcmp({catalogue.group}, 'physical'));

    baseContext = terra.createOperatingContext(configuration, operatingPoint, controller, ...
        'full', scale);
    baseValleys = terra.runAdaptiveDiscovery(baseContext);
    crossover = terra.findMainCrossover(baseContext, baseValleys);
    rows = struct('parameterName', {}, 'unit', {}, 'stepSize', {}, ...
        'unitDerivativePositive', {}, 'unitDerivativeNegative', {}, ...
        'changePositive', {}, 'changeNegative', {}, 'degradationPositive', {}, ...
        'degradationNegative', {}, 'branchAwarePositive', {}, 'branchAwareNegative', {}, ...
        'actualChangePositive', {}, 'actualChangeNegative', {}, ...
        'migratesPositive', {}, 'migratesNegative', {});

    for entryIndex = 1:numel(physicalEntries)
        entry = physicalEntries(entryIndex);
        sensitivity = terra.computeEnvelopeSensitivity(baseContext, baseValleys, ...
            entry.name, entry.stepSize, crossover.valleyIndex);
        nominalValue = terra.getParameterValue(configuration, operatingPoint, controller, ...
            entry.name);
        directions = [1, -1];
        actualChange = zeros(1, numel(directions));
        migrates = false(1, numel(directions));
        % Valleys are sorted by value, so position 1 is the band minimum.
        bandMinimumPosition = 1;
        for directionIndex = 1:numel(directions)
            movedPoint = terra.setParameterValue(configuration, operatingPoint, controller, ...
                entry.name, nominalValue + directions(directionIndex) * entry.stepSize);
            movedValleys = terra.runAdaptiveDiscovery(terra.createOperatingContext( ...
                configuration, movedPoint, controller, 'full', scale));
            actualChange(directionIndex) = movedValleys.minimumValue - baseValleys.minimumValue;
            [~, nearestBaseValley] = min(abs(log(baseValleys.frequencies / ...
                movedValleys.minimumFrequency)));
            migrates(directionIndex) = nearestBaseValley ~= bandMinimumPosition;
        end
        row.parameterName = entry.name;
        row.unit = entry.unit;
        row.stepSize = entry.stepSize;
        row.unitDerivativePositive = sensitivity.unitDerivativePositive;
        row.unitDerivativeNegative = sensitivity.unitDerivativeNegative;
        row.changePositive = sensitivity.changePositive;
        row.changeNegative = sensitivity.changeNegative;
        row.degradationPositive = sensitivity.degradationPositive;
        row.degradationNegative = sensitivity.degradationNegative;
        row.branchAwarePositive = sensitivity.predictions.branch_aware.positive - ...
            baseValleys.minimumValue;
        row.branchAwareNegative = sensitivity.predictions.branch_aware.negative - ...
            baseValleys.minimumValue;
        row.actualChangePositive = actualChange(1);
        row.actualChangeNegative = actualChange(2);
        row.migratesPositive = migrates(1);
        row.migratesNegative = migrates(2);
        rows(end + 1) = row; %#ok<AGROW>
    end
    driftRisk.label = label;
    driftRisk.operatingPoint = operatingPoint;
    driftRisk.baseValue = baseValleys.minimumValue;
    driftRisk.baseFrequency = baseValleys.minimumFrequency;
    driftRisk.rows = rows;
end
