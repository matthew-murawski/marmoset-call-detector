function mask = build_roi_mask(windows, FP)
% build_roi_mask
% make a logical frame mask (true = allowed) from roi windows on the frame grid.
%
% behavior:
% - if windows is empty, returns all true (no restriction).
% - includes frames whose centers lie in any [on, off) window.
%
% inputs
%   windows : Nx2 [on off] in seconds (can be empty)
%   FP      : frame params struct; must have FP.t_frames (frame-center times in s)

    % -- get frame-center times; prefer t_frames to avoid relying on n_frames
    if isfield(FP, 't_frames') && ~isempty(FP.t_frames)
        tf = FP.t_frames(:).';
    else
        error('build_roi_mask:MissingFrameTimes', ...
              'FP must include t_frames (frame-center times in seconds).');
    end
    n = numel(tf);

    % -- no roi → allow all frames
    if isempty(windows)
        mask = true(1, n);
        return
    end

    % -- normalize windows to Nx2
    if isvector(windows)
        if numel(windows) ~= 2
            error('build_roi_mask:BadWindows', 'windows must be Nx2 [on off] or [].');
        end
        windows = reshape(windows, 1, 2);
    end

    % -- accumulate membership across windows
    mask = false(1, n);
    for i = 1:size(windows, 1)
        on  = double(windows(i,1));
        off = double(windows(i,2));
        if ~(isfinite(on) && isfinite(off)) || off <= on
            continue  % skip bad or empty windows
        end
        mask = mask | (tf >= on & tf < off);
    end
end