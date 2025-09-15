function [x, fs, self_labels, heard_truth] = make_synthetic_track()
% make a 30 s mono synthetic track at fs=48k:
% - low-level white/pink-ish noise background
% - three 'heard' 7 khz tone bursts (200 / 500 / 1000 ms)
% - two 'self' bursts (masked out by the detector)
%
% returns:
%   x            : column vector audio (double)
%   fs           : sample rate (hz)
%   self_labels  : nx2 [on off] (s) for self bursts (un-padded)
%   heard_truth  : mx2 [on off] (s) for planted heard bursts

    fs  = 48000;
    dur = 30.0; % seconds
    n   = round(dur * fs);

    % background low-level colored-ish noise (simple 1st-order lowpass of white)
    w = randn(n,1);
    a = 0.95;                        % poles near DC → 1/f-ish color
    b = 1-a;
    bg = filter(b, [1 -a], w);
    bg = bg / max(abs(bg)+eps) * 0.02;  % scale small

    % event frequencies and amplitudes
    f_tone = 7000;  % hz
    amp_heard = 0.25;
    amp_self  = 0.25;

    % heard events (on, off) in seconds
    heard_truth = [
        5.000   5.200;   % 200 ms
        12.300  12.800;  % 500 ms
        22.500  23.500   % 1000 ms
    ];

    % self events (on, off) in seconds (elsewhere; non-overlapping)
    self_labels = [
        8.000   8.400;
        18.000  18.600
    ];

    % build tone helper
    function add_tone(seg_on, seg_off, amp)
        i0 = max(1, round(seg_on  * fs) + 1);
        i1 = min(n, round(seg_off * fs));
        t  = ((i0:i1).' - 1) / fs;
        bg(i0:i1) = bg(i0:i1) + amp * sin(2*pi*f_tone*t);
    end

    % add heard tones
    for k = 1:size(heard_truth,1)
        add_tone(heard_truth(k,1), heard_truth(k,2), amp_heard);
    end
    % add self tones
    for k = 1:size(self_labels,1)
        add_tone(self_labels(k,1), self_labels(k,2), amp_self);
    end

    % final signal
    x = double(bg);
end