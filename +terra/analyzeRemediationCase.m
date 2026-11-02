function result = analyzeRemediationCase(configuration, caseDefinition, moves)
%ANALYZEREMEDIATIONCASE Diagnose one case and compare remediation rules.
%   result = terra.analyzeRemediationCase(configuration, caseDefinition,
%   moves) runs, for one frozen configuration (manuscript Sections 3.2,
%   3.3 and 4.1-4.3):
%     1. full and design models with the same controller, stability of
%        both closed loops with the exact delay;
%     2. full-band valley discovery on both models;
%     3. first-order predictions of all moves for four screening rules
%        (terra.computeEnvelopeSensitivity) plus the design-model rule;
%     4. exhaustive verification of every move on the full model (for
%        benchmarking only) and Top-k selections with equal budgets;
%     5. stability and engineering responses of every distinct decision;
%     6. the three residual-dynamics levels of Section 4.3: residual
%        valley in the active set / changes the decision / changes the
%        pointing response observably.
%   Costs are accounted from measured component times on the same run.

    primaryScale = configuration.scaling.primaryActuatorScale;
    remediation = configuration.remediation;
    controller = terra.nominalController(configuration);
    operatingPoint = caseDefinition.operatingPoint;
    ruleNames = remediation.ruleNames;
    moveCount = numel(moves);

    %% Models, stability and discovery ------------------------------------------
    modelTimer = tic;
    fullContext = terra.createOperatingContext(configuration, operatingPoint, ...
        controller, 'full', primaryScale);
    designContext = terra.createOperatingContext(configuration, operatingPoint, ...
        controller, 'design', primaryScale);
    modelSeconds = toc(modelTimer);

    stabilityFull = terra.assessClosedLoopStability(fullContext.plant, controller, ...
        configuration, operatingPoint.delaySeconds);
    stabilityDesign = terra.assessClosedLoopStability(designContext.plant, controller, ...
        configuration, operatingPoint.delaySeconds);

    discoveryTimer = tic;
    fullValleys = terra.runAdaptiveDiscovery(fullContext);
    discoverySeconds = toc(discoveryTimer);
    designValleys = terra.runAdaptiveDiscovery(designContext);
    crossover = terra.findMainCrossover(fullContext, fullValleys);
    designCrossover = terra.findMainCrossover(designContext, designValleys);

    %% First-order predictions --------------------------------------------------
    sensitivityTimer = tic;
    predictions = nan(moveCount, numel(ruleNames));
    [predictions, fullSensitivities] = predictMoves(fullContext, fullValleys, moves, ...
        crossover.valleyIndex, ruleNames, predictions);
    sensitivitySeconds = toc(sensitivityTimer);
    designPredictions = nan(moveCount, numel(ruleNames));
    designPredictions = predictMoves(designContext, designValleys, moves, ...
        designCrossover.valleyIndex, ruleNames, designPredictions);

    %% Exhaustive verification (benchmark only) ------------------------------------
    verifiedValues = -Inf(moveCount, 1);
    isFeasible = false(moveCount, 1);
    verificationSeconds = zeros(moveCount, 1);
    verificationEvaluations = zeros(moveCount, 1);
    for moveIndex = 1:moveCount
        [movedController, isFeasible(moveIndex)] = terra.applyControllerMove(controller, ...
            moves(moveIndex), configuration);
        if ~isFeasible(moveIndex)
            predictions(moveIndex, :) = NaN;
            continue;
        end
        verificationTimer = tic;
        movedValleys = terra.runAdaptiveDiscovery(terra.withController(fullContext, movedController));
        verificationSeconds(moveIndex) = toc(verificationTimer);
        verificationEvaluations(moveIndex) = movedValleys.evaluationCount;
        verifiedValues(moveIndex) = movedValleys.minimumValue;
    end
    % Infeasible moves (outside the declared bounds) can be chosen by no rule.
    designPredictions(~isFeasible, :) = NaN;
    unchangedValue = fullValleys.minimumValue;
    [oraclePosition, oracleValue] = terra.selectVerifiedMove((1:moveCount)', ...
        verifiedValues, moveCount, unchangedValue);

    %% Equal-budget selections -------------------------------------------------------
    budgets = remediation.screeningBudgets;
    selections = struct();
    for ruleIndex = 1:numel(ruleNames)
        ruleName = ruleNames{ruleIndex};
        for budget = budgets
            [position, value] = terra.selectVerifiedMove(predictions(:, ruleIndex), ...
                verifiedValues, budget, unchangedValue);
            fieldName = sprintf('%s_top%d', ruleName, budget);
            selections.(fieldName) = selectionRecord(position, value, oracleValue, moves, ...
                predictions(:, ruleIndex), budget, discoverySeconds + sensitivitySeconds, ...
                verificationSeconds, fullValleys.evaluationCount, verificationEvaluations);
        end
    end
    exhaustiveSeconds = discoverySeconds + sum(verificationSeconds);
    exhaustiveEvaluations = fullValleys.evaluationCount + sum(verificationEvaluations);

    %% Design-model decision (residual dynamics ignored) -------------------------------
    designRuleIndex = find(strcmp(ruleNames, remediation.designModelRule));
    [~, designRanking] = sort(nanToMinusInf(designPredictions(:, designRuleIndex)), 'descend');
    designVerified = -Inf(moveCount, 1);
    for rankIndex = 1:min(remediation.primaryBudget, moveCount)
        moveIndex = designRanking(rankIndex);
        [movedController, feasible] = terra.applyControllerMove(controller, ...
            moves(moveIndex), configuration);
        if feasible
            movedValleys = terra.runAdaptiveDiscovery( ...
                terra.withController(designContext, movedController));
            designVerified(moveIndex) = movedValleys.minimumValue;
        end
    end
    [designPosition, designModelValue] = terra.selectVerifiedMove( ...
        designPredictions(:, designRuleIndex), designVerified, remediation.primaryBudget, ...
        designValleys.minimumValue);
    designDecision.position = designPosition;
    designDecision.code = moveCode(moves, designPosition);
    designDecision.designModelValue = designModelValue;
    designDecision.fullModelValue = valueOfPosition(designPosition, verifiedValues, unchangedValue);

    %% Engineering consequences of every distinct decision ------------------------------
    primaryField = sprintf('%s_top%d', remediation.primaryRule, remediation.primaryBudget);
    conventionalField = sprintf('%s_top%d', remediation.conventionalRule, ...
        remediation.primaryBudget);
    decisionPositions = unique([0, selections.(primaryField).position, ...
        selections.(conventionalField).position, oraclePosition, designPosition]);
    evaluated = struct('position', {}, 'code', {}, 'label', {}, 'bandMinimum', {}, ...
        'stability', {}, 'metrics', {});
    for position = decisionPositions
        movedController = controller;
        if position > 0
            movedController = terra.applyControllerMove(controller, moves(position), configuration);
        end
        record.position = position;
        record.code = moveCode(moves, position);
        record.label = moveLabel(moves, position);
        record.bandMinimum = valueOfPosition(position, verifiedValues, unchangedValue);
        record.stability = compactStability(terra.assessClosedLoopStability( ...
            fullContext.plant, movedController, configuration, operatingPoint.delaySeconds));
        record.metrics = terra.evaluateResponseMetrics(fullContext.plant, movedController, ...
            configuration, operatingPoint.delaySeconds);
        evaluated(end + 1) = record; %#ok<AGROW>
    end

    %% Residual-dynamics levels (manuscript Section 4.3) -------------------------------
    % Level 1: a near-active valley lies at a removed (residual) mode.
    residualFrequencies = fullContext.modeSelection.residualFrequencies;
    associationWindow = configuration.truncation.residualAssociationLogWindow;
    levels.activeValleyFrequency = fullValleys.minimumFrequency;
    levels.nearestResidualLogDistance = residualLogDistance(residualFrequencies, ...
        fullValleys.minimumFrequency);
    levels.residualValleyIsBandMinimum = levels.nearestResidualLogDistance <= associationWindow;
    activeDistances = zeros(1, numel(fullValleys.activeIndices));
    for activePosition = 1:numel(fullValleys.activeIndices)
        activeDistances(activePosition) = residualLogDistance(residualFrequencies, ...
            fullValleys.frequencies(fullValleys.activeIndices(activePosition)));
    end
    levels.residualValleyActive = any(activeDistances <= associationWindow);
    primaryPosition = selections.(primaryField).position;
    levels.decisionChanged = designPosition ~= primaryPosition && ...
        abs(designDecision.fullModelValue - selections.(primaryField).value) > ...
        remediation.decisionEqualityTolerance;
    primaryMetrics = evaluated([evaluated.position] == primaryPosition).metrics;
    designMetrics = evaluated([evaluated.position] == designPosition).metrics;
    levels.pointingRelativeChange = relativeChange(designMetrics, primaryMetrics);
    levels.pointingChangeObservable = levels.pointingRelativeChange > ...
        remediation.observablePointingRelativeChange;

    %% Assemble ----------------------------------------------------------------------------
    result.label = caseDefinition.label;
    result.family = caseDefinition.family;
    result.operatingPoint = operatingPoint;
    result.fullSummary = terra.summarizeValleys(fullValleys);
    result.designSummary = terra.summarizeValleys(designValleys);
    result.fullValleys = fullValleys;
    result.designValleys = designValleys;
    result.residualFrequencies = residualFrequencies;
    result.crossover = crossover;
    result.stabilityFull = compactStability(stabilityFull);
    result.stabilityDesign = compactStability(stabilityDesign);
    result.fullSensitivities = fullSensitivities;
    result.predictions = predictions;
    result.designPredictions = designPredictions;
    result.verifiedValues = verifiedValues;
    result.isFeasible = isFeasible;
    result.oracle.position = oraclePosition;
    result.oracle.code = moveCode(moves, oraclePosition);
    result.oracle.value = oracleValue;
    result.selections = selections;
    result.primaryField = primaryField;
    result.conventionalField = conventionalField;
    result.designDecision = designDecision;
    result.evaluatedDecisions = evaluated;
    result.levels = levels;
    result.costs.modelSeconds = modelSeconds;
    result.costs.discoverySeconds = discoverySeconds;
    result.costs.sensitivitySeconds = sensitivitySeconds;
    result.costs.verificationSeconds = verificationSeconds;
    result.costs.verificationEvaluations = verificationEvaluations;
    result.costs.exhaustiveSeconds = exhaustiveSeconds;
    result.costs.exhaustiveEvaluations = exhaustiveEvaluations;
