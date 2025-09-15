function heard = detect_heard_calls_v1(wav_input, self_labels, params)
% detect_heard_calls_v1
% orchestrate the v1 heard-call detector (reference-mic only).
%
% steps:
%   1) parse params, apply defaults
%   2) read audio; compute frame params
%   3) stft (log-mag, band-limited) → features E, F
%   4) rolling median+mad thresholds (per feature)
%   5) pad self labels and build mask (true=allowed, false=excluded)
%   6) detect candidates → hysteresis → apply mask
%   7) frames → events (min, merge, cap)
%   8) add per-event confidence and stash meta in table userdata
%
% inputs
%   wav_input   : wav path or struct with fields .x (NxC) and .fs (scalar)
%   self_labels : Nx2 double [on off] seconds, or struct array with .on/.off
%   params      : struct with fields listed in defaults below (partial ok)
%
% output
%   heard : table with variables on/off/dur/confidence; meta in UserData

    % -- defaults
    dflt = struct( ...
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
    if nargin < 3 || isempty(params), params = struct(); end
    params = merge_params(dflt, params);

    % -- read audio (mono ref channel as column), build frame params
    [x, fs] = read_audio(wav_input, params.ref_channel_index);
    FP = frame_params(fs, params.win_ms, params.hop_ms, numel(x));

    % early out if no frames
    if FP.n_frames == 0
        heard = table('Size',[0 4], ...
            'VariableTypes', {'double','double','double','double'}, ...
            'VariableNames', {'on','off','dur','confidence'});
        heard.Properties.UserData.meta.params = params; %#ok<*STRNU>
        return
    end

    % -- stft (log-mag, band-limited), then features
    [Slog, ~, ~] = compute_stft_logmag(x, fs, FP, params.bandpass);
    E = band_energy(Slog);
    F = spectral_flux_pos(Slog);

    % -- rolling robust stats
    frames_per_window = max(1, round(params.rolling_sec * 1000 / params.hop_ms));
    [medE, madE] = rolling_stats(E, frames_per_window);
    [medF, madF] = rolling_stats(F, frames_per_window);

    % -- pad self labels and build mask (true=allowed; false=excluded)
    Lpad = pad_labels(self_labels, params.pre_pad_ms, params.post_pad_ms);
    mask = build_self_mask(Lpad, FP);

    % -- detection path: hysteresis → apply mask
    state = apply_hysteresis(E, F, medE, madE, medF, madF, ...
                             params.kE, params.kF, params.k_low, params.release_frames);
    active = state & mask;

    % -- frame activity → events
    events = frames_to_events(active, FP, params.min_event_ms, params.merge_gap_ms, params.max_event_ms);

    % -- boundary correction: treat FP.t_frames as frame centers.
    % move 'off' to the LEFT edge of the last window (−win/2).
    if ~isempty(events)
        win_s  = params.win_ms / 1000;
        events.off = max(events.on, events.off - 0.5*win_s);
        events.dur = max(events.off - events.on, 0);
    end

    % -- build output table and confidence
    if isempty(events)
        heard = table('Size',[0 4], ...
            'VariableTypes', {'double','double','double','double'}, ...
            'VariableNames', {'on','off','dur','confidence'});
    else
        conf = compute_confidence_per_event(E, FP, active, events);
        heard = events;
        heard.confidence = conf(:);
    end

    % -- stash meta
    meta.params = params;
    meta.fs = fs;
    meta.n_frames = FP.n_frames;
    heard.Properties.UserData.meta = meta;
end

% --- helpers ---

function P = merge_params(dflt, user)
    P = dflt;
    if ~isstruct(user) || isempty(fieldnames(user))
        return
    end
    fn = fieldnames(user);
    for k = 1:numel(fn)
        P.(fn{k}) = user.(fn{k});
    end
end

function Lout = pad_labels(Lin, pre_ms, post_ms)
    % normalize to Nx2 numeric and pad by pre/post (ms→s). clip at zero.
    if isempty(Lin)
        Lout = zeros(0,2);
        return
    elseif isnumeric(Lin)
        L = double(Lin);
    elseif isstruct(Lin)
        on  = arrayfun(@(s) double(s.on),  Lin(:));
        off = arrayfun(@(s) double(s.off), Lin(:));
        L = [on(:) off(:)];
    else
        error('detect_heard_calls_v1:badLabels', 'self_labels must be Nx2 numeric or struct with .on/.off.');
    end
    pre_s  = max(0, double(pre_ms)  / 1000);
    post_s = max(0, double(post_ms) / 1000);
    Lout = [max(0, L(:,1) - pre_s), L(:,2) + post_s];
end

function conf = compute_confidence_per_event(E, FP, active, events)
    % simple heuristic: normalize E over active frames to [0,1],
    % then confidence = median(normalized E) over active frames inside each event.
    E = double(E(:)).';
    tf = double(FP.t_frames(:)).';
    if ~any(active)
        conf = zeros(height(events),1);
        return
    end

    E_act = E(active);
    emin = min(E_act);
    emax = max(E_act);
    erng = max(emax - emin, eps);

    Enorm = nan(1, numel(E));
    Enorm(active) = (E(active) - emin) / erng;

    conf = zeros(height(events),1);
    for i = 1:height(events)
        idx_time = (tf >= events.on(i) - 1e-9) & (tf <= events.off(i) - 1e-9);
        vals = Enorm(idx_time & active);
        if isempty(vals) || all(isnan(vals))
            conf(i) = 0;
        else
            conf(i) = median(vals, 'omitnan');
        end
    end
end