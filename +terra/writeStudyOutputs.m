function writeStudyOutputs(results)
%WRITESTUDYOUTPUTS Tables, report and data export.
%   terra.writeStudyOutputs(results) writes into results.outputDirectory:
%     tables/   CSV files and tables.md (Table 1, Table 2, supplements)
%     data/     results.mat, model_statespace.mat (raw matrices, ports)
%     report.txt          findings with evidence levels and caveats
%   In 'check' mode only the self-check report and the model export
%   (data/) are written. The manifest is written last by terra.runStudy
%   so that it lists every produced file, including the figures.

    outputDirectory = results.outputDirectory;
    dataDirectory = fullfile(outputDirectory, 'data');
    terra.ensureDirectory(dataDirectory);

    terra.exportModelData(fullfile(dataDirectory, 'model_statespace.mat'), results.configuration);
    if ~isfield(results, 'caseResults')
        terra.writeReport(fullfile(outputDirectory, 'report.txt'), results);
        return;
    end
    tableDirectory = fullfile(outputDirectory, 'tables');
    terra.ensureDirectory(tableDirectory);
    terra.writeResultTables(tableDirectory, results);
    save(fullfile(dataDirectory, 'results.mat'), 'results', '-v7');
    terra.writeReport(fullfile(outputDirectory, 'report.txt'), results);
end