end

function [predictions, sensitivities] = predictMoves(context, valleys, moves, ...
        crossoverIndex, ruleNames, predictions)
%PREDICTMOVES Fill the (move x rule) prediction matrix.
    parameterNames = unique({moves.parameterName});
    sensitivities = struct();
    for parameterIndex = 1:numel(parameterNames)
        parameterName = parameterNames{parameterIndex};
        moveIndices = find(strcmp({moves.parameterName}, parameterName));
        stepSize = moves(moveIndices(1)).stepSize;
        sensitivity = terra.computeEnvelopeSensitivity(context, valleys, parameterName, ...
            stepSize, crossoverIndex);
        sensitivities.(parameterName) = sensitivity;
        for moveIndex = moveIndices
            for ruleIndex = 1:numel(ruleNames)
                rulePrediction = sensitivity.predictions.(ruleNames{ruleIndex});
                if moves(moveIndex).direction > 0
                    predictions(moveIndex, ruleIndex) = rulePrediction.positive;
                else
                    predictions(moveIndex, ruleIndex) = rulePrediction.negative;
                end
            end
        end
    end
end

function record = selectionRecord(position, value, oracleValue, moves, rulePredictions, ...
        budget, screeningSeconds, verificationSeconds, discoveryEvaluations, ...
        verificationEvaluations)
