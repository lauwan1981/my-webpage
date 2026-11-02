function modeSelection = selectDesignModes(spacecraftModel, configuration)
%SELECTDESIGNMODES Apply the predeclared truncation rule (Section 2.1(3)).
%   modeSelection = terra.selectDesignModes(spacecraftModel,
%   configuration) partitions the system modes into the disjoint sets
%   M_des (retained in the design model G_des) and M_res (residual,
%   G_res = G_full - G_des). The rule is the frequency cutoff in
%   configuration.truncation; no static correction is applied, so the
%   decomposition G_full = G_des + G_res is exactly additive.
%
%   Output fields
%       allIndices       indices of every system mode (full model)
%       designIndices    M_des
%       residualIndices  M_res
%       residualFrequencies  natural frequencies of M_res (rad/s)
%       ruleDescription  text copied into tables and figure notes

    naturalFrequencies = spacecraftModel.systemModes.naturalFrequencies;
    cutoff = configuration.truncation.designModeCutoffRadiansPerSecond;
    allIndices = (1:numel(naturalFrequencies))';
    isRetained = naturalFrequencies <= cutoff;

    modeSelection.allIndices = allIndices;
    modeSelection.designIndices = allIndices(isRetained);
    modeSelection.residualIndices = allIndices(~isRetained);
    modeSelection.residualFrequencies = naturalFrequencies(~isRetained);
    modeSelection.ruleDescription = sprintf('%s Cutoff %.4g rad/s.', ...
        configuration.truncation.ruleDescription, cutoff);
end
