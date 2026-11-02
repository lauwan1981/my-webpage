function rootSummary = computeDelaySystemRoots(interconnection, delaySeconds, stabilitySettings)
%COMPUTEDELAYSYSTEMROOTS Rightmost characteristic roots with exact delay.
%   rootSummary = terra.computeDelaySystemRoots(interconnection, delaySeconds,
%   stabilitySettings) computes the rightmost roots of
%       det( lambda I - A - B_v C_u exp(-lambda tau) ) = 0
%   (i.e. of x' = A x + B_v C_u x(t - tau)) in two steps:
%     1. pseudospectral (Chebyshev collocation) discretization of the
%        transport equation that carries the command through the delay,
%        at two orders N1 < N2, as in Breda, Maset and Vermiglio,
%        SIAM J. Sci. Comput. 27(2):482-495, 2005;
%     2. Newton refinement of each candidate on the exact nonlinear
%        eigenproblem M(lambda) v = 0 with normalization c' v = 1
%        (bordered Newton, Ruhe 1973), M(lambda) = lambda I - A -
%        B_v C_u exp(-lambda tau).
%   A root is "verified" when Newton converges, the relative residual
%   sigma_min(M)/sigma_max(M) is small and the root also appears in the
%   lower-order discretization. Zero delay uses eig of the closed loop.
%
%   Output fields
%       delaySeconds, method, verifiedRoots, maximumVerifiedRealPart,
%       candidateRoots, isVerified, residuals, unverifiedCount,
%       discretizationOrders

    rootSummary.delaySeconds = delaySeconds;
    if delaySeconds == 0
        eigenvalues = eig(interconnection.zeroDelayClosedLoopMatrix);
        rootSummary.method = 'eig (zero delay, exact)';
        rootSummary.verifiedRoots = sortByRealPart(eigenvalues);
        rootSummary.maximumVerifiedRealPart = max(real(eigenvalues));
        rootSummary.candidateRoots = rootSummary.verifiedRoots;
        rootSummary.isVerified = true(size(rootSummary.verifiedRoots));
        rootSummary.residuals = zeros(size(rootSummary.verifiedRoots));
        rootSummary.unverifiedCount = 0;
        rootSummary.discretizationOrders = [];
        return;
    end

    lowOrder = stabilitySettings.chebyshevOrder;
    highOrder = stabilitySettings.chebyshevConvergenceOrder;
    lowOrderRoots = eig(buildDiscretizedGenerator(interconnection, delaySeconds, lowOrder));
    highOrderRoots = sortByRealPart(eig(buildDiscretizedGenerator(interconnection, ...
        delaySeconds, highOrder)));

    candidateCount = min(stabilitySettings.rightmostRootRefineCount, numel(highOrderRoots));
    candidates = highOrderRoots(1:candidateCount);
    refinedRoots = zeros(candidateCount, 1);
    residuals = inf(candidateCount, 1);
    isVerified = false(candidateCount, 1);
    for candidateIndex = 1:candidateCount
        [refinedRoots(candidateIndex), residuals(candidateIndex), hasConverged] = ...
            refineCharacteristicRoot(interconnection, delaySeconds, ...
            candidates(candidateIndex), stabilitySettings);
        appearsAtLowOrder = min(abs(lowOrderRoots - refinedRoots(candidateIndex))) <= ...
            stabilitySettings.rootAgreementTolerance * max(1, abs(refinedRoots(candidateIndex)));
        isVerified(candidateIndex) = hasConverged && appearsAtLowOrder && ...
            residuals(candidateIndex) <= stabilitySettings.newtonResidualTolerance;
    end

    verified = refinedRoots(isVerified);
    rootSummary.method = sprintf(['Chebyshev collocation N=%d/%d + bordered Newton on ' ...
        'M(lambda) v = 0'], lowOrder, highOrder);
    rootSummary.verifiedRoots = sortByRealPart(uniqueRoots(verified, ...
        stabilitySettings.rootAgreementTolerance));
    if isempty(rootSummary.verifiedRoots)
        rootSummary.maximumVerifiedRealPart = NaN;
    else
        rootSummary.maximumVerifiedRealPart = max(real(rootSummary.verifiedRoots));
    end
    rootSummary.candidateRoots = candidates;
    rootSummary.isVerified = isVerified;
    rootSummary.residuals = residuals;
    rootSummary.unverifiedCount = sum(~isVerified);
    rootSummary.discretizationOrders = [lowOrder, highOrder];
end

function generator = buildDiscretizedGenerator(interconnection, delaySeconds, chebyshevOrder)
%BUILDDISCRETIZEDGENERATOR Collocated delay line w(t, theta) = u(t + theta).
%   chebyshevOrder N gives N + 1 nodes theta_j = tau (x_j - 1)/2 on
%   [-tau, 0]; w_0 = u = C_u x is the inflow boundary, w_N = u(t - tau)
%   drives the wheels through B_v.
    [differentiationMatrix, ~] = terra.chebyshevDifferentiationMatrix(chebyshevOrder);
    derivativeScale = 2 / delaySeconds;
    commandCount = size(interconnection.commandOutput, 1);
    stateCount = interconnection.stateCount;

    toBoundary = derivativeScale * kron(differentiationMatrix(2:end, 1), ...
        interconnection.commandOutput);
    alongLine = derivativeScale * kron(differentiationMatrix(2:end, 2:end), ...
        eye(commandCount));
    delayedCoupling = [zeros(stateCount, (chebyshevOrder - 1) * commandCount), ...
        interconnection.delayedCommandInput];
    generator = [interconnection.stateMatrix, delayedCoupling; toBoundary, alongLine];
end

function [root, residual, hasConverged] = refineCharacteristicRoot( ...
        interconnection, delaySeconds, initialGuess, stabilitySettings)
%REFINECHARACTERISTICROOT Bordered Newton iteration for M(lambda) v = 0.
%   Unknowns (v, lambda) with normalization c' v = 1; the bordered
%   Jacobian [M, M' v; c', 0] stays nonsingular at a simple root, so no
%   singular solve is needed (Ruhe, SIAM J. Numer. Anal. 10(4), 1973).
    stateCount = interconnection.stateCount;
    identityMatrix = eye(stateCount);
    delayedLoop = interconnection.delayedCommandInput * interconnection.commandOutput;
    root = initialGuess;
    [~, ~, rightSingularVectors] = svd(characteristicMatrix(interconnection, ...
        delayedLoop, delaySeconds, root));
    eigenvector = rightSingularVectors(:, end);
    normalization = eigenvector';
    hasConverged = false;
    for iteration = 1:stabilitySettings.newtonMaximumIterations
        matrixValue = characteristicMatrix(interconnection, delayedLoop, delaySeconds, root);
        derivativeValue = identityMatrix + delaySeconds * delayedLoop * ...
            exp(-root * delaySeconds);
        jacobian = [matrixValue, derivativeValue * eigenvector; normalization, 0];
        residualVector = [matrixValue * eigenvector; normalization * eigenvector - 1];
        update = -(jacobian \ residualVector);
        if any(~isfinite(update))
            break;
        end
        eigenvector = eigenvector + update(1:stateCount);
        newtonStep = update(end);
        root = root + newtonStep;
        if abs(newtonStep) <= stabilitySettings.newtonStepTolerance * max(1, abs(root))
            hasConverged = true;
            break;
        end
    end
    singularValues = svd(characteristicMatrix(interconnection, delayedLoop, ...
        delaySeconds, root));
    residual = singularValues(end) / singularValues(1);
end

function value = characteristicMatrix(interconnection, delayedLoop, delaySeconds, lambda)
%CHARACTERISTICMATRIX M(lambda) = lambda I - A - B_v C_u exp(-lambda tau).
    value = lambda * eye(interconnection.stateCount) - interconnection.stateMatrix - ...
        delayedLoop * exp(-lambda * delaySeconds);
end

function sortedRoots = sortByRealPart(rootValues)
%SORTBYREALPART Rightmost first.
    [~, order] = sort(real(rootValues), 'descend');
    sortedRoots = rootValues(order);
end

function distinctRoots = uniqueRoots(rootValues, tolerance)
%UNIQUEROOTS Merge roots that Newton mapped onto the same solution.
    distinctRoots = zeros(0, 1);
    for rootIndex = 1:numel(rootValues)
        candidate = rootValues(rootIndex);
        if isempty(distinctRoots) || ...
                min(abs(distinctRoots - candidate)) > tolerance * max(1, abs(candidate))
            distinctRoots(end + 1, 1) = candidate; %#ok<AGROW>
        end
    end
end
