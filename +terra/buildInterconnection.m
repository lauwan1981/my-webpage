function interconnection = buildInterconnection(plant, controller, configuration)
%BUILDINTERCONNECTION Delay-free state-space interconnection, broken at v.
%   interconnection = terra.buildInterconnection(plant, controller,
%   configuration) assembles plant G, wheels Ga, sensors H and the
%   controller K (manuscript Section 2.1) into one real state-space model
%   whose loop is broken at the delayed command v = u(t - tau):
%
%       x' = A x + B_v v + B_d d + B_ns n_star + B_ng n_gyro
%       u  = C_u x                (controller command, negative feedback)
%
%   Closing v = u gives the zero-delay loop; v(t) = u(t - tau) gives the
%   delay-differential equation x' = A x + B_v C_u x(t - tau).
%   State order: [plant; wheels (torque, torque rate per axis); star
%   tracker; gyro; controller roll-off stage 1; controller roll-off
%   stage 2].
%   Noise enters at the sensor outputs (y = H z + n); the disturbance d
%   is a body torque added to the wheel torque.
%
%   Output fields
%       stateMatrix, delayedCommandInput (B_v), disturbanceInput (B_d),
%       starNoiseInput, gyroNoiseInput, commandOutput (C_u),
%       attitudeOutput, rateOutput, rateDisturbanceFeedthrough,
%       wheelTorqueOutput, zeroDelayClosedLoopMatrix, stateCount,
%       blockIndices (struct of index vectors), stateNames (cell)

    axisCount = 3;
    [proportionalGains, derivativeGains] = terra.computeControllerGains(controller);
    starBandwidth = configuration.sensors.starTrackerBandwidthRadiansPerSecond;
    gyroBandwidth = configuration.sensors.gyroBandwidthRadiansPerSecond;
    wheelFrequency = configuration.actuator.wheelNaturalFrequencyRadiansPerSecond;
    wheelDamping = configuration.actuator.wheelDampingRatio;
    rolloffMatrix = diag(controller.rolloffFrequencyRadiansPerSecond(:));

    %% Component realizations ------------------------------------------------
    wheelAxisMatrix = [0, 1; -wheelFrequency ^ 2, -2 * wheelDamping * wheelFrequency];
    wheelStateMatrix = kron(eye(axisCount), wheelAxisMatrix);
    wheelInputMatrix = kron(eye(axisCount), [0; wheelFrequency ^ 2]);
    wheelOutputMatrix = kron(eye(axisCount), [1, 0]);

    plantStateCount = plant.stateCount;
    wheelStateCount = size(wheelStateMatrix, 1);
    index.plant = 1:plantStateCount;
    index.wheel = plantStateCount + (1:wheelStateCount);
    index.star = index.wheel(end) + (1:axisCount);
    index.gyro = index.star(end) + (1:axisCount);
    index.rolloffFirst = index.gyro(end) + (1:axisCount);
    index.rolloffSecond = index.rolloffFirst(end) + (1:axisCount);
    stateCount = index.rolloffSecond(end);

    stateMatrix = zeros(stateCount);
    delayedCommandInput = zeros(stateCount, axisCount);
    disturbanceInput = zeros(stateCount, axisCount);
    starNoiseInput = zeros(stateCount, axisCount);
    gyroNoiseInput = zeros(stateCount, axisCount);

    %% Plant driven by wheel torque plus disturbance --------------------------
    stateMatrix(index.plant, index.plant) = plant.stateMatrix;
    stateMatrix(index.plant, index.wheel) = plant.inputMatrix * wheelOutputMatrix;
    disturbanceInput(index.plant, :) = plant.inputMatrix;

    %% Wheels driven by the delayed command ------------------------------------
    stateMatrix(index.wheel, index.wheel) = wheelStateMatrix;
    delayedCommandInput(index.wheel, :) = wheelInputMatrix;

    %% Star tracker (attitude) and gyro (rate) ---------------------------------
    stateMatrix(index.star, index.plant) = starBandwidth * plant.attitudeOutputMatrix;
    stateMatrix(index.star, index.star) = -starBandwidth * eye(axisCount);
    stateMatrix(index.gyro, index.plant) = gyroBandwidth * plant.rateOutputMatrix;
    stateMatrix(index.gyro, index.wheel) = gyroBandwidth * plant.rateFeedthrough * ...
        wheelOutputMatrix;
    stateMatrix(index.gyro, index.gyro) = -gyroBandwidth * eye(axisCount);
    disturbanceInput(index.gyro, :) = gyroBandwidth * plant.rateFeedthrough;

    %% Controller: PD blend followed by two first-order roll-off stages -----------
    stateMatrix(index.rolloffFirst, index.star) = rolloffMatrix * diag(proportionalGains);
    stateMatrix(index.rolloffFirst, index.gyro) = rolloffMatrix * diag(derivativeGains);
    stateMatrix(index.rolloffFirst, index.rolloffFirst) = -rolloffMatrix;
    stateMatrix(index.rolloffSecond, index.rolloffFirst) = rolloffMatrix;
    stateMatrix(index.rolloffSecond, index.rolloffSecond) = -rolloffMatrix;
    starNoiseInput(index.rolloffFirst, :) = rolloffMatrix * diag(proportionalGains);
    gyroNoiseInput(index.rolloffFirst, :) = rolloffMatrix * diag(derivativeGains);

    commandOutput = zeros(axisCount, stateCount);
    commandOutput(:, index.rolloffSecond) = -eye(axisCount);
    attitudeOutput = zeros(axisCount, stateCount);
    attitudeOutput(:, index.plant) = plant.attitudeOutputMatrix;
    rateOutput = zeros(axisCount, stateCount);
    rateOutput(:, index.plant) = plant.rateOutputMatrix;
    rateOutput(:, index.wheel) = plant.rateFeedthrough * wheelOutputMatrix;
    wheelTorqueOutput = zeros(axisCount, stateCount);
    wheelTorqueOutput(:, index.wheel) = wheelOutputMatrix;

    interconnection.stateMatrix = stateMatrix;
    interconnection.delayedCommandInput = delayedCommandInput;
    interconnection.disturbanceInput = disturbanceInput;
    interconnection.starNoiseInput = starNoiseInput;
    interconnection.gyroNoiseInput = gyroNoiseInput;
    interconnection.commandOutput = commandOutput;
    interconnection.attitudeOutput = attitudeOutput;
    interconnection.rateOutput = rateOutput;
    interconnection.rateDisturbanceFeedthrough = plant.rateFeedthrough;
    interconnection.wheelTorqueOutput = wheelTorqueOutput;
    interconnection.zeroDelayClosedLoopMatrix = stateMatrix + ...
        delayedCommandInput * commandOutput;
    interconnection.stateCount = stateCount;
    interconnection.blockIndices = index;
    interconnection.stateNames = describeStates(index, plant);
