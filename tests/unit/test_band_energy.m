function tests = test_band_energy
% unit tests for band_energy.
% test 1: simple numeric check on a small matrix with known values.
% test 2: synthetic signal (silence -> tone -> silence); energy median during tone
%         should exceed median during silence when computed from a spectrogram-based Slog.

    tests = functiontests(localfunctions);
end

function test_small_numeric_sum(testCase)
    % build a tiny Slog where exp(Slog) is known exactly
    % Slog is [n_freq x n_frames]; here 2 x 3
    A = [1 2 3; 4 5 6];     % magnitudes
    Slog = log(A);          % log-magnitude
    E = band_energy(Slog);  % should sum by column → [5 7 9]

    verifyEqual(testCase, E, [5 7 9], 'AbsTol', 1e-12);
    % enforce shape is row
    verifySize(testCase, E, [1 3]);
end

function test_tone_has_higher_energy_than_silence(testCase)
    % synthetic: 0.5 s silence, 0.5 s tone (8 kHz), 0.5 s silence
    fs   = 48000;
    dur0 = 0.5;  % s
    dur1 = 0.5;  % s
    t0 = zeros(round(dur0*fs),1);
    t1 = sin(2*pi*8000*(0:round(dur1*fs)-1)'/fs);  % 8 kHz in the 5–12 kHz band
    x = [t0; t1; t0];

    % stft params ~ C1 defaults: win=25 ms, hop=10 ms
    win_samp = round(0.025*fs);
    hop_samp = round(0.010*fs);
    noverlap = max(win_samp - hop_samp, 0);
    nfft = 4096;

    % compute spectrogram; S is complex, F in Hz, T in s
    % note: this uses Signal Processing Toolbox 'spectrogram'.
    [S, F, T] = spectrogram(x, win_samp, noverlap, nfft, fs);

    % band-limit to 5–12 kHz
    band_lo = 5e3; band_hi = 12e3;
    ib = F >= band_lo & F <= band_hi;
    S_band = S(ib, :);

    % log-magnitude with a tiny floor for stability
    Slog = log(abs(S_band) + eps);

    % compute band energy
    E = band_energy(Slog);

    % pick time masks safely away from boundaries to avoid window bleed
    pre_mask  = T >= 0.10 & T <= (dur0 - 0.10);                 % early silence
    tone_mask = T >= (dur0 + 0.10) & T <= (dur0 + dur1 - 0.10); % tone interior

    % sanity: ensure we have frames in both masks
    verifyGreaterThan(testCase, nnz(pre_mask), 3);
    verifyGreaterThan(testCase, nnz(tone_mask), 3);

    med_sil  = median(E(pre_mask));
    med_tone = median(E(tone_mask));

    verifyGreaterThan(testCase, med_tone, med_sil);
end