%SELECTIONRECORD Decision, regret and accounted cost of one rule/budget.
    [~, ranking] = sort(nanToMinusInf(rulePredictions), 'descend');
    verifiedPositions = ranking(1:min(budget, numel(ranking)));
    record.position = position;
    record.code = moveCode(moves, position);
    record.value = value;
    record.regret = oracleValue - value;
    record.accountedSeconds = screeningSeconds + sum(verificationSeconds(verifiedPositions));
    record.accountedEvaluations = discoveryEvaluations + ...
        sum(verificationEvaluations(verifiedPositions));
end

function code = moveCode(moves, position)
%MOVECODE v3-compatible code, 0 for "unchanged".
    if position == 0
        code = 0;
    else
        code = moves(position).code;
    end
end

function label = moveLabel(moves, position)
%MOVELABEL Display label of a move.
    if position == 0
        label = 'unchanged';
    else
        label = moves(position).label;
    end
end

function value = valueOfPosition(position, verifiedValues, unchangedValue)
%VALUEOFPOSITION Verified full-model band minimum of a decision.
    if position == 0
        value = unchangedValue;
    else
        value = verifiedValues(position);
    end
end

function keys = nanToMinusInf(values)
%NANTOMINUSINF Rank NaN predictions last.
    keys = values;
    keys(isnan(keys)) = -Inf;
end

function distance = residualLogDistance(residualFrequencies, valleyFrequency)
%RESIDUALLOGDISTANCE Log-frequency distance of a valley to the nearest removed mode.
    if isempty(residualFrequencies)
        distance = Inf;
    else
        distance = min(abs(log(residualFrequencies / valleyFrequency)));
    end
end

function compact = compactStability(stability)
%COMPACTSTABILITY Drop large arrays, keep the decisive numbers.
    compact.status = stability.status;
    compact.zeroDelayMaximumRealPart = stability.zeroDelayMaximumRealPart;
    compact.delayMarginSeconds = stability.delayMarginSeconds;
    compact.criticalFrequency = stability.delayMargin.criticalFrequency;
    compact.isBandCertified = stability.delayMargin.isBandCertified;
    compact.rightmostRealPart = stability.rightmostRealPart;
    if isfield(stability.roots, 'verifiedRoots') && ~isempty(stability.roots.verifiedRoots)
        compact.rightmostRoot = stability.roots.verifiedRoots(1);
        compact.unverifiedRootCount = stability.roots.unverifiedCount;
    else
        compact.rightmostRoot = NaN;
        compact.unverifiedRootCount = NaN;
    end
    compact.stateCount = stability.stateCount;
end

function change = relativeChange(firstMetrics, secondMetrics)
%RELATIVECHANGE Largest relative change of the pointing indicators.
    firstValues = [firstMetrics.peakPointingGain; firstMetrics.noisePointingRmsRadians(:); ...
        firstMetrics.highBandPointingGain];
    secondValues = [secondMetrics.peakPointingGain; secondMetrics.noisePointingRmsRadians(:); ...
        secondMetrics.highBandPointingGain];
    change = max(abs(firstValues - secondValues) ./ max(abs(secondValues), realmin));
end
