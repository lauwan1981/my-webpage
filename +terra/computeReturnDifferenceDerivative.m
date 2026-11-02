function derivative = computeReturnDifferenceDerivative(context, frequencies, parameterName)
%COMPUTERETURNDIFFERENCEDERIVATIVE dF~/dp at fixed frequencies, 3x3xK.
%   derivative = terra.computeReturnDifferenceDerivative(context,
%   frequencies, parameterName) returns the derivative of the weighted
%   return difference W^-1 F_u W with respect to one parameter, holding
%   omega and W fixed (manuscript Section 3.2, F~' = W^-1 (K'HG + KH'G +
%   KHG') W):
%     damping_*, rolloff_*  analytic derivative of the channel gain c_i
%     loop_delay            analytic: dL/dtau = -s L
%     physical parameters   central difference of L in the rebuilt model
%                           (G' term), step from configuration.derivatives
%   Units: per unit of the parameter (deg, s, kg, kg m^2, rad/s or 1).

    axisCount = size(context.plant.rigidResidue, 1);
    frequencies = reshape(frequencies, 1, []);
    pointCount = numel(frequencies);
    loop = terra.evaluateLoopResponse(context.plant, context.controller, ...
        context.configuration, frequencies, context.delaySeconds);
    channels = loop.channels;
    laplaceValues = loop.laplaceValues;
    channelDerivative = zeros(axisCount, pointCount);

    switch parameterName
        case {'damping_x', 'damping_y', 'damping_z'}
            axisIndex = axisOf(parameterName);
            referenceInertia = context.controller.referenceInertiaKilogramMetersSquared(axisIndex);
            bandwidth = context.controller.bandwidthRadiansPerSecond;
            derivativeGainSlope = 2 * referenceInertia * bandwidth;
            channelDerivative(axisIndex, :) = derivativeGainSlope * channels.gyro .* ...
                laplaceValues .* channels.lowpass(axisIndex, :) .* channels.wheel .* ...
                channels.delayFactor;
        case {'rolloff_x', 'rolloff_y', 'rolloff_z'}
            axisIndex = axisOf(parameterName);
            rolloff = context.controller.rolloffFrequencyRadiansPerSecond(axisIndex);
            % LP = (1 + s/w_r)^-n with n = rolloffOrder, so
            % dLP/dw_r = n s / w_r^2 (1 + s/w_r)^-(n+1).
            rolloffOrder = 2;
            lowpassSlope = rolloffOrder * laplaceValues / rolloff ^ 2 .* ...
                (1 + laplaceValues / rolloff) .^ (-(rolloffOrder + 1));
            channelDerivative(axisIndex, :) = channels.sensorBlend(axisIndex, :) .* ...
                lowpassSlope .* channels.wheel .* channels.delayFactor;
        case 'loop_delay'
            channelDerivative = -channels.channelGain .* repmat(laplaceValues, axisCount, 1);
        otherwise
            derivative = physicalDerivative(context, frequencies, parameterName);
            return;
    end

    rowScale = reshape(channelDerivative, axisCount, 1, pointCount);
    loopDerivative = loop.plantResponse .* repmat(rowScale, [1, axisCount, 1]);
    derivative = terra.applyActuatorScaling(loopDerivative, context.actuatorScale);
end

function derivative = physicalDerivative(context, frequencies, parameterName)
%PHYSICALDERIVATIVE Central difference of the loop in a rebuilt model.
    settings = context.configuration.derivatives;
    nominalValue = terra.getParameterValue(context.configuration, ...
        context.operatingPoint, context.controller, parameterName);
    step = max(settings.physicalFiniteDifferenceRelativeStep * abs(nominalValue), ...
        settings.physicalFiniteDifferenceAbsoluteFloor);
    upperContext = perturbedContext(context, parameterName, nominalValue + step);
    lowerContext = perturbedContext(context, parameterName, nominalValue - step);
    upperResponse = terra.evaluateWeightedReturnDifference(upperContext, frequencies);
    lowerResponse = terra.evaluateWeightedReturnDifference(lowerContext, frequencies);
    derivative = (upperResponse - lowerResponse) / (2 * step);
end

function perturbed = perturbedContext(context, parameterName, value)
%PERTURBEDCONTEXT Same mode set and scaling, one physical parameter moved.
    [operatingPoint, controller] = terra.setParameterValue(context.configuration, ...
        context.operatingPoint, context.controller, parameterName, value);
    perturbed = terra.createOperatingContext(context.configuration, operatingPoint, ...
        controller, context.modeSet, context.actuatorScale);
    if ~isequal(perturbed.plant.retainedModeIndices, context.plant.retainedModeIndices)
        error('terra:ModeSetChanged', ...
            'Perturbing %s changed the retained mode set; derivative undefined.', ...
            parameterName);
    end
end

function axisIndex = axisOf(parameterName)
%AXISOF Axis 1/2/3 from the _x/_y/_z suffix.
    suffix = parameterName(end);
    axisIndex = find(strcmp(suffix, {'x', 'y', 'z'}));
end
