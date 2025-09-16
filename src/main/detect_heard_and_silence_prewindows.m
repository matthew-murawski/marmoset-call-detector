function [heard, silence] = detect_heard_and_silence_prewindows(wav_input, self_labels, varargin)
% detect_heard_and_silence_prewindows
% run heard-call detection + conservative silence detection inside pre-windows
% preceding produced onsets. returns two tables: heard (on/off/dur/confidence)
% and silence (on/off/dur). both are restricted to the roi pre-windows.

    % -- parse inputs
    p = inputParser;
    p.addParameter('PreWindowSec', 5, @(x)isnumeric(x)&&isscalar(x)&&x>=0);
    p.addParameter('HeardParams', struct(), @(s)isstruct(s)||isempty(s));
    p.addParameter('SilenceEdgeMs', 120, @(x)isnumeric(x)&&isscalar(x)&&x>=0);
    p.addParameter('KSilence', 2.5, @(x)isnumeric(x)&&isscalar(x)&&x>=0);
    p.addParameter('MinSilenceMs', 500, @(x)isnumeric(x)&&isscalar(x)&&x>=0);
    p.addParameter('MergeGapMs', 60, @(x)isnumeric(x)&&isscalar(x)&&x>=0);
    p.addParameter('MaxSilenceMs', inf, @(x)isnumeric(x)&&isscalar(x)&&x>=0);
    p.parse(varargin{:});
    opt = p.Results;

    % -- basic validation
    if isempty(self_labels)
        error('detect_heard_and_silence_prewindows:NoSelfLabels', ...
              'self_labels are required to define pre-windows.');
    end
    Lself = normalize_labels(self_labels);

    % -- build roi windows [on - T, on), clipped to >= 0
    T = double(opt.PreWindowSec);
    roi_windows = [max(0, Lself(:,1) - T), Lself(:,1)];

    % -- run heard detection inside rois (params passed through; roi set here)
    hp = opt.HeardParams;
    hp.roi_windows = roi_windows;
    heard_full = detect_heard_calls_v1(wav_input, self_labels, hp);

    % -- try to pull frame grid + params from heard detector; else, fallback
    meta_available = isprop(heard_full,'Properties') && ...
                     isprop(heard_full.Properties,'UserData') && ...
                     ~isempty(heard_full.Properties.UserData) && ...
                     isfield(heard_full.Properties.UserData,'meta');

    if meta_available
        FP = heard_full.Properties.UserData.meta.FP;
        params_heard = heard_full.Properties.UserData.meta.params;
    else
        % fill defaults locally so we can recompute FP/features on the same grid
        params_heard = apply_heard_defaults(opt.HeardParams);
        [x_fp, fs_fp] = read_audio(wav_input, params_heard.ref_channel_index);
        FP = frame_params(fs_fp, params_heard.win_ms, params_heard.hop_ms, numel(x_fp));
    end

    % -- make roi mask on frame grid
    mask_roi = build_roi_mask(roi_windows, FP);

    % -- convert self + heard events to a frame mask, then dilate a rim
    mask_self  = windows_to_mask(Lself, FP);
    mask_heard = windows_to_mask([heard_full.on, heard_full.off], FP);
    rim = mask_self | mask_heard;

    hop_s = infer_hop_s(FP);
    rim_frames = max(0, round((opt.SilenceEdgeMs/1000) / hop_s));  % edge safety in frames
    rim_dilated = dilate_events_mask(rim, rim_frames);

    % -- silence-eligible frames are inside roi and away from dilated edges
    eligible = mask_roi & ~rim_dilated;

    % -- recompute features on the same frame grid for quiet detection
    [x, fs] = read_audio(wav_input, params_heard.ref_channel_index);
    [Slog, ~, ~] = compute_stft_logmag(x, fs, FP, params_heard.bandpass);
    E = band_energy(Slog);
    F = spectral_flux_pos(Slog);
    frames_per_window = max(1, round(params_heard.rolling_sec * 1000 / params_heard.hop_ms));
    [medE, madE] = rolling_stats(E, frames_per_window);
    [medF, madF] = rolling_stats(F, frames_per_window);

    % -- detect quiet frames using inverted thresholds and the eligible mask
    quiet = detect_quiet_frames(E, F, medE, madE, medF, madF, opt.KSilence, eligible);

    % -- frames → silence events with conservative duration rules
    silence = frames_to_events(quiet, FP, opt.MinSilenceMs, opt.MergeGapMs, opt.MaxSilenceMs);

    % -- limit heard to on/off/dur/confidence and attach meta
    heard = heard_full(:, intersect({'on','off','dur','confidence'}, heard_full.Properties.VariableNames, 'stable'));

    % attach meta (always present from here on)
    heard.Properties.UserData.meta.FP = FP;
    heard.Properties.UserData.meta.params = params_heard;
    heard.Properties.UserData.meta.roi_windows = roi_windows;
    heard.Properties.UserData.meta.silence = rmfield_safe(opt, {'HeardParams'});

    silence.Properties.UserData.meta.FP = FP;
    silence.Properties.UserData.meta.params = params_heard;
    silence.Properties.UserData.meta.roi_windows = roi_windows;
    silence.Properties.UserData.meta.silence = rmfield_safe(opt, {'HeardParams'});

end

% --- helpers ---

function P = apply_heard_defaults(P)
    % merge minimal v1 defaults we rely on here
    dflt = struct( ...
        'bandpass',        [5e3, 12e3], ...
        'win_ms',          25, ...
        'hop_ms',          10, ...
        'rolling_sec',     60, ...
        'ref_channel_index', [] ...
    );
    if nargin<1 || isempty(P), P = struct(); end
    f = fieldnames(dflt);
    for k = 1:numel(f)
        name = f{k};
        if ~isfield(P, name) || isempty(P.(name))
            P.(name) = dflt.(name);
        end
    end
end

function L = normalize_labels(Lin)
    if isnumeric(Lin)
        if size(Lin,2) ~= 2
            error('detect_heard_and_silence_prewindows:BadLabels', 'expected Nx2 numeric [on off].');
        end
        L = double(Lin);
    elseif isstruct(Lin)
        on  = arrayfun(@(s) double(s.on),  Lin(:));
        off = arrayfun(@(s) double(s.off), Lin(:));
        L = [on(:) off(:)];
    else
        error('detect_heard_and_silence_prewindows:BadLabels', 'unsupported label type.');
    end
end

function mask = windows_to_mask(win, FP)
    tf = FP.t_frames(:).';
    mask = false(size(tf));
    if isempty(win), return; end
    for i = 1:size(win,1)
        on = win(i,1); off = win(i,2);
        if ~(isfinite(on) && isfinite(off)) || off <= on, continue; end
        mask = mask | (tf >= on & tf < off);
    end
end

function hop_s = infer_hop_s(FP)
    if isfield(FP, 'hop_s') && ~isempty(FP.hop_s)
        hop_s = FP.hop_s;
    else
        tf = FP.t_frames(:);
        if numel(tf) < 2
            hop_s = 0.01;
        else
            hop_s = median(diff(tf), 'omitnan');
        end
    end
end

function S = rmfield_safe(S, fields)
    for k = 1:numel(fields)
        if isfield(S, fields{k})
            S = rmfield(S, fields{k});
        end
    end
end