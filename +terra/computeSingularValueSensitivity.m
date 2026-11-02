function sensitivity = computeSingularValueSensitivity(matrixValue, matrixDerivative, ...
        repeatedTolerance)
%COMPUTESINGULARVALUESENSITIVITY First-order change of the singular values.
%   sensitivity = terra.computeSingularValueSensitivity(matrixValue,
%   matrixDerivative, repeatedTolerance) implements manuscript Section 3.2
%   at one frequency for F~ = matrixValue and E = dF~/dp = matrixDerivative:
%     simple sigma_j:  sigma_j' = Re(u_j' E v_j)
%     repeated sigma_min (|sigma_j - sigma_min| <= tol * max(1, sigma_min))
%     with orthonormal bases U, V of the singular subspaces:
%       one-sided derivative along +d = lambda_min((U'EV + (U'EV)')/2)
%       one-sided derivative along -d = -lambda_max(same matrix)
%
%   Output fields
%       singularValues (3x1, descending), slopes (3x1, simple formula),
%       isRepeatedMinimum, minimumSlopePositive, minimumSlopeNegative

    [leftVectors, singularMatrix, rightVectors] = svd(matrixValue);
    singularValues = diag(singularMatrix);
    projected = leftVectors' * matrixDerivative * rightVectors;
    slopes = real(diag(projected));
    minimumValue = singularValues(end);
    repeatedSet = find(abs(singularValues - minimumValue) <= ...
        repeatedTolerance * max(1, minimumValue));

    sensitivity.singularValues = singularValues;
    sensitivity.slopes = slopes;
    sensitivity.isRepeatedMinimum = numel(repeatedSet) > 1;
    if sensitivity.isRepeatedMinimum
        subspaceBlock = projected(repeatedSet, repeatedSet);
        hermitianPart = (subspaceBlock + subspaceBlock') / 2;
        eigenvalues = real(eig(hermitianPart));
        sensitivity.minimumSlopePositive = min(eigenvalues);
        sensitivity.minimumSlopeNegative = -max(eigenvalues);
    else
        sensitivity.minimumSlopePositive = slopes(end);
        sensitivity.minimumSlopeNegative = -slopes(end);
    end
end
