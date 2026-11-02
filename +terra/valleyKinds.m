function kinds = valleyKinds()
%VALLEYKINDS Integer codes that classify frequency-valley candidates.
%   kinds = terra.valleyKinds() returns the codes stored in
%   valleys.kinds by terra.discoverFrequencyValleys:
%       kinds.lowerEdge  lower band edge, kept as a separate candidate
%       kinds.interior   interior sampled local minimum after refinement
%       kinds.upperEdge  upper band edge, kept as a separate candidate
%   Band edges are never treated as interior stationary points
%   (manuscript Section 4.3).

    kinds.lowerEdge = -1;
    kinds.interior = 0;
    kinds.upperEdge = 1;
end
