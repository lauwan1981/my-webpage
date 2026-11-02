function exportStudyFigure(figureHandle, directory, baseName, configuration)
%EXPORTSTUDYFIGURE Write one figure in every declared format and close it.
%   terra.exportStudyFigure(figureHandle, directory, baseName,
%   configuration) prints <baseName>.png at the declared resolution and
%   <baseName>.eps, then closes the figure. The painters renderer is
%   selected first so that MATLAB writes true vector EPS (it may switch
%   to an embedded bitmap for complex figures otherwise).

    figures = configuration.figures;
    set(figureHandle, 'Renderer', 'painters');
    resolutionFlag = sprintf('-r%d', figures.resolutionDotsPerInch);
    for formatIndex = 1:numel(figures.formats)
        switch figures.formats{formatIndex}
            case 'png'
                print(figureHandle, fullfile(directory, [baseName, '.png']), '-dpng', resolutionFlag);
            case 'eps'
                print(figureHandle, fullfile(directory, [baseName, '.eps']), '-depsc');
            otherwise
                error('terra:FigureFormat', 'Unsupported figure format "%s".', ...
                    figures.formats{formatIndex});
        end
    end
    close(figureHandle);
end
