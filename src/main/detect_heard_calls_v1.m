function heard = detect_heard_calls_v1(wav_input, self_labels, params)
% detect_heard_calls_v1
% orchestrate the v1 heard-call detector (reference-mic only).

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
        'ref_channel_index', [], ...
        'roi_windows',     [] ...   % optional: restrict detection to these [on off] windows (s)
    );
    if nargin < 3 || isempty(params), params = struct(); end

    % inline merge (no dependency on merge_params)
    f = fieldnames(dflt);
    for k = 1:numel(f)
        name = f{k};
        if ~isfield(params, name) || isempty(params.(name))
            params.(name) = dflt.(name);
        end
    end

    % -- read audio (mono ref channel as column), build frame params
    [x, fs] = read_audio(wav_input, params.ref_channel_index);
    FP = frame_params(fs, params.win_ms, params.hop_ms, numel(x));

    % early out if no frames
    if FP.n_frames == 0
        heard = table('Size',[0 4], ...
            'VariableTypes', {'double','double','double','double'}, ...
            'VariableNames', {'on','off','dur','confidence'});
        heard.Properties.UserData.meta.FP = FP;
        heard.Properties.UserData.meta.params = params;
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

    % -- self mask (padded) on frame grid
    Lpad = pad_labels(self_labels, params.pre_pad_ms, params.post_pad_ms);
    mask_self = build_self_mask(Lpad, FP);

    % -- roi mask and composition
    % true means frames are allowed. total allowed = self_mask & roi_mask.
    roi_mask = build_roi_mask(params.roi_windows, FP);
    mask = mask_self & roi_mask;

    % -- detection path
    state = apply_hysteresis(E, F, medE, madE, medF, madF, ...
                             params.kE, params.kF, params.k_low, params.release_frames);
    active = state & mask;

    % -- frames → events
    events = frames_to_events(active, FP, params.min_event_ms, params.merge_gap_ms, params.max_event_ms);

    % -- confidence and metadata
    conf = compute_confidence_per_event(E, FP, active, events);
    heard = events;
    heard.confidence = conf;
    heard.Properties.UserData.meta.FP = FP;
    heard.Properties.UserData.meta.params = params;
end

% --- helpers ---

function Lout = pad_labels(Lin, pre_ms, post_ms)
    if isempty(Lin)
        Lout = zeros(0,2);
        return
    end
    if isnumeric(Lin)
        if size(Lin,2) ~= 2
            error('detect_heard_calls_v1:badLabels', 'self_labels must be Nx2 numeric or struct with .on/.off.');
        end
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