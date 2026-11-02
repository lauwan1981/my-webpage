function catalogue = parameterCatalogue(configuration)
%PARAMETERCATALOGUE Names, units and allowed variation scales h_i.
%   catalogue = terra.parameterCatalogue(configuration) lists every
%   parameter the study differentiates or perturbs, split as in the
%   manuscript (Section 3.2) into
%       physical  p: operating / structural parameters (drift risk)
%       control   q: tunable controller parameters (remediation)
%   Each entry has fields name, unit, group, stepSize (h_i) and
%   description. The step sizes are declared before any result is seen.

    structure = configuration.structure;
    remediation = configuration.remediation;
    physicalStep = configuration.physicalParameters;

    nominalModeFrequencies = structure.cantileverModeFrequenciesRadiansPerSecond;
    hubInertiaDiagonal = diag(structure.hubInertiaKilogramMetersSquared);
    inertiaSpread = structure.hubInertiaDiagonalRelativeUncertainty;
    frequencySpread = structure.modeFrequencyRelativeUncertainty;

    entries = {};
    entries{end + 1} = makeEntry('panel_angle', 'deg', 'physical', ...
        physicalStep.panelAngleStepDegrees, 'solar-array drive angle');
    entries{end + 1} = makeEntry('loop_delay', 's', 'physical', ...
        physicalStep.delayStepSeconds, 'common loop transport delay');
    entries{end + 1} = makeEntry('hub_mass', 'kg', 'physical', ...
        structure.hubMassRelativeUncertainty * structure.hubMassKilograms, ...
        'hub mass');
    axisLabels = {'xx', 'yy', 'zz'};
    for axisIndex = 1:numel(axisLabels)
        entries{end + 1} = makeEntry(['hub_inertia_', axisLabels{axisIndex}], ...
            'kg m^2', 'physical', ...
            inertiaSpread * hubInertiaDiagonal(axisIndex), ...
            ['hub inertia diagonal ', axisLabels{axisIndex}]); %#ok<AGROW>
    end
    for modeIndex = 1:numel(nominalModeFrequencies)
        entries{end + 1} = makeEntry(sprintf('mode%d_frequency', modeIndex), ...
            'rad/s', 'physical', ...
            frequencySpread * nominalModeFrequencies(modeIndex), ...
            sprintf('cantilever mode %d frequency (both arrays)', ...
            modeIndex)); %#ok<AGROW>
    end

    controlAxes = {'x', 'y', 'z'};
    for axisIndex = 1:numel(controlAxes)
        entries{end + 1} = makeEntry(['damping_', controlAxes{axisIndex}], ...
            '-', 'control', remediation.dampingStep, ...
            ['controller damping ratio, axis ', controlAxes{axisIndex}]); %#ok<AGROW>
    end
    for axisIndex = 1:numel(controlAxes)
        entries{end + 1} = makeEntry(['rolloff_', controlAxes{axisIndex}], ...
            'rad/s', 'control', remediation.rolloffStepRadiansPerSecond, ...
            ['controller roll-off frequency, axis ', ...
             controlAxes{axisIndex}]); %#ok<AGROW>
    end

    catalogue = [entries{:}];
end

function entry = makeEntry(name, unit, group, stepSize, description)
%MAKEENTRY Build one catalogue record.
    entry.name = name;
    entry.unit = unit;
    entry.group = group;
    entry.stepSize = stepSize;
    entry.description = description;
end
