function [heard, silence] = detect_heard_and_silence_prewindows(wav_input, self_labels, varargin)
% detect_heard_and_silence_prewindows
% run heard-call detection + conservative silence detection inside pre-windows
% preceding produced onsets. returns two tables: heard (on/off/dur/confidence)
% and silence (on/off/dur). both are restricted to the roi pre-windows.
%
% change: minimal per-ROI loop to avoid whole-file STFT allocation. we read
% small segments around each ROI and call the v1 detector on each segment.

    % -- parse inputs
    p = inputParser;
    p.addParameter('PreWindowSec', 5, @(x)isnumeric(x)&&isscalar(x)&&x>=0);
    p.addParameter('HeardParams', struct(), @(s)isstruct(s)||isempty(s));
    p.addParameter('SilenceEdgeMs', 120, @(x)isnumeric(x)&&isscalar(x)&&x>=0);
    p.addParameter('KSilence', 2.5, @(x)isnumeric(x)&&isscalar(x)&&x>=0);
    p.addParameter('MinSilenceMs', 500, @(x)isnumeric(x)&&isscalar(x)&&x>=0);
    p.addParameter('MergeGapMs', 60, @(x)isnumeric(x)&&isscalar(x)&&x>=0);
    p.addParameter('MaxSilenceMs', inf, @(x)isnumeric(x)&&isscalar(x)&&x>=0);
    p.addParameter('ContextPadSec', 0.75, @(x)isnumeric(x)&&isscalar(x)&&x>=0); % extra audio around each roi
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
    if isempty(roi_windows)
        heard   = table('Size',[0 4], 'VariableTypes', {'double','double','double','double'}, ...
                        'VariableNames', {'on','off','dur','confidence'});
        silence = table('Size',[0 3], 'VariableTypes', {'double','double','double'}, ...
                        'VariableNames', {'on','off','dur'});
        return
    end

    % -- coalesce overlapping/adjacent rois to avoid double-processing
    roi_windows = merge_windows(roi_windows);

    % -- get wav info (fs, total samples) without loading audio
    if ischar(wav_input) || (isstring(wav_input) && isscalar(wav_input))
        info = audioinfo(char(wav_input));
        fs_full = double(info.SampleRate);
        n_samp_full = double(info.TotalSamples);
        wav_is_path = true;
    else
        % allow passing struct('x', NxC, 'fs', fs)
        wav_is_path = false;
        if ~(isstruct(wav_input) && isfield(wav_input,'x') && isfield(wav_input,'fs'))
            error('detect_heard_and_silence_prewindows:BadAudio', ...
                  'wav_input must be a wav path or a struct with fields .x and .fs');
        end
        fs_full = double(wav_input.fs);
        n_samp_full = size(wav_input.x,1);
    end
    dur_full = n_samp_full / fs_full;

    % -- preallocate empty outputs
    heard_all   = table('Size',[0 4], 'VariableTypes', {'double','double','double','double'}, ...
                        'VariableNames', {'on','off','dur','confidence'});
    silence_all = table('Size',[0 3], 'VariableTypes', {'double','double','double'}, ...
                        'VariableNames', {'on','off','dur'});

    % -- process each roi in isolation (+ small context pad)
    pad = double(opt.ContextPadSec);
    hp0 = opt.HeardParams;
    if isfield(hp0, 'roi_windows'), hp0 = rmfield(hp0, 'roi_windows'); end  % not needed; we pass trimmed audio

    for i = 1:size(roi_windows,1)
        roi_on = max(0, roi_windows(i,1));
        roi_off = min(dur_full, roi_windows(i,2));
        if ~(isfinite(roi_on) && isfinite(roi_off)) || roi_off <= roi_on
            continue
        end

        % segment bounds with context
        seg_on  = max(0, roi_on - pad);
        seg_off = min(dur_full, roi_off + pad);

        % convert to 1-based sample indices
        s0 = max(1, floor(seg_on * fs_full) + 1);
        s1 = min(n_samp_full, ceil(seg_off * fs_full));
        seg_offset_s = (s0 - 1) / fs_full;  % absolute time of sample s0

        % read the audio segment (path or in-memory)
        if wav_is_path
            [x_seg, fs] = audioread(char(wav_input), [s0 s1]);
        else
            x_seg = wav_input.x(s0:s1, :);
            fs = fs_full;
        end

        % build self labels local to the segment
        Lself_local = intersect_and_shift_windows(Lself, [seg_on seg_off], seg_offset_s);

        % run heard detection on just this segment
        heard_seg = detect_heard_calls_v1(struct('x', x_seg, 'fs', fs), Lself_local, hp0);

        % keep a local copy of heard windows before shifting to absolute
        H_local = [heard_seg.on, heard_seg.off];

        % shift heard to absolute time and crop to roi
        heard_seg.on  = heard_seg.on  + seg_offset_s;
        heard_seg.off = heard_seg.off + seg_offset_s;
        % crop to exact roi interior
        heard_seg = crop_events_to_window(heard_seg, [roi_on roi_off]);

        % recompute dur after cropping
        if ~isempty(heard_seg)
            heard_seg.dur = heard_seg.off - heard_seg.on;
        end

        % -----------------------
        % quiet detection (segment)
        % -----------------------
        % get frame grid and params used by heard detector
        meta_ok = isprop(heard_seg,'Properties') && isprop(heard_seg.Properties,'UserData') && ...
                  ~isempty(heard_seg.Properties.UserData) && isfield(heard_seg.Properties.UserData,'meta');
        if meta_ok
            FP = heard_seg.Properties.UserData.meta.FP;
            params_heard = heard_seg.Properties.UserData.meta.params;
        else
            % fall back to minimal defaults based on this segment
            params_heard = apply_heard_defaults(opt.HeardParams);
            FP = frame_params(fs, params_heard.win_ms, params_heard.hop_ms, size(x_seg,1));
        end

        % select ref channel same way detect_heard_calls_v1 did
        [x_mono, ~] = read_audio(struct('x', x_seg, 'fs', fs), params_heard.ref_channel_index);

        % features on the segment frame grid
        [Slog, ~, ~] = compute_stft_logmag(x_mono, fs, FP, params_heard.bandpass);
        E = band_energy(Slog);
        F = spectral_flux_pos(Slog);

        % rolling stats (cap to the segment length)
        frames_per_window = max(1, round(params_heard.rolling_sec * 1000 / params_heard.hop_ms));
        frames_per_window = min(frames_per_window, FP.n_frames);
        [medE, madE] = rolling_stats(E, frames_per_window);
        [medF, madF] = rolling_stats(F, frames_per_window);

        % masks on the segment frame grid (all times are local to segment here)
        mask_self  = windows_to_mask(Lself_local, FP);
        mask_heard = windows_to_mask(H_local, FP);
        rim = mask_self | mask_heard;

        hop_s = infer_hop_s(FP);
        rim_frames = max(0, round((opt.SilenceEdgeMs/1000) / hop_s));
        rim_dilated = dilate_events_mask(rim, rim_frames);

        % eligible frames are inside the roi (local coords) and not in rim
        roi_local = [roi_on roi_off] - seg_offset_s;
        mask_roi_local = windows_to_mask(roi_local, FP);
        eligible = mask_roi_local & ~rim_dilated;

        % detect quiet frames
        quiet = detect_quiet_frames(E, F, medE, madE, medF, madF, opt.KSilence, eligible);

        % frames → silence events and crop to roi
        silence_seg = frames_to_events(quiet, FP, opt.MinSilenceMs, opt.MergeGapMs, opt.MaxSilenceMs);

        % shift to absolute and crop strictly to roi
        if ~isempty(silence_seg)
            silence_seg.on  = silence_seg.on  + seg_offset_s;
            silence_seg.off = silence_seg.off + seg_offset_s;
            silence_seg = crop_events_to_window(silence_seg, [roi_on roi_off]);
            silence_seg.dur = silence_seg.off - silence_seg.on;
        end

        % accumulate
        heard_all   = [heard_all;   heard_seg];    %#ok<AGROW>
        silence_all = [silence_all; silence_seg];  %#ok<AGROW>
    end

    % -- sort by onset
    if ~isempty(heard_all),   heard_all = sortrows(heard_all, 'on');   end
    if ~isempty(silence_all), silence_all = sortrows(silence_all, 'on'); end

    % -- outputs + minimal meta
    heard   = heard_all;
    silence = silence_all;

    heard.Properties.UserData.meta.roi_windows = roi_windows;
    heard.Properties.UserData.meta.context_pad_sec = opt.ContextPadSec;
    heard.Properties.UserData.meta.silence = rmfield_safe(opt, {'HeardParams'});

    silence.Properties.UserData.meta.roi_windows = roi_windows;
    silence.Properties.UserData.meta.context_pad_sec = opt.ContextPadSec;
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
    % allow a single [on off] row or Nx2
    if size(win,2) ~= 2
        error('windows_to_mask:BadShape', 'windows must be Nx2 [on off]');
    end
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

