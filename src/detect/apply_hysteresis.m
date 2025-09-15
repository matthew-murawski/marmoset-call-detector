function state = apply_hysteresis(E, F, medE, madE, medF, madF, kHighE, kHighF, kLow, release_frames)
% apply_hysteresis
% 2-state gate (0=background, 1=call) driven by energy (E) and flux (F).
% enter when both exceed high gates; exit after both stay below low gates
% for >= release_frames consecutive frames.
%
% inputs are vectors; med/mad can be scalars or vectors (matched by size).
% returns a logical row vector state (1 x n_frames).

    % -- basic shape checks and normalization to row
    E = E(:).'; F = F(:).';
    n = numel(E);
    if numel(F) ~= n
        error('apply_hysteresis:invalidInput', 'E and F must have the same length.');
    end

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

    % -- run 2-state machine
    state = false(1, n);
    in_call = false;
    below_cnt = 0;

    for i = 1:n
        enter_now = (E(i) > highE(i)) && (F(i) > highF(i));
        below_low = (E(i) <= lowE(i)) && (F(i) <= lowF(i));

        if ~in_call
            if enter_now
                in_call = true;
                below_cnt = 0;
            end
        else
            if below_low
                below_cnt = below_cnt + 1;
                if below_cnt >= release_frames
                    in_call = false;  % exit on the frame that completes the hold
                    below_cnt = 0;
                end
            else
                below_cnt = 0;  % reset hold if either feature pops above low
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