function x = make_sine(fs, dur_s, f_hz, amp)
% make_sine  generate a simple sine tone as a column vector.
%
% inputs:
%   fs     - sample rate (hz)
%   dur_s  - duration (s)
%   f_hz   - frequency (hz)
%   amp    - amplitude (default 0.1)
%
% outputs:
%   x      - column vector (double)

    % set defaults and validate lightly
    if nargin < 4 || isempty(amp), amp = 0.1; end
    if fs <= 0 || dur_s <= 0 || f_hz < 0
        error('make_sine:invalidInput', 'fs, dur_s must be > 0 and f_hz >= 0.');
    end

    n = max(1, round(dur_s * fs));
    t = (0:n-1).' / fs;
    x = double(amp) * sin(2*pi*double(f_hz) * t);
end
