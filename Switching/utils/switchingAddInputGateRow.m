function rows = switchingAddInputGateRow(rows, name, pathIn, status, code, msg, mpath)
%SWITCHINGADDINPUTGATEROW Append one row to canonical input gate status struct.

rows.table_name(end+1,1) = string(name);
rows.table_path(end+1,1) = string(pathIn);
rows.validation_status(end+1,1) = string(status);
rows.failure_code(end+1,1) = string(code);
rows.failure_message(end+1,1) = string(msg);
rows.metadata_path(end+1,1) = string(mpath);
end
