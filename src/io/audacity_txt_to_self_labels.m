function self_labels = audacity_txt_to_self_labels(txt_path, label_to_keep)
% read an audacity labels .txt (tab-separated). expected formats:
%   start \t end \t label   (region labels)   <-- use this
%   start \t label          (point labels)    <-- not usable as-is
%
% label_to_keep (optional): e.g., 'self' or 'produced'.
% if omitted, all regions are returned.

    T = readtable(txt_path, 'FileType','text', 'Delimiter','\t', ...
        'ReadVariableNames',false, 'MultipleDelimsAsOne',true);

    if width(T) == 3
        starts = double(T.Var1);
        stops  = double(T.Var2);
        labels = string(T.Var3);
    elseif width(T) == 2
        error('audacity_txt:pointLabels', ...
            'file has point labels (no end times). convert to regions first.');
    else
        error('audacity_txt:badFormat', 'unexpected number of columns.');
    end

    % optional filtering by label text (case-insensitive, trims spaces)
    keep = true(height(T),1);
    if nargin >= 2 && ~isempty(label_to_keep)
        keep = strcmpi(strtrim(labels), label_to_keep);
    end

    on  = starts(keep);
    off = stops(keep);

    % basic sanity: on<off, finite, nonempty
    good = isfinite(on) & isfinite(off) & (off > on);
    self_labels = [on(good) off(good)];

    % you may want them sorted
    self_labels = sortrows(self_labels, 1);
end