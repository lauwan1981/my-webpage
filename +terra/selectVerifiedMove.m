function [selectedPosition, selectedValue] = selectVerifiedMove(predictedValues, ...
        verifiedValues, budget, unchangedValue)
%SELECTVERIFIEDMOVE Screen by prediction, verify the top candidates.
%   [selectedPosition, selectedValue] = terra.selectVerifiedMove(
%   predictedValues, verifiedValues, budget, unchangedValue) ranks moves
%   by predicted margin (descending), recomputes ("verifies") only the
%   first `budget` of them and keeps the best verified result, including
%   the option of not changing the controller. selectedPosition is 0 when
%   no verified move beats unchangedValue. NaN predictions rank last.

    rankingKeys = predictedValues(:);
    rankingKeys(isnan(rankingKeys)) = -Inf;
    [~, ranking] = sort(rankingKeys, 'descend');
    selectedPosition = 0;
    selectedValue = unchangedValue;
    for rankIndex = 1:min(budget, numel(ranking))
        position = ranking(rankIndex);
        if verifiedValues(position) > selectedValue
            selectedValue = verifiedValues(position);
            selectedPosition = position;
        end
    end
end
