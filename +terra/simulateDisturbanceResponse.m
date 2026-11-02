function simulation = simulateDisturbanceResponse(plant, controller, configuration, delaySeconds)
%SIMULATEDISTURBANCERESPONSE Time response to the orbital torque bound.
%   simulation = terra.simulateDisturbanceResponse(plant, controller,
%   configuration, delaySeconds) applies the source's orbital disturbance
%   bound T_ext as a body-torque step at t_on and simulates the closed
%   loop with
%     - the exact transport delay (time step chosen so that tau/dt is an
%       integer; the delayed command is read from a buffer),
%     - command saturation at the declared rated torque,
%     - exact (matrix-exponential) discretization of the delay-free
%       interconnection with first-order-hold inputs.
%   The only approximation is the linear interpolation of the delayed
%   command and the disturbance within one step. At zero delay the
%   command sampled at the start of a step is held over that step
%   (sample and hold, up to one step of lag); no study case uses zero
%   delay.
%
%   Output fields
%       timeSeconds, attitudeRadians (3xT), commandNewtonMeters (3xT),
%       timeStepSeconds, delaySteps, peakAttitudeRadians,
%       steadyStateAttitudeRadians, steadyStateApeRatio (vs APE),
%       peakCommandRatio, saturationFraction, settlingTimeSeconds

    response = configuration.response;
    ratedTorque = configuration.actuator.ratedTorqueNewtonMeters(:);
    disturbanceTorque = configuration.requirements.orbitalDisturbanceTorqueNewtonMeters(:);
    interconnection = terra.buildInterconnection(plant, controller, configuration);

    if delaySeconds > 0
        delaySteps = ceil(delaySeconds / response.maximumTimeStepSeconds);
        timeStep = delaySeconds / delaySteps;
    else
        delaySteps = 0;
        timeStep = response.maximumTimeStepSeconds;
    end
    stepCount = ceil(response.simulationDurationSeconds / timeStep);
    [transition, holdInput, rampInput] = firstOrderHoldDiscretization( ...
        interconnection.stateMatrix, ...
        [interconnection.delayedCommandInput, interconnection.disturbanceInput], timeStep);

    axisCount = 3;
    commandHistory = zeros(axisCount, stepCount + 1);
    state = zeros(interconnection.stateCount, 1);
    decimation = response.storedSampleDecimation;
    storedCount = floor(stepCount / decimation) + 1;
    storedTime = zeros(1, storedCount);
    storedAttitude = zeros(axisCount, storedCount);
    storedCommand = zeros(axisCount, storedCount);
    peakAttitude = zeros(axisCount, 1);
    peakCommand = zeros(axisCount, 1);
    saturatedSteps = 0;
    steadyStart = response.simulationDurationSeconds - response.steadyStateWindowSeconds;
    steadySum = zeros(axisCount, 1);
    steadyCount = 0;
    attitudeHistoryForSettling = zeros(axisCount, stepCount + 1);

    for stepIndex = 0:stepCount
        timeNow = stepIndex * timeStep;
        command = interconnection.commandOutput * state;
        commandHistory(:, stepIndex + 1) = command;
        attitude = interconnection.attitudeOutput * state;
        attitudeHistoryForSettling(:, stepIndex + 1) = attitude;
        peakAttitude = max(peakAttitude, abs(attitude));
        peakCommand = max(peakCommand, abs(command));
        if any(abs(command) > ratedTorque)
            saturatedSteps = saturatedSteps + 1;
        end
        if timeNow >= steadyStart
            steadySum = steadySum + attitude;
            steadyCount = steadyCount + 1;
        end
        if mod(stepIndex, decimation) == 0
            storedPosition = stepIndex / decimation + 1;
            storedTime(storedPosition) = timeNow;
            storedAttitude(:, storedPosition) = attitude;
            storedCommand(:, storedPosition) = command;
        end
        if stepIndex == stepCount
            break;
        end
        delayedNow = delayedCommand(commandHistory, stepIndex, delaySteps, ratedTorque);
        delayedNext = delayedCommand(commandHistory, stepIndex + 1, delaySteps, ratedTorque);
        if delaySteps == 0
            delayedNext = delayedNow;
        end
        disturbanceNow = disturbanceTorque * double(timeNow >= response.disturbanceOnsetSeconds);
        disturbanceNext = disturbanceTorque * ...
            double(timeNow + timeStep >= response.disturbanceOnsetSeconds);
        inputNow = [delayedNow; disturbanceNow];
        inputSlope = ([delayedNext; disturbanceNext] - inputNow) / timeStep;
        state = transition * state + holdInput * inputNow + rampInput * inputSlope;
    end

    steadyAttitude = steadySum / max(steadyCount, 1);
    simulation.timeSeconds = storedTime;
    simulation.attitudeRadians = storedAttitude;
    simulation.commandNewtonMeters = storedCommand;
    simulation.timeStepSeconds = timeStep;
    simulation.delaySteps = delaySteps;
    simulation.peakAttitudeRadians = peakAttitude;
    simulation.steadyStateAttitudeRadians = steadyAttitude;
    simulation.steadyStateApeRatio = abs(steadyAttitude) ./ ...
        configuration.requirements.absolutePointingErrorRadians(:);
    simulation.peakCommandRatio = peakCommand ./ ratedTorque;
    simulation.saturationFraction = saturatedSteps / (stepCount + 1);
    simulation.settlingTimeSeconds = settlingTimes(attitudeHistoryForSettling, ...
        steadyAttitude, timeStep, response);
