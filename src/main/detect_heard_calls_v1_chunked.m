function heard = detect_heard_calls_v1_chunked(wav_path, self_labels, params)
% detect_heard_calls_v1_chunked
% run v1 detector on arbitrarily long wavs by processing overlapping chunks.
%
% params additions:
%   .t_start (s)    : optional start time (default 0)
%   .t_end   (s)    : optional end time (default = wav duration)
%   .chunk_sec      : optional core chunk length (default 120)
%   .overlap_sec    : optional overlap per side (default = max(rolling_sec, win_s))

    % section: resolve defaults and time window
    if nargin < 3 || isempty(params), params = struct(); end
    params = local_merge_params(defaults_v1(), params);

    info = audioinfo(wav_path);
    fs   = info.SampleRate;
    T    = info.Duration;
    C    = info.NumChannels;

    if ~isfield(params, 't_start') || isempty(params.t_start), params.t_start = 0; end
    if ~isfield(params, 't_end')   || isempty(params.t_end),   params.t_end   = T; end

    t_start = max(0, min(T, double(params.t_start)));
    t_end   = max(0, min(T, double(params.t_end)));
    if t_end <= t_start
        heard = table('Size',[0 4], ...
            'VariableTypes', {'double','double','double','double'}, ...
            'VariableNames', {'on','off','dur','confidence'});
        return
    end

    % section: chunk geometry and ref channel choice
    if ~isfield(params, 'chunk_sec')   || isempty(params.chunk_sec),   params.chunk_sec   = 120; end
    if ~isfield(params, 'overlap_sec') || isempty(params.overlap_sec)
        params.overlap_sec = max(params.rolling_sec, params.win_ms/1000);
    end

    if ~isempty(params.ref_channel_index)
        ref_idx = min(max(1, params.ref_channel_index), C);
    else
        ref_idx = (C >= 2) + 1; % default: ch2 if present; else ch1
    end

    % section: main loop over core chunks within [t_start, t_end]
    chunk  = params.chunk_sec;
    olap   = params.overlap_sec;
    events_all = table('Size',[0 4], ...
        'VariableTypes', {'double','double','double','double'}, ...
        'VariableNames', {'on','off','dur','confidence'});

    core0 = t_start;
    while core0 < t_end
        core1   = min(t_end, core0 + chunk);
        t_read0 = max(0, core0 - olap);
        t_read1 = min(T,  core1 + olap);

        s0 = floor(t_read0 * fs) + 1;
        s1 = max(s0, floor(t_read1 * fs));
        x  = audioread(wav_path, [s0 s1]);           % [N x C]
        if size(x,2) < ref_idx, ref_idx = 1; end
        x  = x(:, ref_idx);                           % mono ref
        wavin.x  = x;
        wavin.fs = fs;

        % in-section: limit labels to window and shift to local time
        Lloc = local_slice_labels(self_labels, t_read0, t_read1, params);

        % in-section: run stock detector on chunk
        heard_chunk = detect_heard_calls_v1(wavin, Lloc, params);

        % section: map back to global time and keep only core overlap
        if ~isempty(heard_chunk)
            heard_chunk.on  = heard_chunk.on  + t_read0;
            heard_chunk.off = heard_chunk.off + t_read0;
            heard_chunk.dur = max(heard_chunk.off - heard_chunk.on, 0);

            keep = (heard_chunk.on < core1) & (heard_chunk.off > core0);
            heard_chunk = heard_chunk(keep, :);

            if ~isempty(heard_chunk)
                heard_chunk.on  = max(heard_chunk.on,  0);
                heard_chunk.off = min(heard_chunk.off, T);
                heard_chunk.dur = max(heard_chunk.off - heard_chunk.on, 0);
            end

            events_all = [events_all; heard_chunk]; %#ok<AGROW>
        end

        core0 = core1; % advance by core length
    end

    % section: merge across boundaries and enforce max duration
    heard = local_merge_events(events_all, params.merge_gap_ms, params.max_event_ms);
end

% --- helpers ---

function d = defaults_v1()
    d = struct( ...
        'bandpass',        [5e3, 12e3], ...
        'win_ms',          25, ...
        'hop_ms',          10, ...
        'rolling_sec',     60, ...
        'kE',              3.5, ...
        'kF',              3.0, ...
        'k_low',           2.0, ...
        'release_frames',  2, ...
        'min_event_ms',    70, ...
        'merge_gap_ms',    50, ...
        'max_event_ms',    4000, ...
        'pre_pad_ms',      30, ...
        'post_pad_ms',     100, ...
        'ref_channel_index', [] ...
    );
end

function P = local_merge_params(a, b)
    P = a;
    if ~isstruct(b) || isempty(fieldnames(b)), return; end
    fn = fieldnames(b);
    for k = 1:numel(fn), P.(fn{k}) = b.(fn{k}); end
end

function Lout = local_slice_labels(Lin, t0, t1, params)
% keep only labels that can affect [t0,t1] after padding, shift to chunk-local time.
    if isempty(Lin)
        Lout = zeros(0,2);
        return
    end
    if isnumeric(Lin)
        L = double(Lin);
    elseif isstruct(Lin)
        on  = arrayfun(@(s) double(s.on),  Lin(:));
        off = arrayfun(@(s) double(s.off), Lin(:));
        L = [on(:) off(:)];
    else
        error('detect_heard_calls_v1_chunked:badLabels', 'self_labels must be Nx2 numeric or struct with .on/.off.');
    end

    pre  = max(0, double(params.pre_pad_ms)  / 1000);
    post = max(0, double(params.post_pad_ms) / 1000);
    hit  = (L(:,2) + post) >= t0 & (L(:,1) - pre) <= t1;
    L    = L(hit, :);

    if isempty(L)
        Lout = zeros(0,2);
        return
    end

    L = L - t0;
    L(:,1) = max(L(:,1), 0);
    L(:,2) = max(L(:,2), 0);
    Lout = L;
end

function Tm = local_merge_events(T, merge_gap_ms, max_event_ms)
    if isempty(T), Tm = T; return; end
    T = sortrows(T, 'on');
    gap_s = double(merge_gap_ms) / 1000;
    max_s = double(max_event_ms) / 1000;

    out = T(1,:);
    for i = 2:height(T)
        last = out(end,:);
        cur  = T(i,:);
        if cur.on <= last.off + gap_s
            out.off(end,:)        = max(last.off, cur.off); %#ok<AGROW>
            out.dur(end,:)        = max(out(end,:).off - out(end,:).on, 0);
            if ismember('confidence', T.Properties.VariableNames)
                out(end,:).confidence = max(last.confidence, cur.confidence);
            end
        else
            out = [out; cur]; %#ok<AGROW>
        end
    end

    too_long = out.dur > max_s;
    out.off(too_long) = out.on(too_long) + max_s;
    out.dur(too_long) = max_s;

    Tm = out;
end