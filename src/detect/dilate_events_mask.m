function mask_out = dilate_events_mask(mask_in, frames_radius)
% dilate a 1-d logical mask by a given radius (in frames).
% uses a flat kernel convolution; o(n).

% coerce to logical row
mask = logical(mask_in(:)).';
n = numel(mask);

% validate radius
if ~(isscalar(frames_radius) && isnumeric(frames_radius) && frames_radius >= 0 && isfinite(frames_radius))
    error('dilate_events_mask:BadRadius', 'frames_radius must be a non-negative scalar.');
end
% integerize radius
r = floor(frames_radius);
if r == 0
    mask_out = mask;
    return;
end

% flat kernel of length 2*r+1
k = ones(1, 2*r + 1);

% convolution-based dilation; any overlap -> true
mask_out = conv(double(mask), k, 'same') > 0;

% ensure logical row
mask_out = logical(mask_out(:)).';
end