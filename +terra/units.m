function unitConstants = units()
%UNITS Named unit-conversion factors used throughout the study.
%   unitConstants = terra.units() returns multiplicative conversion
%   factors. Every unit conversion in the code base goes through these
%   named factors so that no bare conversion literal appears elsewhere.
%
%   Fields
%       degreesToRadians        degrees      -> radians
%       radiansToDegrees        radians      -> degrees
%       secondsToMilliseconds   seconds      -> milliseconds
%       millisecondsToSeconds   milliseconds -> seconds
%       radiansToMicroradians   radians      -> microradians
%       secondsPerDay           days (datenum) -> seconds
%       millidegreesToRadians   millidegrees -> radians
%       decibelsPerMagnitude    20, for 20*log10(magnitude)
%       percentToFraction       percent      -> fraction

    unitConstants.degreesToRadians = pi / 180;
    unitConstants.radiansToDegrees = 180 / pi;
    unitConstants.secondsToMilliseconds = 1e3;
    unitConstants.millisecondsToSeconds = 1e-3;
    unitConstants.radiansToMicroradians = 1e6;
    unitConstants.secondsPerDay = 86400;
    unitConstants.millidegreesToRadians = (pi / 180) * 1e-3;
    unitConstants.decibelsPerMagnitude = 20;
    unitConstants.percentToFraction = 1e-2;
end
