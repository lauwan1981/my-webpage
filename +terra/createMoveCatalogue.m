function moves = createMoveCatalogue(configuration)
%CREATEMOVECATALOGUE Predeclared single-parameter controller moves.
%   moves = terra.createMoveCatalogue(configuration) returns 12 moves:
%   damping_x/y/z and rolloff_x/y/z, each in the + and - direction, with
%   the declared step sizes h_i. Field code reproduces the v3 move codes
%   (+-1..3 damping, +-4..6 roll-off) so results stay comparable.
%
%   Fields: code, parameterName, direction (+1/-1), stepSize, label

    catalogue = terra.parameterCatalogue(configuration);
    controlEntries = catalogue(strcmp({catalogue.group}, 'control'));
    moveCount = 2 * numel(controlEntries);
    moves = repmat(struct('code', 0, 'parameterName', '', 'direction', 0, ...
        'stepSize', 0, 'label', ''), moveCount, 1);
    moveIndex = 0;
    for parameterIndex = 1:numel(controlEntries)
        for direction = [1, -1]
            moveIndex = moveIndex + 1;
            moves(moveIndex).code = direction * parameterIndex;
            moves(moveIndex).parameterName = controlEntries(parameterIndex).name;
            moves(moveIndex).direction = direction;
            moves(moveIndex).stepSize = controlEntries(parameterIndex).stepSize;
            moves(moveIndex).label = sprintf('%s %s%g', ...
                controlEntries(parameterIndex).name, signCharacter(direction), ...
                controlEntries(parameterIndex).stepSize);
        end
    end
end

function character = signCharacter(direction)
%SIGNCHARACTER '+' or '-' for display.
    if direction > 0
        character = '+';
    else
        character = '-';
    end
end
