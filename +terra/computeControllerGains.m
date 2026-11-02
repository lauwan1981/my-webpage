function [proportionalGains, derivativeGains] = computeControllerGains(controller)
%COMPUTECONTROLLERGAINS PD gains of the V5.4 controller (single source).
%   [proportionalGains, derivativeGains] = terra.computeControllerGains(
%   controller) returns 3x1 vectors
%       Kp = J_ref * omega_b^2            (N m / rad)
%       Kd = 2 * zeta * J_ref * omega_b   (N m s / rad)
%   This is the only place where the gain law is written down.

    referenceInertia = controller.referenceInertiaKilogramMetersSquared(:);
    bandwidth = controller.bandwidthRadiansPerSecond;
    proportionalGains = referenceInertia * bandwidth ^ 2;
    derivativeGains = 2 * controller.dampingRatio(:) .* referenceInertia * bandwidth;
end
