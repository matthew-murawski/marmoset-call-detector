function [Slog, f, t] = compute_stft_logmag(x, fs, FP, bandpass)
% compute log-magnitude stft, then band-limit rows to [bandpass(1), bandpass(2)].
% uses hann window of length FP.win_samp and hop FP.hop_samp.
% returns:
%   Slog: log(eps + |S|) with size [n_freq_kept, FP.n_frames]
%   f: frequencies (hz) for kept rows
%   t: times (s), aligned to FP.t_frames

    % -- validate bandpass
    if ~(isnumeric(bandpass) && numel(bandpass) == 2 && all(isfinite(bandpass)))
        error('stft:badBand', 'bandpass must be a 1x2 finite numeric vector.');
    end
    bp = double(bandpass(:))';
    if ~(bp(1) > 0 && bp(2) <= fs/2 && bp(1) < bp(2))
        error('stft:badBand', 'bandpass must satisfy 0 < low < high <= fs/2.');
    end

    % -- coerce signal to column vector
    x = double(x(:));
    nfft = 2^nextpow2(FP.win_samp);

    % -- hann window (fallback if hann unavailable)
    if exist('hann','file') == 2
        w = hann(FP.win_samp, 'periodic');
    elseif exist('hanning','file') == 2 %#ok<*HANN>
        w = hanning(FP.win_samp, 'periodic');
    else
        n = (0:FP.win_samp-1).';
        w = 0.5 - 0.5*cos(2*pi*n/FP.win_samp);
    end
    noverlap = FP.win_samp - FP.hop_samp;

    % -- compute stft
    [S, f_all, t_all] = spectrogram(x, w, noverlap, nfft, fs);

    % -- ensure time alignment to provided frame grid
    % spectrogram's centers match the frame formula; we snap to FP.t_frames for determinism
    t = FP.t_frames;

    % -- band-limit rows
    keep = (f_all >= bp(1)) & (f_all <= bp(2));
    f = f_all(keep);

    % -- magnitude -> log
    Sab = abs(S(keep, :));
    Slog = log(eps + Sab);

    % -- enforce shape on degenerate cases
    % if spectrogram produced a different number of frames due to edge rounding,
    % trim or pad to match FP.n_frames (should rarely trigger).
    nf = FP.n_frames;
    if size(Slog,2) ~= nf
        if size(Slog,2) > nf
            Slog = Slog(:, 1:nf);
        else
            % pad with last column (or zeros if empty) to reach nf
            if isempty(Slog)
                Slog = zeros(numel(f), nf);
            else
                lastcol = Slog(:, end);
                Slog = [Slog, repmat(lastcol, 1, nf - size(Slog,2))]; %#ok<AGROW>
            end
        end
    end
end