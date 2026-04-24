function switchingWriteTableBothPaths(tbl, repoRoot, runTablesDir, fileName)
%SWITCHINGWRITETABLEBOTHPATHS Write one table to run tables and repo-root tables.

writetable(tbl, fullfile(runTablesDir, fileName));
writetable(tbl, fullfile(repoRoot, 'tables', fileName));
end
