function events = frames_to_events(active, FP, min_event_ms, merge_gap_ms, max_event_ms)
% convert active frames to a table of events with duration shaping.
% steps:
%   1) find contiguous runs where active==true
%   2) drop runs shorter than min_event_ms
%   3) merge adjacent runs separated by gaps < merge_gap_ms
%   4) cap long runs at max_event_ms (truncate off time)
%
% on/off/dur are in seconds. empty table if no events.
%
% timebase:
%   we define on = t_frames(i_start)
%             off = t_frames(i_end) + hop_s
%   thus duration = n_frames_in_run * hop_s (and merged events include gap).

    % --- normalize shapes and validate
    active = logical(active(:)).';
    n = numel(active);

    % resolve timebase from FP
    [t_frames, hop_s] = resolve_timebase(FP, n);

    % fast exit: no frames
    if n == 0 || ~any(active)
        events = empty_events_table();
        return
    end

    % --- find contiguous true runs
    d = diff([false, active, false]);
    starts = find(d == 1);
    ends   = find(d == -1) - 1;

    % compute initial on/off using frame indices
    on  = t_frames(starts);
    off = t_frames(ends) + hop_s;

    % --- drop short runs
    min_event_s = max(0, double(min_event_ms) / 1000);
    dur = off - on;
    keep = dur >= min_event_s;
    on  = on(keep);
    off = off(keep);

    if isempty(on)
        events = empty_events_table();
        return
    end

    % --- merge gaps smaller than threshold
    merge_gap_s = max(0, double(merge_gap_ms) / 1000);
    [on_m, off_m] = merge_by_gap(on, off, merge_gap_s);

    % --- cap overly long events by truncation
    max_event_s = max(0, double(max_event_ms) / 1000);
    if isfinite(max_event_s) && max_event_s > 0
        off_capped = min(off_m, on_m + max_event_s);
    else
        off_capped = off_m;
    end

    % --- assemble table
    dur = off_capped - on_m;
    events = table(on_m(:), off_capped(:), dur(:), ...
        'VariableNames', {'on','off','dur'});
end

% --- helpers ---

function [t_frames, hop_s] = resolve_timebase(FP, n)
    % make t_frames a 1xn row and hop_s a scalar. prefer explicit fields.
    have_t = isfield(FP, 't_frames');
    have_hop_s = isfield(FP, 'hop_s');
    have_hop_fs = isfield(FP, 'hop') && isfield(FP, 'fs');

    if have_t
        t_frames = double(FP.t_frames(:)).';
        if numel(t_frames) ~= n
            error('frames_to_events:invalidFP', 'FP.t_frames must match the number of frames.');
        end
        if have_hop_s
            hop_s = double(FP.hop_s);
        else
            % infer hop from time vector
            if n >= 2
                hop_s = median(diff(t_frames));
            else
                error('frames_to_events:invalidFP', 'cannot infer hop from a single frame.');
            end
        end
    elseif have_hop_s
        hop_s = double(FP.hop_s);
        t_frames = (0:n-1) * hop_s;
    elseif have_hop_fs
        hop_s = double(FP.hop) / double(FP.fs);
        t_frames = (0:n-1) * hop_s;
    else
        error('frames_to_events:invalidFP', 'FP must provide t_frames, or hop_s, or hop+fs.');
    end
end

function [on_out, off_out] = merge_by_gap(on, off, gap_thr)
    % merge consecutive events whose gap < gap_thr.
    on_out = [];
    off_out = [];
    cur_on = on(1);
    cur_off = off(1);
    for i = 2:numel(on)
        gap = on(i) - cur_off;
        if gap < gap_thr  % strict less-than per spec
            % extend current event to include this one
            cur_off = max(cur_off, off(i));
        else
            on_out(end+1)  = cur_on; %#ok<AGROW>
            off_out(end+1) = cur_off; %#ok<AGROW>
            cur_on  = on(i);
            cur_off = off(i);
        end
    end
    % flush final
    on_out(end+1)  = cur_on;
    off_out(end+1) = cur_off;
end

function T = empty_events_table()
    T = table('Size',[0 3], ...
        'VariableTypes', {'double','double','double'}, ...
        'VariableNames', {'on','off','dur'});
end