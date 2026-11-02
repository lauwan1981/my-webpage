function context = createDiagnosticContextLike(template, plant, controller)
%CREATEDIAGNOSTICCONTEXTLIKE Rebuild a context, keeping its extra fields.
%   context = terra.createDiagnosticContextLike(template, plant,
%   controller) creates a fresh diagnostic context (kernel or
%   interconnection included) for plant and controller with the delay,
%   scaling, evaluator kind and label of template, and copies every
%   additional field of template (operating point, grid, model, ...).

    context = terra.createDiagnosticContext(plant, controller, template.configuration, ...
        template.delaySeconds, template.actuatorScale, template.evaluatorKind, template.label);
    templateFields = fieldnames(template);
    for fieldIndex = 1:numel(templateFields)
        fieldName = templateFields{fieldIndex};
        if ~isfield(context, fieldName)
            context.(fieldName) = template.(fieldName);
        end
    end
end
