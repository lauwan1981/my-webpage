function plantResponse = evaluatePlantResponse(plant, laplaceValues)
%EVALUATEPLANTRESPONSE Modal plant frequency response G(s), 3x3xN.
%   plantResponse = terra.evaluatePlantResponse(plant, laplaceValues)
%   evaluates G(s) = R0/s^2 + sum_k [R_k/(s - lambda_k) + conj(R_k)/(s -
%   conj(lambda_k))] at every complex frequency in laplaceValues (any
%   shape, typically 1i*omega). Real modes contribute a single term.
%   The sum is vectorized across frequencies; no state-space solve.

    axisCount = 3;
    laplaceRow = reshape(laplaceValues, 1, []);
    pointCount = numel(laplaceRow);
    modeCount = numel(plant.eigenvalues);

    rigidColumn = reshape(plant.rigidResidue, [], 1);
    flattenedResponse = rigidColumn * (1 ./ laplaceRow .^ 2);
    if modeCount > 0
        residueMatrix = reshape(plant.residues, axisCount * axisCount, modeCount);
        laplaceGrid = repmat(laplaceRow.', 1, modeCount);
        eigenvalueGrid = repmat(reshape(plant.eigenvalues, 1, []), pointCount, 1);
        directTerms = 1 ./ (laplaceGrid - eigenvalueGrid);
        flattenedResponse = flattenedResponse + residueMatrix * directTerms.';

        complexModes = ~plant.isReal(:)';
        if any(complexModes)
            conjugateTerms = 1 ./ (laplaceGrid(:, complexModes) - ...
                conj(eigenvalueGrid(:, complexModes)));
            flattenedResponse = flattenedResponse + ...
                conj(residueMatrix(:, complexModes)) * conjugateTerms.';
        end
    end
    plantResponse = reshape(flattenedResponse, axisCount, axisCount, pointCount);
end
