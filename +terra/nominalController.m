function controller = nominalController(configuration)
%NOMINALCONTROLLER Nominal tunable controller parameters q (user V5.4).
%   controller = terra.nominalController(configuration) returns
%       referenceInertiaKilogramMetersSquared  3x1 design inertia
%       bandwidthRadiansPerSecond              common design bandwidth
%       dampingRatio                           3x1 design damping ratios
%       rolloffFrequencyRadiansPerSecond       3x1 roll-off frequencies
%       versionLabel                           controller version string

    controller = configuration.controller;
end
