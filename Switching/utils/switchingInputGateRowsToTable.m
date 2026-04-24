function tbl = switchingInputGateRowsToTable(rows)
%SWITCHINGINPUTGATEROWSTOTABLE Convert gate row struct to table.

tbl = table(rows.table_name, rows.table_path, rows.validation_status, rows.failure_code, rows.failure_message, rows.metadata_path, ...
    'VariableNames', {'table_name','table_path','validation_status','failure_code','failure_message','metadata_path'});
end
