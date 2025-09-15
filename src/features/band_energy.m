function E = band_energy(Slog)
% compute per-frame band energy from a log-magnitude spectrogram.
% returns a 1 x n_frames row vector.
%
% intent: collapse the (band-limited) spectrogram over frequency by summing
% magnitudes per frame. we exponentiate because Slog is log-magnitude.
%
% usage:
%   E = band_energy(Slog);  % Slog is [n_freq x n_frames] log-mag
%
% notes:
% - we keep shapes predictable: E is always 1 x n_frames.
% - minimal input checks; this is an internal helper and tests cover the basics.

    % --- basic validation
    if ~isnumeric(Slog) || ndims(Slog) > 2
        error('band_energy:invalidInput', 'Slog must be a 2d numeric array.');
    end

    % --- sum magnitudes across frequency rows
    % use exp(Slog) because Slog encodes log-magnitude
    E = sum(exp(Slog), 1);
    E = reshape(E, 1, []);  % enforce row vector
end