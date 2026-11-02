function summary = summarizeRemediation(results)
%SUMMARIZEREMEDIATION Statistics of every screening rule per case family.
%   summary = terra.summarizeRemediation(results) returns a struct array
%   with fields family ('all', 'angle', 'delay', 'structural'), rule,
%   budget, caseCount, matchCount (regret within the decision tolerance),
%   worstRegret, meanRegret, medianEvaluations, medianSeconds and
%   medianCostFraction (accounted time / time of verifying every move).

    remediation = results.configuration.remediation;
    caseResults = results.caseResults;
    families = [{'all'}, reshape(unique({caseResults.family}), 1, [])];
    summary = struct('family', {}, 'rule', {}, 'budget', {}, 'caseCount', {}, ...
        'matchCount', {}, 'worstRegret', {}, 'meanRegret', {}, 'medianEvaluations', {}, ...
        'medianSeconds', {}, 'medianCostFraction', {});
    for familyIndex = 1:numel(families)
        family = families{familyIndex};
        if strcmp(family, 'all')
            members = caseResults;
        else
            members = caseResults(strcmp({caseResults.family}, family));
        end
        for ruleIndex = 1:numel(remediation.ruleNames)
            for budget = remediation.screeningBudgets
                fieldName = sprintf('%s_top%d', remediation.ruleNames{ruleIndex}, budget);
                regrets = zeros(1, numel(members));
                evaluations = zeros(1, numel(members));
                accountedSeconds = zeros(1, numel(members));
                fractions = zeros(1, numel(members));
                for memberIndex = 1:numel(members)
                    selection = members(memberIndex).selections.(fieldName);
                    regrets(memberIndex) = selection.regret;
                    evaluations(memberIndex) = selection.accountedEvaluations;
                    accountedSeconds(memberIndex) = selection.accountedSeconds;
                    fractions(memberIndex) = selection.accountedSeconds / ...
                        members(memberIndex).costs.exhaustiveSeconds;
                end
                record.family = family;
                record.rule = remediation.ruleNames{ruleIndex};
                record.budget = budget;
                record.caseCount = numel(members);
                record.matchCount = sum(abs(regrets) <= remediation.decisionEqualityTolerance);
                record.worstRegret = max(regrets);
                record.meanRegret = mean(regrets);
                record.medianEvaluations = median(evaluations);
                record.medianSeconds = median(accountedSeconds);
                record.medianCostFraction = median(fractions);
                summary(end + 1) = record; %#ok<AGROW>
            end
        end
    end
end
