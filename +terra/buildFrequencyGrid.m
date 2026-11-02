function frequencies = buildFrequencyGrid(bandRadiansPerSecond, pointCount, plant, configuration)
%BUILDFREQUENCYGRID Initial grid: log grid plus modal neighbourhood points.
%   frequencies = terra.buildFrequencyGrid(bandRadiansPerSecond,
%   pointCount, plant, configuration) returns a sorted row of unique
%   frequencies in the band. With an empty plant the grid is a plain
%   logarithmic grid (used by the dense baselines). With a plant, points
%   |Im lambda_k| * (1 + m * step * zeta_k), m = -H..H, are added around
%   the damped frequency of every lightly damped plant mode so that
%   narrow valleys created by lightly damped modes cannot fall between
%   grid points. The grid is fixed before any result is inspected
%   (manuscript Section 4.3).

    lowerFrequency = bandRadiansPerSecond(1);
    upperFrequency = bandRadiansPerSecond(2);
    logGrid = logspace(log10(lowerFrequency), log10(upperFrequency), pointCount);
    modalPoints = zeros(1, 0);
    if ~isempty(plant)
        search = configuration.search;
        offsets = (-search.modalNeighbourhoodHalfCount:search.modalNeighbourhoodHalfCount) * ...
            search.modalNeighbourhoodOffsetStepInDampingUnits;
        for modeIndex = 1:numel(plant.naturalFrequencies)
            dampingRatio = plant.dampingRatios(modeIndex);
            if plant.isReal(modeIndex) || ...
                    dampingRatio >= configuration.model.lightDampingThreshold
                continue;
            end
            dampedFrequency = abs(imag(plant.eigenvalues(modeIndex)));
            modalPoints = [modalPoints, dampedFrequency * (1 + offsets * dampingRatio)]; %#ok<AGROW>
        end
    end
    insideBand = modalPoints > lowerFrequency & modalPoints < upperFrequency;
    frequencies = unique([logGrid, modalPoints(insideBand)]);
end
