function margins = guaranteedMultiloopMargins(diskMargin)
%GUARANTEEDMULTILOOPMARGINS Simultaneous gain/phase margins from sigma_min.
%   margins = terra.guaranteedMultiloopMargins(diskMargin) converts
%   alpha = min_omega sigma_min(I + L) (at the actuator command end) into
%   the classical guaranteed margins for simultaneous, independent
%   multiplicative gain or phase changes in all channels:
%       gain factor in [1/(1 + alpha), 1/(1 - alpha)],
%       phase change within +-2 asin(alpha/2)
%   (Lehtomaki, Sandell and Athans, IEEE TAC 26(1), 1981). Because
%   diagonal perturbations commute with diagonal scaling, the bound also
%   holds for alpha computed with any diagonal W_u. Valid for 0 < alpha <= 1.
%   This is the requirement used by the source: alpha >= 1/gamma = 2/3
%   gives a gain margin of 3 (9.54 dB) and a phase margin of 38.9 deg.

    unitConstants = terra.units();
    clampedDiskMargin = min(max(diskMargin, 0), 1);
    margins.diskMargin = diskMargin;
    margins.lowerGainFactor = 1 / (1 + clampedDiskMargin);
    if clampedDiskMargin < 1
        margins.upperGainFactor = 1 / (1 - clampedDiskMargin);
    else
        margins.upperGainFactor = Inf;
    end
    margins.upperGainMarginDecibels = unitConstants.decibelsPerMagnitude * ...
        log10(margins.upperGainFactor);
    margins.lowerGainMarginDecibels = unitConstants.decibelsPerMagnitude * ...
        log10(margins.lowerGainFactor);
    margins.phaseMarginDegrees = 2 * asin(clampedDiskMargin / 2) * unitConstants.radiansToDegrees;
end
