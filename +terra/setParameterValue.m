function [operatingPoint, controller] = setParameterValue(configuration, ...
        operatingPoint, controller, parameterName, value)
%SETPARAMETERVALUE Return copies with one named parameter replaced.
%   [operatingPoint, controller] = terra.setParameterValue(configuration,
%   operatingPoint, controller, parameterName, value) sets the parameter
%   to value (physical unit, see terra.getParameterValue). Physical
%   parameters change the operating point; control parameters change the
%   controller. Checks: loop_delay must be >= 0; masses, inertias, mode
%   frequencies, damping ratios and roll-off frequencies must be > 0;
%   panel_angle accepts any value (the model is periodic in it).

    structure = configuration.structure;
    switch parameterName
        case 'panel_angle'
            operatingPoint.panelAngleDegrees = value;
        case 'loop_delay'
            requirePositiveOrZero(value, parameterName);
            operatingPoint.delaySeconds = value;
        case 'hub_mass'
            requirePositive(value, parameterName);
            operatingPoint.hubMassScale = value / structure.hubMassKilograms;
        case {'hub_inertia_xx', 'hub_inertia_yy', 'hub_inertia_zz'}
            requirePositive(value, parameterName);
            axisIndex = find(strcmp(parameterName, ...
                {'hub_inertia_xx', 'hub_inertia_yy', 'hub_inertia_zz'}));
            nominalDiagonal = diag(structure.hubInertiaKilogramMetersSquared);
            operatingPoint.hubInertiaDiagonalScale(axisIndex) = ...
                value / nominalDiagonal(axisIndex);
        case {'mode1_frequency', 'mode2_frequency', 'mode3_frequency'}
            requirePositive(value, parameterName);
            modeIndex = find(strcmp(parameterName, ...
                {'mode1_frequency', 'mode2_frequency', 'mode3_frequency'}));
            operatingPoint.cantileverFrequencyScale(modeIndex) = value / ...
                structure.cantileverModeFrequenciesRadiansPerSecond(modeIndex);
        case {'damping_x', 'damping_y', 'damping_z'}
            requirePositive(value, parameterName);
            axisIndex = find(strcmp(parameterName, ...
                {'damping_x', 'damping_y', 'damping_z'}));
            controller.dampingRatio(axisIndex) = value;
        case {'rolloff_x', 'rolloff_y', 'rolloff_z'}
            requirePositive(value, parameterName);
            axisIndex = find(strcmp(parameterName, ...
                {'rolloff_x', 'rolloff_y', 'rolloff_z'}));
            controller.rolloffFrequencyRadiansPerSecond(axisIndex) = value;
        otherwise
            error('terra:UnknownParameter', 'Unknown parameter "%s".', parameterName);
    end
end

function requirePositive(value, parameterName)
%REQUIREPOSITIVE Reject non-positive physical values.
    if ~(isfinite(value) && value > 0)
        error('terra:InvalidParameterValue', ...
            'Parameter "%s" must be positive (got %g).', parameterName, value);
    end
end

function requirePositiveOrZero(value, parameterName)
%REQUIREPOSITIVEORZERO Reject negative or non-finite values.
    if ~(isfinite(value) && value >= 0)
        error('terra:InvalidParameterValue', ...
            'Parameter "%s" must be non-negative (got %g).', parameterName, value);
    end
end
