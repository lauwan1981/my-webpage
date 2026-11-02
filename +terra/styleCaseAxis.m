function styleCaseAxis(axesHandle, configuration, cases, showAxisLabel)
%STYLECASEAXIS Category x axis of the per-case plots (Figures S1 and S2).
%   terra.styleCaseAxis(axesHandle, configuration, cases, showAxisLabel)
%   puts a tick at every case, labels case 1 and every multiple of
%   configuration.figures.caseLabelInterval (26 two-digit labels do not
%   fit side by side on a double-column panel), draws dotted separators
%   between the case families of terra.createCaseDefinitions and, when
%   showAxisLabel is true, writes an x label that gives the case-number
%   range of every family. Call it after the y limits are final; the
%   limits are frozen so that the separators do not change them.

    figures = configuration.figures;
    caseCount = numel(cases);
    caseNumbers = 1:caseCount;
    isLabelled = caseNumbers == 1 | mod(caseNumbers, figures.caseLabelInterval) == 0;
    tickLabels = repmat({''}, 1, caseCount);
    tickLabels(isLabelled) = arrayfun(@(caseNumber) sprintf('%d', caseNumber), ...
        caseNumbers(isLabelled), 'UniformOutput', false);
    set(axesHandle, 'XTick', caseNumbers, 'XTickLabel', tickLabels);
    xlim(axesHandle, [1 - figures.categoryAxisPadding, caseCount + figures.categoryAxisPadding]);

    families = {cases.family};
    lastCaseOfFamily = find(~strcmp(families(1:end - 1), families(2:end)));
    % Separators lie halfway between the last case of a family and the next case.
    separatorOffset = 0.5;
    yLimits = get(axesHandle, 'YLim');
    for lastCase = lastCaseOfFamily
        line((lastCase + separatorOffset) * [1, 1], yLimits, 'Parent', axesHandle, ...
            'LineStyle', ':', 'Color', figures.colors.requirement, ...
            'LineWidth', figures.thinLineWidth);
    end
    ylim(axesHandle, yLimits);

    if showAxisLabel
        firstCases = [1, lastCaseOfFamily + 1];
        lastCases = [lastCaseOfFamily, caseCount];
        familyTexts = cell(1, numel(firstCases));
        for familyIndex = 1:numel(firstCases)
            if firstCases(familyIndex) == lastCases(familyIndex)
                familyTexts{familyIndex} = sprintf('%d %s', firstCases(familyIndex), ...
                    families{firstCases(familyIndex)});
            else
                familyTexts{familyIndex} = sprintf('%d-%d %s', firstCases(familyIndex), ...
                    lastCases(familyIndex), families{firstCases(familyIndex)});
            end
        end
        xlabel(axesHandle, sprintf('case number (%s)', strjoin(familyTexts, ', ')));
    end
end
