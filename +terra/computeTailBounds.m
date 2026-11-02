function tails = computeTailBounds(plant, controller, configuration, lowEdge, highEdge, actuatorScale)
%COMPUTETAILBOUNDS Analytic loop-gain bounds outside [lowEdge, highEdge].
%   tails = terra.computeTailBounds(plant, controller, configuration,
%   lowEdge, highEdge, actuatorScale) bounds the loop L = diag(c) G for
%   every frequency below lowEdge and above highEdge, using the modal
%   form G = R0/s^2 + sum_k R_k/(s - lambda_k) and monotone bounds of the
%   sensor, roll-off and wheel factors. The delay has unit modulus and
%   does not enter. Results (double precision, not interval arithmetic):
%
%     low tail  (omega <= lowEdge):  sigma_min(L) >= lowLoopLowerBound
%     high tail (omega >= highEdge): sigma_max(L) <= highLoopUpperBound
%
%   and the implied lower bounds of the weighted diagnostic
%       f_W >= sigma_min(L)/cond(W) - 1   (low tail)
%       f_W >= 1 - cond(W) sigma_max(L)   (high tail)
%   Unit-modulus loop eigenvalues are impossible where sigma_min(L) > 1
%   or sigma_max(L) < 1, which certifies the delay-margin search band.

    [proportionalGains, derivativeGains] = terra.computeControllerGains(controller);
    starBandwidth = configuration.sensors.starTrackerBandwidthRadiansPerSecond;
    wheelFrequency = configuration.actuator.wheelNaturalFrequencyRadiansPerSecond;
    wheelDamping = configuration.actuator.wheelDampingRatio;
    rolloff = controller.rolloffFrequencyRadiansPerSecond(:);
    scalingCondition = max(actuatorScale) / min(actuatorScale);

    modeMagnitudes = abs(plant.eigenvalues(:));
    residueNorms = zeros(numel(plant.eigenvalues), 1);
    for modeIndex = 1:numel(plant.eigenvalues)
        residueNorms(modeIndex) = norm(plant.residues(:, :, modeIndex), 2);
    end
    conjugateMultiplicity = 2 - double(plant.isReal(:));
    rigidSingularValues = svd(plant.rigidResidue);

    tails.lowEdge = lowEdge;
    tails.highEdge = highEdge;
    tails.scalingCondition = scalingCondition;

    %% Low tail ------------------------------------------------------------------
    tails.isLowValid = isempty(modeMagnitudes) || lowEdge < min(modeMagnitudes);
    if tails.isLowValid
        modalUpper = sum(conjugateMultiplicity .* residueNorms ./ (modeMagnitudes - lowEdge));
        plantLower = rigidSingularValues(end) / lowEdge ^ 2 - modalUpper;
        blendLower = proportionalGains * starBandwidth / sqrt(starBandwidth ^ 2 + lowEdge ^ 2) - ...
            derivativeGains * lowEdge;
        lowpassLower = 1 ./ (1 + (lowEdge ./ rolloff) .^ 2);
        % |w^2 / (w^2 - x^2 + 2j zeta w x)| >= w^2 / sqrt(w^4 + (2 zeta w x)^2)
        % for x^2 <= 2 w^2, which holds at the low edge.
        wheelFrequencySquared = wheelFrequency ^ 2;
        wheelLower = wheelFrequencySquared / sqrt(wheelFrequencySquared ^ 2 + ...
            (2 * wheelDamping * wheelFrequency * lowEdge) ^ 2);
        channelLower = min(max(blendLower, 0) .* lowpassLower) * wheelLower;
        tails.lowLoopLowerBound = channelLower * max(plantLower, 0);
    else
        tails.lowLoopLowerBound = NaN;
    end
    tails.lowDiagnosticLowerBound = tails.lowLoopLowerBound / scalingCondition - 1;

    %% High tail -----------------------------------------------------------------
    tails.isHighValid = (isempty(modeMagnitudes) || highEdge > max(modeMagnitudes)) && ...
        highEdge >= max(rolloff);
    if tails.isHighValid
        modalUpper = sum(conjugateMultiplicity .* residueNorms ./ (highEdge - modeMagnitudes));
        plantUpper = rigidSingularValues(1) / highEdge ^ 2 + modalUpper;
        channelUpper = max((proportionalGains + derivativeGains * highEdge) ./ ...
            (1 + (highEdge ./ rolloff) .^ 2));
        if wheelDamping < 1 / sqrt(2)
            wheelUpper = 1 / (2 * wheelDamping * sqrt(1 - wheelDamping ^ 2));
        else
            wheelUpper = 1;
        end
        tails.highLoopUpperBound = channelUpper * wheelUpper * plantUpper;
    else
        tails.highLoopUpperBound = NaN;
    end
    tails.highDiagnosticLowerBound = 1 - scalingCondition * tails.highLoopUpperBound;

    tails.excludesLowUnitCrossing = tails.isLowValid && tails.lowLoopLowerBound > 1;
    tails.excludesHighUnitCrossing = tails.isHighValid && tails.highLoopUpperBound < 1;
    tails.note = ['Analytic norm bounds in double precision; not outward-rounded ' ...
        'interval certificates.'];
end
