function [med, mad] = rolling_stats(X, frames_per_window)
% rolling median and MAD over a centered window with edge clipping.
% returns 1 x n_frames row vectors 'med' and 'mad'.
%
% intent: provide robust per-frame baselines for adaptive thresholding.
% for each frame i, use indices [i-w, i+w], where w=floor(frames_per_window/2),
% clipped to [1, n_frames]. MAD is median(|X - median_window|)*1.4826.
%
% usage:
%   [med, mad] = rolling_stats(X, frames_per_window);
%
% notes:
% - X is expected as a row vector (1 x n_frames). we accept column and reshape.
% - n_frames == 0 returns empty row vectors.
% - clarity over cleverness; simple loop per frame.

    % --- validate inputs and normalize shape
    if ~isnumeric(X) || ~isvector(X)
        error('rolling_stats:invalidInput', 'X must be a numeric vector.');
    end
    if nargin < 2 || ~isscalar(frames_per_window) || ~isfinite(frames_per_window) || frames_per_window < 1
        error('rolling_stats:invalidWindow', 'frames_per_window must be a positive scalar.');
    end

    X = double(X(:)).';         % row vector
    n = numel(X);
    med = zeros(1, n);
    mad = zeros(1, n);

    if n == 0
        med = zeros(1, 0);
        mad = zeros(1, 0);
        return
    end

    % --- centered half-window size
    w = floor(frames_per_window / 2);

    % --- compute per-frame rolling median and MAD
    c = 1.4826;                 % gaussian consistency factor
    for i = 1:n
        lo = max(1, i - w);
        hi = min(n, i + w);
        xi = X(lo:hi);
        m = median(xi);
        med(i) = m;

        % median absolute deviation within the same window
        di = abs(xi - m);
        mad_raw = median(di);
        mad(i) = c * mad_raw;
    end
end