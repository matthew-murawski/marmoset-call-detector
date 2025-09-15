function [x, fs] = read_audio(input, ref_channel_index)
% read_audio  load audio and select a reference channel, returning a column vector (double).
%
% usage:
%   [x, fs] = read_audio(wav_path, ref_channel_index)
%   [x, fs] = read_audio(struct('x', NxC, 'fs', fs), ref_channel_index)
%
% intent:
% - accept either a wav file path or a struct with fields .x (samples x channels) and .fs (hz).
% - if ref_channel_index is omitted, default to channel 2 when available (c>=2), else channel 1.
% - validate inputs and always return x as a column vector (double) with fs as double.
%
% error behavior:
% - on any bad input or invalid channel selection, throw 'read_audio:invalidInput'.

    % --- normalize and load input
    if ischar(input) || (isstring(input) && isscalar(input))
        % path case: must exist and be a .wav (be lenient on case)
        p = char(input);
        if ~(exist(p, 'file') == 2) || isempty(regexpi(p, '\.wav$'))
            error('read_audio:invalidInput', 'expected an existing .wav file path.');
        end
        try
            [x_raw, fs_raw] = audioread(p);
        catch
            error('read_audio:invalidInput', 'failed to read wav file.');
        end
        x_mat = x_raw;
        fs = double(fs_raw);
    elseif isstruct(input) && isfield(input, 'x') && isfield(input, 'fs')
        x_mat = input.x;
        fs = double(input.fs);
    else
        error('read_audio:invalidInput', 'input must be a wav path or struct with fields .x and .fs.');
    end

    % --- basic validation
    if isempty(x_mat) || ~isnumeric(x_mat)
        error('read_audio:invalidInput', 'audio data is empty or not numeric.');
    end
    if ~isscalar(fs) || ~isfinite(fs) || fs <= 0
        error('read_audio:invalidInput', 'sampling rate fs must be a positive finite scalar.');
    end

    % ensure 2d shape [N x C]
    if isvector(x_mat)
        x_mat = x_mat(:); % columnize
    elseif ndims(x_mat) ~= 2
        error('read_audio:invalidInput', 'audio data must be 1d or 2d numeric array.');
    end

    % --- determine channel to use
    [~, C] = size(x_mat);
    if nargin < 2 || isempty(ref_channel_index)
        if C >= 2
            ch = 2;
        else
            ch = 1;
        end
    else
        ch = double(ref_channel_index);
        if ~isscalar(ch) || ~isfinite(ch) || ch ~= floor(ch)
            error('read_audio:invalidInput', 'ref_channel_index must be a finite integer scalar.');
        end
        if ch < 1 || ch > C
            error('read_audio:invalidInput', 'ref_channel_index out of range for available channels.');
        end
    end

    % --- select channel and cast to double column
    x = double(x_mat(:, ch));
end