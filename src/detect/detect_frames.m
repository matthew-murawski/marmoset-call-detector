function active = detect_frames(E, F, medE, madE, medF, madF, kE, kF, mask)
% threshold frames using energy and positive spectral flux with optional masking.
% returns a 1 x n_frames logical row vector.
%
% intent: combine robust thresholds on energy and flux, then exclude masked frames.
% candidate(i) = (E(i) > medE(i) + kE*madE(i)) && (F(i) > medF(i) + kF*madF(i))
% active = candidate & mask
%
% usage:
%   active = detect_frames(E, F, medE, madE, medF, madF, kE, kF);
%   active = detect_frames(..., mask);  % mask=true means allowed; false excludes

    % --- normalize shapes and basic checks
    E    = double(E(:)).';
    F    = double(F(:)).';
    medE = double(medE(:)).';
    madE = double(madE(:)).';
    medF = double(medF(:)).';
    madF = double(madF(:)).';

    n = numel(E);
    if any([numel(F), numel(medE), numel(madE), numel(medF), numel(madF)] ~= n)
        error('detect_frames:invalidInput', 'all inputs must have the same number of frames.');
    end
    if ~(isscalar(kE) && isscalar(kF))
        error('detect_frames:invalidK', 'kE and kF must be scalars.');
    end

    if nargin < 9 || isempty(mask)
        mask = true(1, n);
    else
        mask = logical(mask(:)).';
        if numel(mask) ~= n
            error('detect_frames:invalidMask', 'mask must match the number of frames.');
        end
    end

    if n == 0
        active = false(1, 0);
        return
    end

    % --- compute thresholds and candidate activity
    TE = medE + kE .* madE;
    TF = medF + kF .* madF;

    candidate = (E > TE) & (F > TF);
    active = candidate & mask;
    active = reshape(active, 1, []);  % enforce row shape
end