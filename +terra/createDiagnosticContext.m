function context = createDiagnosticContext(plant, controller, configuration, ...
        delaySeconds, actuatorScale, evaluatorKind, label)
%CREATEDIAGNOSTICCONTEXT Bundle everything needed to evaluate f_W(omega).
%   context = terra.createDiagnosticContext(plant, controller,
%   configuration, delaySeconds, actuatorScale, evaluatorKind, label)
%   returns the evaluation context for the weighted diagnostic
%       f_W(omega) = sigma_min( W^-1 F_u(j omega) W ),   W = diag(actuatorScale)
%   evaluatorKind
%       'modal'        modal residues + transfer-function channels through
%                      a precomputed kernel (adaptive method, dense grids)
%       'state_space'  resolvent of the assembled interconnection
%                      (independent implementation, dense reference)
%   Change the plant or controller of an existing context only through
%   terra.withPlant / terra.withController, which rebuild the kernel.

    context.plant = plant;
    context.controller = controller;
    context.configuration = configuration;
    context.delaySeconds = delaySeconds;
    context.actuatorScale = reshape(actuatorScale, [], 1);
    context.evaluatorKind = evaluatorKind;
    context.label = label;
    switch evaluatorKind
        case 'modal'
            context.kernel = terra.buildDiagnosticKernel(plant, controller, configuration, ...
                delaySeconds, actuatorScale);
        case 'state_space'
            context.interconnection = terra.buildInterconnection(plant, controller, configuration);
        otherwise
            error('terra:UnknownEvaluator', 'Unknown evaluator kind "%s".', evaluatorKind);
    end
end
