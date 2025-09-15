function FP = frame_params(fs, win_ms, hop_ms, n_samples)
% convert window/hop in ms to samples and compute frame indexing metadata.
% frames start at sample 1. frame center time is
% (start_idx + win_samp/2 - 1)/fs in seconds.

    % -- basic validation
    if ~(isscalar(fs) && isnumeric(fs) && isfinite(fs) && fs > 0)
        error('frame_params:invalidArgs', 'fs must be a positive finite scalar.');
    end
    if ~(isscalar(win_ms) && isnumeric(win_ms) && isfinite(win_ms) && win_ms > 0)
        error('frame_params:invalidArgs', 'win_ms must be a positive finite scalar.');
    end
    if ~(isscalar(hop_ms) && isnumeric(hop_ms) && isfinite(hop_ms) && hop_ms > 0)
        error('frame_params:invalidArgs', 'hop_ms must be a positive finite scalar.');
    end
    if ~(isscalar(n_samples) && isnumeric(n_samples) && isfinite(n_samples) && n_samples >= 0)
        error('frame_params:invalidArgs', 'n_samples must be a nonnegative finite scalar.');
    end

    % -- convert ms to samples (ensure integer counts >= 1)
    win_samp = max(1, round(fs * (win_ms/1000)));
    hop_samp = max(1, round(fs * (hop_ms/1000)));

    % -- compute number of frames (nonnegative)
    n_frames = max(0, floor((n_samples - win_samp) / hop_samp) + 1);

    % -- compute frame center times (seconds)
    if n_frames > 0
        start_idx = 1 + (0:(n_frames-1)) * hop_samp;        % 1-based start indices
        center_samp = start_idx + (win_samp/2) - 1;         % center position in samples
        t_frames = center_samp / fs;                        % row vector (1 x n_frames)
    else
        t_frames = zeros(1,0);                              % 1x0 empty row vector
    end

    % -- package output
    FP = struct( ...
        'win_samp', win_samp, ...
        'hop_samp', hop_samp, ...
        'n_frames', n_frames, ...
        't_frames', t_frames);
end