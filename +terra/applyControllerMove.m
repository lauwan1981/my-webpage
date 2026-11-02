function [controller, isFeasible] = applyControllerMove(controller, move, configuration)
%APPLYCONTROLLERMOVE Apply one move if it respects the declared bounds.
%   [controller, isFeasible] = terra.applyControllerMove(controller,
%   move, configuration) adds move.direction * move.stepSize to the named
%   controller parameter. If the result violates the declared feasible
%   range (configuration.remediation), the controller is returned
%   unchanged with isFeasible = false. An empty move (code 0) means
%   "leave the controller unchanged".

    isFeasible = true;
    if isempty(move) || move.code == 0
        return;
    end
    remediation = configuration.remediation;
    currentValue = terra.getParameterValue(configuration, [], controller, move.parameterName);
    newValue = currentValue + move.direction * move.stepSize;
    if strncmp(move.parameterName, 'damping', numel('damping'))
        bounds = remediation.dampingBounds;
    elseif strncmp(move.parameterName, 'rolloff', numel('rolloff'))
        bounds = remediation.rolloffBoundsRadiansPerSecond;
    else
        error('terra:UnknownMove', 'No bounds are declared for controller parameter "%s".', ...
            move.parameterName);
    end
    if newValue < bounds(1) || newValue > bounds(2)
        isFeasible = false;
        return;
    end
    [~, controller] = terra.setParameterValue(configuration, [], controller, ...
        move.parameterName, newValue);
end
