function state = apply_hysteresis(E, F, medE, madE, medF, madF, kHighE, kHighF, kLow, release_frames, varargin)
% apply_hysteresis
% 2-state gate (0=background, 1=call) driven by energy (E) and flux (F).
% enter when both exceed high gates for >= enter_frames consecutive frames;
% exit after both stay below low gates for >= release_frames frames.
%
% inputs are vectors; med/mad can be scalars or vectors (matched by size).
% returns a logical row vector state (1 x n_frames).

    % -- basic shape checks and normalization to row
    E = E(:).'; F = F(:).';
    n = numel(E);
    if numel(F) ~= n
        error('apply_hysteresis:invalidInput', 'E and F must have the same length.');
    end

    % -- optional params (name-value or struct), default enter_frames=1
    enter_frames = 1;
    if ~isempty(varargin)
        if numel(varargin) == 1 && isstruct(varargin{1})
            s = varargin{1};
            if isfield(s, 'enter_frames') && ~isempty(s.enter_frames)
                enter_frames = s.enter_frames;
            end
        else
            % parse simple name-value
            for k = 1:2:numel(varargin)
                name = lower(string(varargin{k}));
                if name == "enter_frames"
                    enter_frames = varargin{k+1};
                end
            end
        end
    end
    % coerce to sensible integer >=1
    if ~isscalar(enter_frames) || ~isfinite(enter_frames)
        error('apply_hysteresis:invalidParam', 'enter_frames must be a finite scalar.');
    end
    enter_frames = max(1, round(enter_frames));

    % -- expand thresholds to per-frame arrays (supports scalar or vector med/mad)
    medE = expand_to_len(medE, n);
    madE = expand_to_len(madE, n);
    medF = expand_to_len(medF, n);
    madF = expand_to_len(madF, n);

    % guard against zero MAD: treat as tiny to avoid NaN/Inf thresholds
    madE(madE == 0) = eps;
    madF(madF == 0) = eps;

    % -- compute high and low thresholds
    highE = medE + kHighE .* madE;
    highF = medF + kHighF .* madF;
    lowE  = medE + kLow   .* madE;
    lowF  = medF + kLow   .* madF;

    % -- run 2-state machine with consecutive-entry requirement
    state = false(1, n);
    in_call = false;
    below_cnt = 0;
    enter_cnt = 0;

    for i = 1:n
        above_high = (E(i) > highE(i)) && (F(i) > highF(i));
        below_low  = (E(i) <= lowE(i)) && (F(i) <= lowF(i));

        if ~in_call
            if above_high
                enter_cnt = enter_cnt + 1;
            else
                enter_cnt = 0;
            end
            if enter_cnt >= enter_frames
                in_call = true;
                below_cnt = 0;
                enter_cnt = 0; % reset after entry
            end
        else
            if below_low
                below_cnt = below_cnt + 1;
                if below_cnt >= release_frames
                    in_call = false;       % exit on the frame that completes the hold
                    below_cnt = 0;
                    enter_cnt = 0;
                end
            else
                below_cnt = 0;            % reset hold if either feature is above low
            end
        end

        state(i) = in_call;
    end
end

function v = expand_to_len(v, n)
    % helper: make v a 1xn row, repeating scalar if needed
    if isscalar(v)
        v = repmat(v, 1, n);
    else
        v = v(:).';
        if numel(v) ~= n
            error('apply_hysteresis:invalidInput', 'median/MAD vectors must match the length of E/F.');
        end
    end
end