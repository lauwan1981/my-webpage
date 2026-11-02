function plotStudyFigures(results)
%PLOTSTUDYFIGURES Produce every figure of the study in results.outputDirectory/figures.
%   terra.plotStudyFigures(results) writes
%     Fig1_return_difference       full vs design f_W, all candidates, E_res
%     Fig2_branches_switches       branches, envelope, switches, one-sided secants
%     Fig3_remediation             unchanged / conventional / active-branch
%                                  responses, or the cost comparison when the
%                                  decisions do not differ verifiably
%     FigS1_cost_comparison        equal-error cost per case (Table 2)
%     FigS2_decisions              band minima of every decision rule per case
%     FigS3_derivative_convergence smooth-region secant error convergence
%     FigS4_residual_mode_path     residual-mode path and delay margins
%   plus figure_captions.txt with the caption facts required by Section 4.2.

    figureDirectory = fullfile(results.outputDirectory, 'figures');
    if exist(figureDirectory, 'dir') ~= 7
        mkdir(figureDirectory);
    end
    captions = {};
    captions{end + 1} = terra.plotReturnDifferenceFigure(results, figureDirectory);
    captions{end + 1} = terra.plotBranchFigure(results, figureDirectory);
    captions{end + 1} = terra.plotRemediationFigure(results, figureDirectory);
    captions{end + 1} = terra.plotCostFigure(results, figureDirectory);
    captions{end + 1} = terra.plotDecisionFigure(results, figureDirectory);
    captions{end + 1} = terra.plotDerivativeConvergenceFigure(results, figureDirectory);
    captions{end + 1} = terra.plotResidualPathFigure(results, figureDirectory);

    fileIdentifier = fopen(fullfile(figureDirectory, 'figure_captions.txt'), 'wt');
    if fileIdentifier < 0
        error('terra:OutputFile', 'Cannot write the figure captions.');
    end
    closer = onCleanup(@() fclose(fileIdentifier)); %#ok<NASGU>
    for captionIndex = 1:numel(captions)
        fprintf(fileIdentifier, '%s\n\n', captions{captionIndex});
    end
end