end

function stateNames = describeStates(index, plant)
%DESCRIBESTATES Human-readable state labels for the exported matrices.
%   Plant state order (terra.buildPlantModel): rigid attitude (3), rigid
%   rate (3), then flexible block-modal states. Wheel states alternate
%   torque and torque rate per axis.
    axisLabels = {'x', 'y', 'z'};
    axisCount = numel(axisLabels);
    rigidStateCount = 2 * axisCount;
    stateNames = cell(index.rolloffSecond(end), 1);
    for axisIndex = 1:axisCount
        wheelOffset = 2 * (axisIndex - 1);
        stateNames{index.plant(axisIndex)} = ['rigid_attitude_', axisLabels{axisIndex}];
        stateNames{index.plant(axisCount + axisIndex)} = ['rigid_rate_', axisLabels{axisIndex}];
        stateNames{index.wheel(wheelOffset + 1)} = ['wheel_torque_', axisLabels{axisIndex}];
        stateNames{index.wheel(wheelOffset + 2)} = ['wheel_torque_rate_', axisLabels{axisIndex}];
        stateNames{index.star(axisIndex)} = ['star_tracker_', axisLabels{axisIndex}];
        stateNames{index.gyro(axisIndex)} = ['gyro_', axisLabels{axisIndex}];
        stateNames{index.rolloffFirst(axisIndex)} = ['rolloff_stage1_', axisLabels{axisIndex}];
        stateNames{index.rolloffSecond(axisIndex)} = ['rolloff_stage2_', axisLabels{axisIndex}];
    end
    flexibleStateCount = plant.stateCount - rigidStateCount;
    for position = 1:flexibleStateCount
        stateNames{index.plant(rigidStateCount + position)} = ...
            sprintf('flexible_modal_%02d', position);
    end
end
