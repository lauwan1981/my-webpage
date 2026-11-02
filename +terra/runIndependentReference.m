function referenceValleys = runIndependentReference(plant, controller, configuration, ...
        delaySeconds, actuatorScale, pointCount)
%RUNINDEPENDENTREFERENCE Dense, independently implemented reference valleys.
%   referenceValleys = terra.runIndependentReference(plant, controller,
%   configuration, delaySeconds, actuatorScale, pointCount) evaluates the
%   diagnostic with the state-space resolvent of the assembled
%   interconnection (no modal residues, no transfer-function channels),
%   on a plain logarithmic grid of pointCount points (no modal points),
%   and refines every sampled minimum by golden-section search in linear
%   frequency (no Brent refinement). Its evaluator (state-space
%   resolvent) and its grid and refinement are independent of the
%   adaptive method; it shares the modal plant data, the gain law, the
%   candidate bookkeeping of terra.discoverFrequencyValleys and the
%   golden-section routine that the method uses for its error bounds
%   (manuscript Section 3.3, "independent dense scan").

    context = terra.createDiagnosticContext(plant, controller, configuration, ...
        delaySeconds, actuatorScale, 'state_space', 'independent reference');
    frequencies = terra.buildFrequencyGrid(configuration.search.bandRadiansPerSecond, ...
        pointCount, [], configuration);
    options.refinement = 'golden';
    options.relativeTolerance = configuration.baseline.referenceRefinementRelativeTolerance;
    options.maximumIterations = configuration.search.goldenSectionMaximumIterations;
    options.computeDiagnostics = false;
    referenceValleys = terra.discoverFrequencyValleys(context, frequencies, options);
end
