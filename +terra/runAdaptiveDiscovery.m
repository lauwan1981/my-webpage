function valleys = runAdaptiveDiscovery(context)
%RUNADAPTIVEDISCOVERY The adaptive method's full-band valley search.
%   valleys = terra.runAdaptiveDiscovery(context) re-searches the whole
%   predeclared band on context.frequencyGrid with Brent refinement and
%   full qualification (terra.discoverFrequencyValleys). Every new
%   parameter point calls this, so newly born valleys cannot be missed
%   by warm starting (manuscript Section 3.3).

    options.refinement = 'brent';
    options.computeDiagnostics = true;
    valleys = terra.discoverFrequencyValleys(context, context.frequencyGrid, options);
end
