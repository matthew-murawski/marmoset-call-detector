function export_audacity_labels(filename_txt, events_table, label_text)
% export_audacity_labels
% write an audacity labels .txt file with lines:
%   on \t off \t label_text
%
% behavior:
% - ensures ascending order by onset
% - empty table → creates an empty file
% - validates inputs and errors with id 'export:badInput' if required fields are missing
%
% inputs
%   filename_txt : path to output .txt (char or string)
%   events_table : table with variables 'on' and 'off' (seconds)
%   label_text   : scalar char/string; written on every line

    % --- validate inputs
    if nargin < 3
        error('export:badInput', 'filename, events_table, and label_text are required.');
    end
    if ~(ischar(filename_txt) || (isstring(filename_txt) && isscalar(filename_txt)))
        error('export:badInput', 'filename_txt must be a char or string scalar path.');
    end
    if ~istable(events_table)
        error('export:badInput', 'events_table must be a table with variables ''on'' and ''off''.');
    end
    need = {'on','off'};
    if ~all(ismember(need, events_table.Properties.VariableNames))
        error('export:badInput', 'events_table must contain variables ''on'' and ''off''.');
    end
    if ~(ischar(label_text) || (isstring(label_text) && isscalar(label_text)))
        error('export:badInput', 'label_text must be a char or string scalar.');
    end

    % normalize types
    fp = char(filename_txt);
    lbl = char(label_text);

    % sort by onset if non-empty
    if height(events_table) > 0
        events_table = sortrows(events_table, 'on', 'ascend');
    end

    % open for write (create/truncate)
    fid = fopen(fp, 'w');
    if fid < 0
        error('export:io', 'could not open %s for writing.', fp);
    end
    c = onCleanup(@() fclose(fid)); %#ok<NASGU>

    % empty table → write nothing (empty file)
    if height(events_table) == 0
        return
    end

    % write rows with fixed precision (6 decimals)
    on  = events_table.on(:);
    off = events_table.off(:);
    for i = 1:numel(on)
        fprintf(fid, '%.6f\t%.6f\t%s\n', on(i), off(i), lbl);
    end
end