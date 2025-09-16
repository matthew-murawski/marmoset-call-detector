function quiet = detect_quiet_frames(E, F, medE, madE, medF, madF, k_silence, mask)
% detect quiet frames where both features are below (median + k_silence*mad) within mask.
% outputs a logical row vector; nans are treated as non-quiet.

% coerce to row vectors
E = E(:).'; 
F = F(:).';
mask = logical(mask(:).');

n = numel(E);
if numel(F) ~= n || numel(mask) ~= n
    error('detect_quiet_frames:SizeMismatch', 'E, F, and mask must have the same length.');
end

% thresholds
thrE = medE + k_silence * madE;
thrF = medF + k_silence * madF;

% core logic (nans are non-quiet)
quiet = (E < thrE) & (F < thrF) & mask & ~isnan(E) & ~isnan(F);

% ensure logical row vector
quiet = logical(quiet(:)).';
end