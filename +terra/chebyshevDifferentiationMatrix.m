function [differentiationMatrix, nodes] = chebyshevDifferentiationMatrix(chebyshevOrder)
%CHEBYSHEVDIFFERENTIATIONMATRIX Chebyshev collocation derivative on [-1, 1].
%   [differentiationMatrix, nodes] = terra.chebyshevDifferentiationMatrix(
%   chebyshevOrder) returns, for order N = chebyshevOrder (N intervals,
%   N + 1 nodes), the (N+1)x(N+1) differentiation matrix on the Chebyshev
%   extreme points x_j = cos(j*pi/N), j = 0..N (x_0 = 1, x_N = -1),
%   following L. N. Trefethen, Spectral Methods in MATLAB, SIAM 2000,
%   program cheb.m. The diagonal uses the negative-sum trick.

    if chebyshevOrder < 1
        error('terra:ChebyshevOrder', 'The Chebyshev order must be at least 1.');
    end
    nodeCount = chebyshevOrder + 1;
    nodes = cos(pi * (0:chebyshevOrder)' / chebyshevOrder);
    % End nodes carry weight 2, interior nodes weight 1, with alternating sign.
    endpointWeight = 2;
    endpointWeights = [endpointWeight; ones(chebyshevOrder - 1, 1); endpointWeight] .* ...
        ((-1) .^ (0:chebyshevOrder)');
    nodeGrid = repmat(nodes, 1, nodeCount);
    nodeDifferences = nodeGrid - nodeGrid';
    differentiationMatrix = (endpointWeights * (1 ./ endpointWeights)') ./ ...
        (nodeDifferences + eye(nodeCount));
    differentiationMatrix = differentiationMatrix - ...
        diag(sum(differentiationMatrix, 2));
end
