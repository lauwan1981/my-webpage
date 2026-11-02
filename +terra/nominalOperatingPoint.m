function operatingPoint = nominalOperatingPoint(configuration)
%NOMINALOPERATINGPOINT Frozen configuration theta at the nominal values.
%   operatingPoint = terra.nominalOperatingPoint(configuration) returns
%   a struct with the physical (uncertain or varying) parameters p:
%       panelAngleDegrees         solar-array drive angle
%       delaySeconds              common loop transport delay
%       hubMassScale              hub mass / nominal hub mass
%       hubInertiaDiagonalScale   3x1 scale of the hub inertia diagonal
%       cantileverFrequencyScale  3x1 scale of cantilever modes 1..3

    operatingPoint = configuration.operatingPoint;
end
