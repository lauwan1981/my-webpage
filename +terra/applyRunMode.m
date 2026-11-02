function configuration = applyRunMode(configuration, runMode)
%APPLYRUNMODE Select the study size: 'full', 'quick' or 'check'.
%   configuration = terra.applyRunMode(configuration, runMode)
%     'full'   publication run, every predeclared grid and case
%     'quick'  smoke test of the whole pipeline on reduced grids and case
%              lists; its numbers are NOT publication data
%     'check'  model self-checks only (terra.verifyModelConsistency)
%   The reduced values below are part of the declared configuration.

    unitConstants = terra.units();
    configuration.metadata.runMode = runMode;
    switch runMode
        case {'full', 'check'}
            return;
        case 'quick'
            configuration.output.directoryPrefix = [configuration.output.directoryPrefix, '_quick'];
            configuration.paths.panelAngleDegrees = 0:15:configuration.paths.angularPeriodDegrees;
            configuration.paths.delaySeconds = (2:2:30) * unitConstants.millisecondsToSeconds;
            thirdCantileverMode = 3;
            nominalThirdModeFrequency = configuration.structure. ...
                cantileverModeFrequenciesRadiansPerSecond(thirdCantileverMode);
            configuration.paths.mode3FrequencyRadiansPerSecond = nominalThirdModeFrequency * ...
                (80:10:120) * unitConstants.percentToFraction;
            configuration.cases.angleFamilyAnglesDegrees = [0, 45, 90, 135];
            configuration.cases.delayFamilyDelaysSeconds = [14, 20] * ...
                unitConstants.millisecondsToSeconds;
            configuration.cases.structuralFamilyAnglesDegrees = 90;
            configuration.cases.structuralFamilyMode3Scales = 1.2;
            configuration.baseline.referenceGridPointCount = 8000;
            configuration.baseline.denseGridLadder = 1000 * 4 .^ (0:4);
            configuration.baseline.timingRepeatCount = 1;
            configuration.derivatives.secantStepFractions = [1, 0.1, 0.01];
            configuration.response.noiseIntegrationGridPointCount = 2000;
            configuration.response.peakSearchGridPointCount = 800;
            configuration.figures.curveGridPointCount = 1200;
            configuration.response.simulationDurationSeconds = 30;
            configuration.response.steadyStateWindowSeconds = 5;
            configuration.stability.delayMarginGridPointCount = 3000;
        otherwise
            error('terra:InvalidRunMode', 'Run mode must be "full", "quick" or "check".');
    end
end
