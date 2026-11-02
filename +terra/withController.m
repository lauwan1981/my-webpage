function context = withController(context, controller)
%WITHCONTROLLER Same plant, delay, scaling and grid with another controller.
%   context = terra.withController(context, controller) is used to verify
%   a controller move without rebuilding the structural model. The fast
%   kernel or the state-space interconnection is rebuilt accordingly.

    context = terra.createDiagnosticContextLike(context, context.plant, controller);
end
