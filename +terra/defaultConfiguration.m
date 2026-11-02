function configuration = defaultConfiguration()
%DEFAULTCONFIGURATION Lock every model, numerical and reporting assumption.
%   configuration = terra.defaultConfiguration() returns the complete,
%   predeclared study configuration. Physical data, numerical tolerances,
%   case lists, figure settings and requirement values are defined here
%   once, with units in the field names, so that the analysis functions
%   contain no unexplained literals. Change values only here and record
%   every change in the manuscript's reproducibility statement.
%
%   Provenance (see configuration.provenance for the exact strings)
%       Structural data, actuator/sensor models, requirements and sensor
%       noise intensities reproduce Table 1 and Section 3.1 of
%       Sanfedino, Alazard, Kassarian and Somers (2023), "Satellite
%       dynamics toolbox library: a tool to model multi-body space
%       systems for robust control synthesis and analysis",
%       IFAC-PapersOnLine 56(2):9153-9160, arXiv:2303.15872.
%       This model is NOT the 2024 European Satellite Benchmark.
%       The attitude controller is the user-supplied V5.4 PD law with a
%       second-order roll-off; it is not the controller of either paper.

    unitConstants = terra.units();
    % Band-minimum differences below this are ties in every decision; the
    % equal-error dense baseline uses the same value as its error target.
    decisionTolerance = 1e-6;

    %% Study metadata and provenance -------------------------------------
    configuration.metadata.studyName = 'Terra active-valley margin study';
    configuration.metadata.codeVersion = '4.0.0';
    configuration.metadata.manuscriptVersion = 'V5.3 submission candidate';
    configuration.metadata.runMode = 'full';

    configuration.provenance.structuralModel = ['Sanfedino F, Alazard D, ' ...
        'Kassarian E, Somers F. Satellite dynamics toolbox library: a tool ' ...
        'to model multi-body space systems for robust control synthesis ' ...
        'and analysis. IFAC-PapersOnLine 56(2):9153-9160, 2023 ' ...
        '(arXiv:2303.15872), Table 1 and Section 3.1.'];
    configuration.provenance.notTheBenchmark = ['The model is not the ' ...
        '2024 European Satellite Benchmark (Sanfedino et al., ' ...
        'IFAC-PapersOnLine 2024); the manuscript must cite the 2023 source.'];
    configuration.provenance.controller = ['User-supplied V5.4 controller: ' ...
        'decentralized PD on star-tracker attitude and gyro rate, ' ...
        'second-order roll-off, common 10 ms loop delay.'];
    configuration.provenance.dampingModel = ['Cantilever (appendage) modal ' ...
        'damping as in SDTlib, i.e. non-classical damping at system level; ' ...
        'the system-level modal expansion therefore uses complex modes.'];
    configuration.provenance.controllerImplementation = ['Continuous-time ' ...
        'controller with an exact transport delay. Sampling and zero-order ' ...
        'hold are not modeled; state this in the manuscript or add them.'];

    %% Structure (hub plus two flexible solar arrays) ---------------------
    configuration.structure.hubMassKilograms = 1000;
    configuration.structure.hubInertiaKilogramMetersSquared = ...
        [75, 1, 2; ...
         1, 40, -1; ...
         2, -1, 80];
    configuration.structure.hubCenterOfMassMeters = [0.35; 1.50; 0.50];
    configuration.structure.panelAttachmentPointsMeters = ...
        {[0.4; 1.4; 1.0], [0.4; 1.4; 0.0]};
    % Columns of each frame are the panel axes expressed in the body frame.
    % Panel x is the span (drive) axis: panel 1 extends along +z body,
    % panel 2 along -z body.
    configuration.structure.panelReferenceFrames = ...
        {[0, -1, 0; 0, 0, -1; 1, 0, 0], ...
         [0, 1, 0; 0, 0, -1; -1, 0, 0]};
    % Both arrays turn together about the body z axis. Because the panel
    % span axes point in opposite body directions, the same physical
    % rotation is +angle about panel 1 x and -angle about panel 2 x.
    % Confirm this convention against the SDTlib model before publication.
    configuration.structure.panelRotationSigns = [1, -1];
    configuration.structure.panelMassKilograms = 43;
    configuration.structure.panelInertiaAtCenterOfMassKilogramMetersSquared = ...
        diag([17, 62, 80]);
    configuration.structure.panelCenterOfMassOffsetMeters = [2.07; 0; 0];
    configuration.structure.cantileverModeFrequenciesRadiansPerSecond = ...
        [5.6, 19.3, 35.4];
    configuration.structure.cantileverModeDampingRatio = 0.005;
    % Rows: cantilever modes 1..3. Columns: [Tx Ty Tz Rx Ry Rz] at the
    % attachment point in the panel frame. Units: sqrt(kg) for the
    % translation columns and m*sqrt(kg) for the rotation columns.
    configuration.structure.modalParticipationFactors = ...
        [0, 0, -5.12, 0, 12.5, 0; ...
         0, 0, 0, -3.84, 0, 0; ...
         0, 0, -2.97, 0, 2.51, 0];
    % Relative uncertainty half-ranges declared in the source (Table 1).
    configuration.structure.hubMassRelativeUncertainty = 0.20;
    configuration.structure.hubInertiaDiagonalRelativeUncertainty = 0.20;
    configuration.structure.modeFrequencyRelativeUncertainty = 0.20;

    %% Model numerics ------------------------------------------------------
    % Eigenvalues with |imag| <= tolerance*|lambda| are treated as real modes.
    configuration.model.realEigenvalueRelativeTolerance = 1e-10;
    % Modal (residue) sums must reproduce the resolvent to this accuracy.
    configuration.model.modalReconstructionTolerance = 1e-9;
    configuration.model.selfCheckFrequenciesRadiansPerSecond = [0.5, 3, 10, 22, 40];
    configuration.model.selfCheckTolerance = 1e-8;
    % Plant modes below this damping ratio receive extra grid points.
    configuration.model.lightDampingThreshold = 0.2;

    %% Nominal operating point -------------------------------------------
    configuration.operatingPoint.panelAngleDegrees = 0;
    configuration.operatingPoint.delaySeconds = 0.010;
    configuration.operatingPoint.hubMassScale = 1;
    configuration.operatingPoint.hubInertiaDiagonalScale = [1; 1; 1];
    configuration.operatingPoint.cantileverFrequencyScale = [1; 1; 1];

    %% Actuators and sensors (source Section 3.1) -------------------------
    configuration.actuator.wheelNaturalFrequencyRadiansPerSecond = 200 * pi;
    configuration.actuator.wheelDampingRatio = 0.7;
    % Rated torque is NOT given by the source. Declared research assumption.
    configuration.actuator.ratedTorqueNewtonMeters = [1; 1; 1];
    configuration.sensors.starTrackerBandwidthRadiansPerSecond = 16 * pi;
    configuration.sensors.gyroBandwidthRadiansPerSecond = 400 * pi;
    % White-noise intensities from the source; treated as two-sided
    % intensities so that variance = intensity * (1/pi) * int_0^inf |T|^2.
    configuration.sensors.starTrackerNoiseIntensityRadiansSquaredSeconds = 1e-8;
    configuration.sensors.gyroNoiseIntensityRadiansSquaredPerSecond = 1e-10;

    %% Nominal controller (user V5.4) ------------------------------------
    configuration.controller.referenceInertiaKilogramMetersSquared = ...
        [768; 768; 115];
    configuration.controller.bandwidthRadiansPerSecond = 0.998;
    configuration.controller.dampingRatio = 0.446 * ones(3, 1);
    configuration.controller.rolloffFrequencyRadiansPerSecond = ...
        42.89 * ones(3, 1);
    configuration.controller.versionLabel = 'V5.4';

    %% Requirements (source Section 3.1) ---------------------------------
    % Input-sensitivity peak bound gamma; disk margin requirement 1/gamma.
    configuration.requirements.inputSensitivityPeakBound = 1.5;
    configuration.requirements.diskMarginRequirement = ...
        1 / configuration.requirements.inputSensitivityPeakBound;
    configuration.requirements.absolutePointingErrorRadians = ...
        [4; 4; 20] * unitConstants.millidegreesToRadians;
    configuration.requirements.orbitalDisturbanceTorqueNewtonMeters = ...
        [0.03; 0.01; 0.02];

    %% Actuator-command-end scaling W_u (manuscript Section 2.2) ---------
    configuration.scaling.primaryActuatorScale = ...
        configuration.actuator.ratedTorqueNewtonMeters;
    % Alternate scale: +/-20 % per-axis rating spread (declared, mirrors
    % the source's 20 % uncertainty convention).
    configuration.scaling.alternateActuatorScale = [1.0; 0.8; 1.2];
    % Measurement-end scaling for the auxiliary F_y check (attitude, rate).
    configuration.scaling.measurementScale = ones(6, 1);

    %% Design-model truncation rule (written before any scan) ------------
    configuration.truncation.ruleDescription = ['Retain coupled (system) ' ...
        'flexible modes whose undamped natural frequency does not exceed ' ...
        'the cutoff; remove the others; no static correction.'];
    configuration.truncation.designModeCutoffRadiansPerSecond = 30;
    % A full-model valley is associated with the removed (residual) modes
    % if its frequency lies within this log-distance of a removed mode.
    configuration.truncation.residualAssociationLogWindow = 0.05;

    %% Frequency search (manuscript Sections 3.1 and 3.3) ----------------
    search.bandRadiansPerSecond = [0.1, 100];
    search.initialGridPointCount = 1500;
    % Extra grid points around every lightly damped plant mode at
    % |Im lambda|*(1 + k*zeta*offsetStep), k = -halfCount..halfCount.
    search.modalNeighbourhoodHalfCount = 6;
    search.modalNeighbourhoodOffsetStepInDampingUnits = 0.5;
    search.refinementToleranceLogFrequency = 1e-10;
    search.secondaryRefinementRelativeTolerance = 1e-12;
    search.secondaryBracketGridCells = 1.5;
    % Safety cap only: 200 golden steps shrink a bracket by about 1e-42.
    search.goldenSectionMaximumIterations = 200;
    % Safety cap only for terra.brentMinimize (golden-section steps alone
    % shrink a unit bracket to 1e-10 in 48 steps).
    search.brentMaximumIterations = 200;
    search.curvatureStepLogFrequency = 1e-4;
    search.curvatureFloor = 1e-6;
    search.valueErrorFloor = 1e-12;
    % Engineering resolution for the near-active set; the run-time value
    % is max(this, nearActiveErrorMultiplier * max valley error bound).
    search.nearActiveEngineeringResolution = 1e-3;
    search.nearActiveErrorMultiplier = 10;
    % Valleys closer than this relative frequency (model resolution) are
    % reported as unresolved.
    search.modelFrequencyResolutionRelative = 0.01;
    search.unresolvedGridCellCount = 2;
    search.repeatedSingularValueTolerance = 1e-7;
    % Frequencies evaluated per vectorized block (bounds memory, ~4 MB).
    search.evaluationChunkSize = 20000;
    configuration.search = search;

    %% Independent dense baseline (manuscript Sections 3.3 and 4.2) ------
    baseline.referenceGridPointCount = 32000;
    baseline.referenceRefinementRelativeTolerance = 1e-12;
    % Doubling ladder of plain dense grids. A sampled minimum misses the
    % true one by up to c*cell^2/8 (c = log-frequency curvature, up to about
    % 1.4e4 here), so 1e-6 can require several 1e5 points.
    baseline.denseGridLadder = 1000 * 2 .^ (0:9);
    % Equal-error target: the decision tolerance used to compare moves.
    baseline.targetMinimumValueError = decisionTolerance;
    baseline.matchFrequencyToleranceLog = 1e-3;
    baseline.matchValueTolerance = 1e-5;
    baseline.timingRepeatCount = 3;
    % Absolute bisection tolerances (path units) of the switch-location
    % reference. They do not exceed the method's root tolerances
    % (paths.switchRootTolerance), so the reported method error is not
    % limited by the reference; the evaluator noise |b_i - b_j| ~ 1e-15
    % divided by the slope difference is about 1e-12 deg, 1e-16 s and
    % 2e-13 rad/s.
    baseline.switchBisectionTolerances.panel_angle = 1e-12;
    baseline.switchBisectionTolerances.loop_delay = 1e-16;
    baseline.switchBisectionTolerances.mode3_frequency = 1e-12;
    baseline.switchBisectionMaximumIterations = 60;
    % Half-width (log frequency) of the reference branch windows used
    % while bisecting a switch; branches move far less than this.
    baseline.switchReferenceWindowLog = 0.01;
    configuration.baseline = baseline;

    %% Tail certificates outside the band --------------------------------
    configuration.tails.extensionFactor = 10;
    configuration.tails.maximumExtensionCount = 3;

    %% Parameter paths (Figure 2) ----------------------------------------
    % The model is 180-degree periodic in the drive angle (diagonal panel
    % inertia about the drive axis, centre of mass on the axis), so the
    % angle path covers one period; periodicity is verified numerically.
    paths.angularPeriodDegrees = 180;
    paths.panelAngleDegrees = 0:5:paths.angularPeriodDegrees;
    paths.delaySeconds = (1:30) * unitConstants.millisecondsToSeconds;
    % Third cantilever mode from -20 % to +20 % of nominal in 2 % steps
    % (integer percentages give identical values in MATLAB and Octave).
    thirdCantileverMode = 3;
    nominalThirdModeFrequency = ...
        configuration.structure.cantileverModeFrequenciesRadiansPerSecond(thirdCantileverMode);
    paths.mode3FrequencyRadiansPerSecond = nominalThirdModeFrequency * ...
        (80:2:120) * unitConstants.percentToFraction;
    paths.periodicityCheckAnglesDegrees = [15, 45, 90];
    paths.branchMatchGateLog = 0.15;
    paths.localBranchWindowLog = 0.05;
    % The window grows to this multiple of the branch's own frequency
    % change across the interval when that change is larger.
    paths.branchWindowGrowth = 1.5;
    % A branch is "lost" if its local optimum lies in the outer 5 % of
    % the search window (the valley left the window).
    paths.branchWindowEdgeFraction = 0.05;
    % Absolute root tolerances (path units) of the switch location. A root
    % error delta biases a one-sided secant of step h by about
    % |slope difference| * delta / h; with the smallest secant steps
    % (1e-3 deg, 1e-7 s, 1e-4 rad/s) these values keep that bias at or
    % below 1e-8 of the slope difference. terra.fzeroTolerance converts
    % them to fzero's TolX, which MATLAB applies relative to max(|x|, 1).
    paths.switchRootTolerance.panel_angle = 1e-11;
    paths.switchRootTolerance.loop_delay = 1e-16;
    paths.switchRootTolerance.mode3_frequency = 1e-12;
    paths.transversalityStep.panel_angle = 1e-3;
    paths.transversalityStep.loop_delay = 1e-6;
    paths.transversalityStep.mode3_frequency = 1e-4;
    paths.swapCheckStepMultiplier = 10;
    paths.switchEqualityTolerance = 1e-6;
    paths.minimumSlopeDifference = 1e-9;
    configuration.paths = paths;

    %% Directional derivatives (manuscript Section 3.2) ------------------
    derivatives.physicalFiniteDifferenceRelativeStep = 1e-5;
    derivatives.physicalFiniteDifferenceAbsoluteFloor = 1e-6;
    derivatives.secantStepFractions = [1, 0.3, 0.1, 0.03, 0.01];
    % Largest one-sided secant step per parameter (physical units).
    derivatives.secantBaseSteps.damping_x = 1e-3;
    derivatives.secantBaseSteps.damping_y = 1e-3;
    derivatives.secantBaseSteps.damping_z = 1e-3;
    derivatives.secantBaseSteps.rolloff_x = 0.1;
    derivatives.secantBaseSteps.rolloff_y = 0.1;
    derivatives.secantBaseSteps.rolloff_z = 0.1;
    derivatives.secantBaseSteps.panel_angle = 0.1;
    derivatives.secantBaseSteps.loop_delay = 1e-5;
    derivatives.secantBaseSteps.mode3_frequency = 0.01;
    derivatives.smoothRegionControlParameters = ...
        {'damping_x', 'rolloff_y', 'rolloff_z'};
    derivatives.smoothRegionPhysicalParameters = ...
        {'panel_angle', 'loop_delay', 'mode3_frequency'};
    derivatives.switchPointParameters = {'damping_x', 'path_parameter'};
    configuration.derivatives = derivatives;

    % Allowed variation scales h of the physical (drift-risk) parameters
    % that have no source uncertainty range; the full list, units and the
    % other scales are built by terra.parameterCatalogue.
    configuration.physicalParameters.panelAngleStepDegrees = 5;
    configuration.physicalParameters.delayStepSeconds = ...
        2 * unitConstants.millisecondsToSeconds;

    %% Remediation moves q (manuscript Section 3.2) ----------------------
    remediation.dampingStep = 0.05;
    remediation.rolloffStepRadiansPerSecond = 5;
    remediation.dampingBounds = [0.2, 1.0];
    remediation.rolloffBoundsRadiansPerSecond = [20, 80];
    remediation.screeningBudgets = [1, 2];
    remediation.primaryBudget = 2;
    % Predeclared primary screening rule for Figure 3 and Table 1, and the
    % conventional baseline it is compared with.
    remediation.primaryRule = 'branch_aware';
    remediation.conventionalRule = 'single_crossover';
    remediation.ruleNames = {'active_set', 'branch_aware', ...
        'spectrum_aware', 'single_crossover'};
    remediation.ruleDescriptions = ...
        {'paper Section 3.2: active-set D+/D- (near-active valleys)', ...
         'branch-aware: first-order prediction of every tracked valley', ...
         'spectrum-aware: every singular value at every valley', ...
         'conventional: main crossover valley only'};
    remediation.designModelRule = 'spectrum_aware';
    remediation.decisionEqualityTolerance = decisionTolerance;
    % Relative change regarded as an observable pointing difference.
    remediation.observablePointingRelativeChange = 0.01;
    configuration.remediation = remediation;

    %% Predeclared case families ----------------------------------------
    cases.angleFamilyAnglesDegrees = 0:15:configuration.paths.angularPeriodDegrees;
    cases.delayFamilyDelaysSeconds = [12, 14, 16, 18, 20, 22, 25] * ...
        unitConstants.millisecondsToSeconds;
    % Out-of-sample structural cases at the source's 20 % corners.
    cases.structuralFamilyAnglesDegrees = [0, 90];
    cases.structuralFamilyMode3Scales = [0.8, 1.2];
    cases.structuralFamilyHubInertiaScale = 0.8;
    cases.showcasePhysicalAngleDegrees = 90;
    cases.showcaseDelaySeconds = 20 * unitConstants.millisecondsToSeconds;
    configuration.cases = cases;

    %% Closed-loop stability (exact delay) -------------------------------
    % Chebyshev collocation orders N (N + 1 nodes) of the delay line; a
    % root counts only if it also appears at the second, higher order.
    stability.chebyshevOrder = 24;
    stability.chebyshevConvergenceOrder = 48;
    stability.rightmostRootRefineCount = 12;
    stability.newtonMaximumIterations = 30;
    stability.newtonStepTolerance = 1e-12;
    stability.newtonResidualTolerance = 1e-9;
    stability.rootAgreementTolerance = 1e-6;
    stability.delayMarginGridPointCount = 6000;
    stability.delayMarginRootTolerance = 1e-12;
    configuration.stability = stability;

    %% Disturbance, noise and time-domain simulation ---------------------
    response.peakSearchGridPointCount = 2400;
    response.peakRefinementToleranceLogFrequency = 1e-9;
    response.highFrequencyBandRadiansPerSecond = [32, 45];
    response.noiseIntegrationBandRadiansPerSecond = [1e-3, 1e4];
    response.noiseIntegrationGridPointCount = 6000;
    response.simulationDurationSeconds = 120;
    response.maximumTimeStepSeconds = 1e-3;
    response.disturbanceOnsetSeconds = 1.0;
    response.steadyStateWindowSeconds = 20;
    response.settlingBandFraction = 0.02;
    response.storedSampleDecimation = 20;
    configuration.response = response;

    %% Figures ------------------------------------------------------------
    figures.resolutionDotsPerInch = 300;
    figures.formats = {'png', 'eps'};
    figures.fontName = 'Helvetica';
    figures.fontSize = 9;
    figures.titleFontSize = 10;
    figures.lineWidth = 1.2;
    figures.thinLineWidth = 0.8;
    figures.markerSize = 5;
    figures.doubleColumnWidthCentimeters = 17.5;
    figures.standardHeightCentimeters = 13.0;
    figures.tallHeightCentimeters = 17.0;
    figures.pageHeightCentimeters = 22.0;
    % Panel layout in centimetres, identical in MATLAB and Octave.
    figures.layout.leftMarginCentimeters = 2.1;
    figures.layout.rightMarginCentimeters = 0.4;
    figures.layout.topMarginCentimeters = 0.8;
    figures.layout.bottomMarginCentimeters = 1.3;
    figures.layout.horizontalGapCentimeters = 2.4;
    figures.layout.verticalGapCentimeters = 2.1;
    % Legends drawn by terra.addLegendPanel: width kept free on the right
    % of the axes, gap (and inset), row height, line sample from start to
    % end and text start, measured from the legend's left edge. An inside
    % legend may take at most the given share of its axes height.
    figures.layout.legendColumnCentimeters = 4.8;
    figures.layout.legendGapCentimeters = 0.3;
    figures.layout.legendRowCentimeters = 0.45;
    figures.layout.legendSampleStartCentimeters = 0.1;
    figures.layout.legendSampleEndCentimeters = 0.9;
    figures.layout.legendTextStartCentimeters = 1.1;
    figures.layout.maximumLegendHeightFraction = 0.5;
    % Per-case axes label case 1 and every multiple of this interval.
    figures.caseLabelInterval = 5;
    % Time window shown in Figure 3 (the simulation itself is longer).
    figures.timeResponseDisplaySeconds = 30;
    % Figure 1 x-axis extends slightly beyond Omega so the edges are visible.
    figures.bandAxisMargin = 1.25;
    % Figure 3 zooms f_W on the flexible band where the valleys change.
    figures.remediationZoomBandRadiansPerSecond = [5, 60];
    figures.remediationZoomTicksRadiansPerSecond = [5, 10, 20, 40, 60];
    figures.screenPositionPixels = [80, 80, 1100, 820];
    figures.returnDifferenceAxisLimits = [0.5, 1.2];
    % Figure 1 top panels: f_W <= 1 above the rigid-body crossover, so the
    % band 1 < f_W <= 1.3 holds the legends without covering any curve.
    figures.figure1AxisLimits = [0.5, 1.3];
    figures.curveGridPointCount = 2400;
    % Branch panels (Figure 2): fixed upper limit, lower limit leaves room
    % below the envelope for the legend.
    figures.branchAxisUpperLimit = 1.0;
    figures.branchAxisLowerLimit = 0.5;
    figures.branchAxisPadding = 0.05;
    figures.legendFontReduction = 2;
    % Text placed this fraction of the axis span inside the axes.
    figures.textInsetFraction = 0.02;
    % Category (case-number) axes extend half a category beyond the data.
    figures.categoryAxisPadding = 0.5;
    % Secant panels of Figure 2: y padding as a fraction of the plotted
    % value range.
    figures.secantAxisPaddingFraction = 0.15;
    % Log step axes (Figures 2 and S3) extend this factor beyond the data
    % (keeps the end decade ticks labelled); the slope-1 guide of Figure
    % S3 lies the second factor below the data.
    figures.logAxisPaddingFactor = 1.3;
    figures.referenceSlopeOffsetFactor = 3;
    % Exact-delay root plots show roots with real part above this value.
    figures.rootPlotRealPartFloor = -1.0;
    figures.rootPlotImaginaryLimit = 45;
    figures.colors.full = [0.00, 0.30, 0.70];
    figures.colors.design = [0.85, 0.33, 0.10];
    figures.colors.envelope = [0, 0, 0];
    figures.colors.branch = [0.55, 0.70, 0.88];
    figures.colors.alternate = [0.45, 0.45, 0.45];
    figures.colors.requirement = [0.40, 0.40, 0.40];
    figures.colors.confirmed = [0.80, 0.00, 0.00];
    figures.colors.candidate = [0.95, 0.60, 0.00];
    figures.colors.unchanged = [0.20, 0.20, 0.20];
    figures.colors.baselineMove = [0.85, 0.33, 0.10];
    figures.colors.methodMove = [0.00, 0.45, 0.74];
    figures.colors.oracleMove = [0.47, 0.67, 0.19];
    figures.colors.designMove = [0.49, 0.18, 0.56];
    figures.axisColors = {[0.00, 0.45, 0.74], [0.85, 0.33, 0.10], ...
        [0.47, 0.67, 0.19]};
    configuration.figures = figures;

    %% Output -------------------------------------------------------------
    configuration.output.directoryPrefix = 'terra_results_v4';
    configuration.output.consoleProgress = true;
    configuration.output.checkpointFileName = 'checkpoint.mat';
end