end

function command = delayedCommand(commandHistory, stepIndex, delaySteps, ratedTorque)
%DELAYEDCOMMAND Saturated command issued delaySteps samples earlier.
    sourceIndex = stepIndex - delaySteps;
    if sourceIndex < 0
        command = zeros(size(ratedTorque));
    else
        command = min(max(commandHistory(:, sourceIndex + 1), -ratedTorque), ratedTorque);
    end
end

function [transition, holdInput, rampInput] = firstOrderHoldDiscretization( ...
        stateMatrix, inputMatrix, timeStep)
%FIRSTORDERHOLDDISCRETIZATION Exact step for inputs linear within a step.
%   expm([A B 0; 0 0 I; 0 0 0] dt) = [Phi Gamma0 Gamma1; ...], so that
%   x(k+1) = Phi x(k) + Gamma0 w(k) + Gamma1 (w(k+1) - w(k))/dt.
    stateCount = size(stateMatrix, 1);
    inputCount = size(inputMatrix, 2);
    augmented = zeros(stateCount + 2 * inputCount);
    augmented(1:stateCount, 1:stateCount) = stateMatrix;
    augmented(1:stateCount, stateCount + (1:inputCount)) = inputMatrix;
    augmented(stateCount + (1:inputCount), stateCount + inputCount + (1:inputCount)) = ...
        eye(inputCount);
    exponential = expm(augmented * timeStep);
    transition = exponential(1:stateCount, 1:stateCount);
    holdInput = exponential(1:stateCount, stateCount + (1:inputCount));
    rampInput = exponential(1:stateCount, stateCount + inputCount + (1:inputCount));
end

function settling = settlingTimes(attitudeHistory, steadyAttitude, timeStep, response)
%SETTLINGTIMES Last time each axis leaves the +-band around its final value.
    axisCount = size(attitudeHistory, 1);
    settling = zeros(axisCount, 1);
    for axisIndex = 1:axisCount
        bandHalfWidth = response.settlingBandFraction * abs(steadyAttitude(axisIndex));
        outside = find(abs(attitudeHistory(axisIndex, :) - steadyAttitude(axisIndex)) > ...
            bandHalfWidth, 1, 'last');
        if isempty(outside)
            settling(axisIndex) = 0;
        else
            settling(axisIndex) = (outside - 1) * timeStep - response.disturbanceOnsetSeconds;
        end
    end
end