function W = merge_windows(W)
    % merge overlapping or touching windows
    if isempty(W), return; end
    W = sortrows(W,1);
    out = W(1,:);
    for i = 2:size(W,1)
        a = out(end,:); b = W(i,:);
        if b(1) <= a(2)  % overlap or touch
            out(end,2) = max(a(2), b(2));
        else
            out(end+1,:) = b; %#ok<AGROW>
        end
    end
    W = out;
end

function Lout = intersect_and_shift_windows(Lin, seg_win, offset)
    % intersect Lin with seg_win and shift by -offset to local segment time
    if isempty(Lin)
        Lout = zeros(0,2);
        return
    end
    A = Lin;
    A(:,1) = max(A(:,1), seg_win(1));
    A(:,2) = min(A(:,2), seg_win(2));
    keep = A(:,2) > A(:,1);
    A = A(keep,:);
    A = A - offset;
    Lout = A;
end

function T = crop_events_to_window(T, win)
    % crop event rows (table with on/off) to [win(1) win(2)]
    if isempty(T), return; end
    on = T.on; off = T.off;
    on = max(on, win(1));
    off = min(off, win(2));
    keep = off > on;
    T = T(keep,:);
    T.on = on(keep);
    T.off = off(keep);
    if any(ismember(T.Properties.VariableNames, 'dur'))
        T.dur = T.off - T.on;
    end
end