function stability = assessClosedLoopStability(plant, controller, configuration, delaySeconds, options)
%ASSESSCLOSEDLOOPSTABILITY Closed-loop stability with the exact delay.
%   stability = terra.assessClosedLoopStability(plant, controller,
%   configuration, delaySeconds, options) checks every configuration
%   before its diagnostics are interpreted (manuscript Section 4.1):
%     (a) zero-delay closed-loop eigenvalues (exact, eig);
%     (b) common-delay margin tau_dm from loop eigen-loci
%         (terra.computeCommonDelayMargin): stable for tau < tau_dm;
%     (c) optional: rightmost exact-delay roots at tau
%         (terra.computeDelaySystemRoots, set options.computeRoots).
%   status
%     'unstable_without_delay'  (a) has a root with real part >= 0
%     'stable_exact_delay'      (a) stable, tau < tau_dm on a certified
%                               band and, when computed, every verified
%                               root of (c) has negative real part
%     'unstable_exact_delay'    tau >= tau_dm and (c) found a verified root
%                               with real part >= 0
%     'beyond_delay_margin'     tau >= tau_dm on a certified band, roots
%                               not computed (tau_dm proves stability only
%                               on [0, tau_dm); stability may return at a
%                               larger delay)
%     'inconclusive'            any other combination
%   All results are double-precision numerical evidence, not interval
%   certificates.

    if nargin < 5
        options = struct();
    end
    if ~isfield(options, 'computeRoots')
        options.computeRoots = true;
    end

    interconnection = terra.buildInterconnection(plant, controller, configuration);
    zeroDelayEigenvalues = eig(interconnection.zeroDelayClosedLoopMatrix);
    stability.delaySeconds = delaySeconds;
    stability.stateCount = interconnection.stateCount;
    stability.zeroDelayMaximumRealPart = max(real(zeroDelayEigenvalues));
    stability.zeroDelayEigenvalues = zeroDelayEigenvalues;
    stability.delayMargin = terra.computeCommonDelayMargin(plant, controller, configuration);
    stability.delayMarginSeconds = stability.delayMargin.delayMarginSeconds;

    if options.computeRoots
        stability.roots = terra.computeDelaySystemRoots(interconnection, delaySeconds, ...
            configuration.stability);
        stability.rightmostRealPart = stability.roots.maximumVerifiedRealPart;
    else
        stability.roots = struct();
        stability.rightmostRealPart = NaN;
    end

    isZeroDelayStable = stability.zeroDelayMaximumRealPart < 0;
    isWithinMargin = stability.delayMargin.isBandCertified && ...
        delaySeconds < stability.delayMarginSeconds;
    hasRootEvidence = options.computeRoots && isfinite(stability.rightmostRealPart);
    rootsAgree = ~hasRootEvidence || (stability.rightmostRealPart < 0) == isWithinMargin;

    isBeyondCertifiedMargin = stability.delayMargin.isBandCertified && ~isWithinMargin;
    if ~isZeroDelayStable
        stability.status = 'unstable_without_delay';
    elseif isWithinMargin && rootsAgree
        stability.status = 'stable_exact_delay';
    elseif isBeyondCertifiedMargin && hasRootEvidence && stability.rightmostRealPart >= 0
        stability.status = 'unstable_exact_delay';
    elseif isBeyondCertifiedMargin && ~hasRootEvidence
        stability.status = 'beyond_delay_margin';
    else
        stability.status = 'inconclusive';
    end
end
