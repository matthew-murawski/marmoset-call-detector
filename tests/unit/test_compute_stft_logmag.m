function tests = test_compute_stft_logmag
% unit tests for compute_stft_logmag (stft + log-mag + band-limit).
tests = functiontests(localfunctions);
end

function test_two_tone_energy_concentrates(tst)
% generate 2-tone (6 khz + 9 khz) and verify peaks in band-limited spectrum
    fs = 48000;
    dur = 1.0;                     % seconds
    t = (0:round(dur*fs)-1) / fs;
    x = sin(2*pi*6000*t) + 0.9*sin(2*pi*9000*t);  % slight amplitude difference ok

    win_ms = 25;
    hop_ms = 10;
    FP = frame_params(fs, win_ms, hop_ms, numel(x));

    bandpass = [5000 12000];
    [Slog, f, tt] = compute_stft_logmag(x, fs, FP, bandpass);

    % shapes
    verifyGreaterThan(tst, size(Slog,1), 0);                    % some rows kept
    verifyEqual(tst, size(Slog,2), FP.n_frames);                % columns match frames
    verifyEqual(tst, numel(tt), FP.n_frames);                   % time alignment

    % average over time to get spectral envelope
    m = mean(Slog, 2);

    % top-2 peaks should be near 6k and 9k
    [~, idxTop] = maxk(m, 2);
    fTop = sort(f(idxTop));

    verifyLessThan(tst, abs(fTop(1) - 6000), 200);              % within 200 hz
    verifyLessThan(tst, abs(fTop(2) - 9000), 200);

    % sanity: band-limited grid sits within requested passband
    verifyGreaterThanOrEqual(tst, min(f), bandpass(1) - 1e-9);
    verifyLessThanOrEqual(tst, max(f), bandpass(2) + 1e-9);
end

function test_bad_bandpass_errors(tst)
% invalid bandpass should error with specified id
    fs = 48000; win_ms = 25; hop_ms = 10; n = fs;
    FP = frame_params(fs, win_ms, hop_ms, n);
    x = zeros(n,1);

    fcn = @() compute_stft_logmag(x, fs, FP, [0 1000]); % lower must be >0
    verifyError(tst, fcn, 'stft:badBand');

    fcn = @() compute_stft_logmag(x, fs, FP, [1000 1000]); % lower<upper
    verifyError(tst, fcn, 'stft:badBand');

    fcn = @() compute_stft_logmag(x, fs, FP, [1000 fs]); % upper <= fs/2
    verifyError(tst, fcn, 'stft:badBand');
end
