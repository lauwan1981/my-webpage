function value = getParameterValue(configuration, operatingPoint, controller, parameterName)
%GETPARAMETERVALUE Current physical value of a named parameter.
%   value = terra.getParameterValue(configuration, operatingPoint,
%   controller, parameterName) returns the parameter in its physical
%   unit (deg, s, kg, kg m^2, rad/s or dimensionless), using the names
%   listed by terra.parameterCatalogue.

    structure = configuration.structure;
    switch parameterName
        case 'panel_angle'
            value = operatingPoint.panelAngleDegrees;
        case 'loop_delay'
            value = operatingPoint.delaySeconds;
        case 'hub_mass'
            value = structure.hubMassKilograms * operatingPoint.hubMassScale;
        case {'hub_inertia_xx', 'hub_inertia_yy', 'hub_inertia_zz'}
            axisIndex = inertiaAxisIndex(parameterName);
            nominalDiagonal = diag(structure.hubInertiaKilogramMetersSquared);
            value = nominalDiagonal(axisIndex) * ...
                operatingPoint.hubInertiaDiagonalScale(axisIndex);
        case {'mode1_frequency', 'mode2_frequency', 'mode3_frequency'}
            modeIndex = modeNumber(parameterName);
            value = structure.cantileverModeFrequenciesRadiansPerSecond(modeIndex) * ...
                operatingPoint.cantileverFrequencyScale(modeIndex);
        case {'damping_x', 'damping_y', 'damping_z'}
            value = controller.dampingRatio(controlAxisIndex(parameterName));
        case {'rolloff_x', 'rolloff_y', 'rolloff_z'}
            value = controller.rolloffFrequencyRadiansPerSecond( ...
                controlAxisIndex(parameterName));
        otherwise
            error('terra:UnknownParameter', 'Unknown parameter "%s".', parameterName);
    end
end

function axisIndex = inertiaAxisIndex(parameterName)
%INERTIAAXISINDEX Map hub_inertia_xx/yy/zz to 1/2/3.
    axisIndex = find(strcmp(parameterName, ...
        {'hub_inertia_xx', 'hub_inertia_yy', 'hub_inertia_zz'}));
end

function modeIndex = modeNumber(parameterName)
%MODENUMBER Map modeK_frequency to K.
    modeIndex = find(strcmp(parameterName, ...
        {'mode1_frequency', 'mode2_frequency', 'mode3_frequency'}));
end

function axisIndex = controlAxisIndex(parameterName)
%CONTROLAXISINDEX Map the _x/_y/_z suffix to 1/2/3.
    suffixes = {'_x', '_y', '_z'};
    axisIndex = 0;
    for index = 1:numel(suffixes)
        suffixLength = numel(suffixes{index});
        if numel(parameterName) > suffixLength && ...
                strcmp(parameterName(end - suffixLength + 1:end), suffixes{index})
            axisIndex = index;
        end
    end
end
