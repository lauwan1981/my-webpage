function context = withPlant(context, plant)
%WITHPLANT Same controller, delay, scaling and grid with another plant.
%   context = terra.withPlant(context, plant) is used for mode-removal
%   counterfactuals; the evaluation kernel is rebuilt for the new plant.

    context = terra.createDiagnosticContextLike(context, plant, context.controller);
end
