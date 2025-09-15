function is_active = detect_frames(e, fpos, medE, madE, medF, madF, kE, kF, k_low, self_mask)
% detect_frames
% energy/flux thresholding with optional self-mask to suppress detections.
% % this is a placeholder stub. real logic will be added in later prompts.

%
% inputs
%   e, fpos: feature time series (1 x time)
%   medE, madE, medF, madF: rolling stats
%   kE, kF, k_low: threshold multipliers
%   self_mask: optional logical row vector to exclude frames
%
% output
%   is_active: 1 x time boolean frame activity (pre-hysteresis)

%#ok<*INUSD>
is_active = [];
end
