function F = spectral_flux_pos(Slog)
% positive spectral flux per frame from a log-magnitude spectrogram.
% returns a 1 x n_frames row vector.
%
% intent: capture frame-to-frame increases in spectral magnitude (onsets/changes),
% ignoring decreases. computed as:
%   M = exp(Slog)                          % back to linear magnitude
%   D = [zeros(nf,1), diff(M,1,2)]         % temporal diff along frames
%   D(D < 0) = 0                           % keep only positive deltas
%   F = sum(D, 1)                          % sum across frequency bins
%
% usage:
%   F = spectral_flux_pos(Slog);  % Slog is [n_freq x n_frames] log-mag

    % --- basic validation
    if ~isnumeric(Slog) || ndims(Slog) > 2
        error('spectral_flux_pos:invalidInput', 'Slog must be a 2d numeric array.');
    end

    % --- convert to linear magnitude and compute positive temporal deltas
    M = exp(Slog);
    if isempty(M)
        F = zeros(1, 0);
        return
    end
    D = [zeros(size(M,1), 1), diff(M, 1, 2)];
    D(D < 0) = 0;

    % --- collapse across frequency bins and enforce row shape
    F = sum(D, 1);
    F = reshape(F, 1, []);
end