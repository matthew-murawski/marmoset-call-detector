function benchmark_one_clip
% benchmark_one_clip
% quick runtime check on a 60 s synthetic clip.
%
% what this does:
% - generates a 60 s synthetic wav (tiny noise + a few chirps),
% - runs detect_heard_calls_v1 with default params,
% - prints elapsed time and the real-time factor x_rt = duration / elapsed,
% - on a developer machine (CI env var absent), asserts x_rt >= 1.
%
% notes:
% - this is a simple sanity/perf harness; absolute timing depends on your machine.
% - it writes a temp wav file, then cleans it up.

    % --- guard: make sure the detector exists
    if exist('detect_heard_calls_v1', 'file') ~= 2
        error('benchmark_one_clip:missingDetector', ...
            'detect_heard_calls_v1 not found on path. build v1 before running the benchmark.');
    end

    % --- synthetic audio
    fs = 16000;
    dur_s = 60;
    t = (0:1/fs:dur_s).';                             % column vector
    x = 0.005 * randn(size(t));                       % low-amplitude noise

    % sprinkle a few synthetic "heard" chirps (up-sweeps) for realism (not strictly needed)
    chirp_onsets = [5 12 20 33 41 50];                % seconds
    for k = 1:numel(chirp_onsets)
        on = chirp_onsets(k);
        len = 0.15;                                   % 150 ms
        idx = max(1, round(on*fs)) : min(numel(t), round((on+len)*fs));
        tt = (0:numel(idx)-1)'/fs;
        x(idx) = x(idx) + 0.02 * chirp(tt, 4000, len, 9000, 'linear');
    end

    % --- write to a temp wav so we exercise the I/O path used in normal workflows
    tmpdir = tempname;
    mkdir(tmpdir);
    wav_path = fullfile(tmpdir, 'bench.wav');
    audiowrite(wav_path, x, fs);

    % --- empty self labels
    self_labels = zeros(0,2);

    % --- default params (match spec)
    params = struct();
    params.bandpass        = [5e3, 12e3];
    params.win_ms          = 25;
    params.hop_ms          = 10;
    params.rolling_sec     = 60;
    params.kE              = 3.5;
    params.kF              = 3.0;
    params.k_low           = 2.0;
    params.release_frames  = 2;
    params.min_event_ms    = 70;
    params.merge_gap_ms    = 50;
    params.max_event_ms    = 4000;
    params.pre_pad_ms      = 30;
    params.post_pad_ms     = 100;

    % --- run and time
    t0 = tic;
    heard = detect_heard_calls_v1(wav_path, self_labels, params); %#ok<NASGU>
    elapsed = toc(t0);
    x_rt = dur_s / max(elapsed, eps);

    fprintf('benchmark_one_clip: dur=%.1f s, elapsed=%.3f s, x_rt=%.2fx\n', dur_s, elapsed, x_rt);

    % --- assert real-time on developer machine (skip in CI)
    is_ci = ~isempty(getenv('CI'));
    if ~is_ci
        assert(x_rt >= 1, 'expected real-time (x_rt >= 1), got %.2f', x_rt);
    end

    % --- cleanup
    try, rmdir(tmpdir, 's'); end %#ok<TRYNC>
end
