function mask = build_roi_mask(windows, FP)
% build a frame-level roi mask from time windows.
% windows: Nx2 [on off] in seconds (closed-open). empty -> all true.
% FP: struct with FP.t_frames (sec) and FP.n_frames.

% handle empty or malformed inputs up front
if isempty(windows)
    mask = true(1, FP.n_frames);
    return;
end
if size(windows,2) ~= 2
    error('build_roi_mask:BadWindows', 'windows must be Nx2 [on off] in seconds.');
end

% drop rows with nans or non-positive width
bad = any(isnan(windows), 2) | (windows(:,2) <= windows(:,1));
windows = windows(~bad, :);

% if nothing valid remains, keep everything
if isempty(windows)
    mask = true(1, FP.n_frames);
    return;
end

% ensure row vector outputs; compare using closed-open rule
t = FP.t_frames(:)';              % 1 x n
on  = windows(:,1);               % nW x 1
off = windows(:,2);               % nW x 1

% implicit expansion (r2016b+) for vectorized interval membership
in_any = (t >= on) & (t < off);   % nW x nFrames
mask = any(in_any, 1);            % 1 x nFrames

% enforce type/shape and exact length
mask = logical(mask);
if ~isrow(mask), mask = reshape(mask, 1, []); end
n = FP.n_frames;
if numel(mask) ~= n
    % be defensive if FP.n_frames disagrees with t_frames
    mask = mask(1:min(end, n));
    if numel(mask) < n
        mask(1, n) = false; % extend with false
    end
end
end