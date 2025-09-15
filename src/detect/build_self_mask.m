function mask = build_self_mask(self_labels, FP)
% build a per-frame boolean mask excluding frames that overlap self-vocal intervals.
% returns 1 x n_frames logical: true = allowed; false = excluded.
%
% intent:
% - map [on, off] second-intervals onto frame indices via FP.t_frames.
% - keep it minimal: no padding here; caller will pre-pad if desired.
% - ignore invalid intervals (off <= on). clip to [1, FP.n_frames].
%
% inputs:
%   self_labels: either Nx2 double [on off] in seconds, or struct array with fields .on, .off
%   FP: struct with fields:
%       - t_frames : 1 x n_frames vector of frame times (s)
%       - n_frames : scalar number of frames (optional; if missing, inferred from t_frames)
%
% notes:
% - uses a tiny tolerance when comparing times to avoid fp-edge misses at boundaries.

    % --- basic FP validation and normalization
    if ~isstruct(FP) || ~isfield(FP, 't_frames')
        error('build_self_mask:invalidFP', 'FP must be a struct with field t_frames.');
    end
    t = double(FP.t_frames(:)).';
    if isfield(FP, 'n_frames') && ~isempty(FP.n_frames)
        n = double(FP.n_frames);
    else
        n = numel(t);
    end
    if ~isscalar(n) || n < 0 || ~isfinite(n)
        error('build_self_mask:invalidFP', 'FP.n_frames must be a nonnegative scalar if provided.');
    end
    if numel(t) < n
        error('build_self_mask:invalidFP', 'FP.t_frames must have at least FP.n_frames elements.');
    end
    t = t(1:n);  % enforce length

    % --- trivial cases
    if n == 0
        mask = false(1, 0);  % empty row
        return
    end

    mask = true(1, n);

    % --- normalize labels to Nx2 [on off] in seconds
    L = zeros(0, 2);
    if isempty(self_labels)
        % nothing to exclude
        return
    elseif isnumeric(self_labels)
        if size(self_labels, 2) ~= 2
            error('build_self_mask:invalidLabels', 'numeric self_labels must be Nx2 [on off].');
        end
        L = double(self_labels);
    elseif isstruct(self_labels)
        if ~all(isfield(self_labels, {'on','off'}))
            error('build_self_mask:invalidLabels', 'struct self_labels must have fields .on and .off.');
        end
        if isempty(self_labels)
            return
        end
        on  = arrayfun(@(s) double(s.on),  self_labels(:)).';
        off = arrayfun(@(s) double(s.off), self_labels(:)).';
        L = [on(:) off(:)];
    else
        error('build_self_mask:invalidLabels', 'self_labels must be Nx2 numeric or struct with .on/.off.');
    end

    % --- apply exclusions; include boundary frames with a small tolerance
    % tolerance picks up fp rounding like 0.30000000000000004 vs 0.30
    tol = 1e-9;

    for k = 1:size(L,1)
        on  = L(k,1);
        off = L(k,2);
        if ~(isfinite(on) && isfinite(off)) || off <= on
            continue
        end
        idx = (t >= on - tol) & (t <= off + tol);
        if any(idx)
            mask(idx) = false;
        end
    end

    mask = reshape(mask, 1, []);  % enforce row
end