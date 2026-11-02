function roles = figureRoles()
%FIGUREROLES Order and names of the three controllers compared in Figure 3.
%   roles = terra.figureRoles() returns the positions used in every
%   per-showcase array of terra.runShowcaseExperiments and
%   terra.plotRemediationFigure:
%       roles.unchanged     nominal controller
%       roles.conventional  decision of the single-main-crossover rule
%       roles.method        decision of the active-branch (primary) rule
%   plus roles.count and roles.names (display names in that order).

    roles.unchanged = 1;
    roles.conventional = 2;
    roles.method = 3;
    roles.count = 3;
    roles.names = {'unchanged', 'conventional single-crossover', 'active-branch method'};
end
