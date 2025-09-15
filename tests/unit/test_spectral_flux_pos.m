function tests = test_spectral_flux_pos
% unit tests for spectral_flux_pos.
% test 1: step increase → single-frame spike in flux.
% test 2: constant tone (synthetic Slog) → low flux inside the tone, with
%         concentrated flux at onset and near offset.

    tests = functiontests(localfunctions);
end

function test_step_increase_spikes_once(testCase)
    % 3 freqs x 5 frames; baseline magnitude = 1, step up at frame 3
    nf = 3; nT = 5;
    M = ones(nf, nT);
    inc = [0.5; 0.2; 0.3];              % per-bin increase
    M(:,3:end) = M(:,3:end) + inc;      % step occurs between frames 2->3

    Slog = log(M);                       % log-mag input
    F = spectral_flux_pos(Slog);

    % expected: only frame 3 has positive flux equal to sum(inc)
    expected = zeros(1, nT);
    expected(3) = sum(inc);

    verifySize(testCase, F, [1 nT]);
    verifyEqual(testCase, F, expected, 'AbsTol', 1e-12);
end

function test_constant_tone_flux_at_edges(testCase)
    % build a synthetic "tone": one bin is high for a contiguous block.
    % add a tiny pre-offset bump so there's positive flux just before offset.
    nf = 8; nT = 30;
    k = 5;              % "tone" bin index
    A = 2.0;            % magnitude during tone
    M = zeros(nf, nT);

    on_frame  = 11;     % onset frame
    off_frame = 21;     % first frame after tone (tone spans 11..20)
    M(k, on_frame:off_frame-2) = A;        % 11..19 at A
    M(k, off_frame-1) = A + 0.2;           % slight rise at frame 20 (pre-offset bump)

    % convert to log, with an epsilon to avoid -Inf
    Slog = log(M + eps);
    F = spectral_flux_pos(Slog);

    % flux should be ~zero away from edges
    interior_idx = [1:on_frame-2, on_frame+1:off_frame-3, off_frame+1:nT];
    if ~isempty(interior_idx)
        verifyLessThanOrEqual(testCase, max(F(interior_idx)), 1e-6);
    end

    % top 2 flux peaks should appear at onset (frame 11) and near offset (frame 20)
    [~, order] = sort(F, 'descend');
    top2 = sort(order(1:2));  % sort for stable comparison
    verifyEqual(testCase, top2, sort([on_frame, off_frame-1]));

    % also check they are meaningfully larger than background
    bg_med = median(F(interior_idx));
    verifyGreaterThan(testCase, F(on_frame), 10*max(bg_med, 1e-12));
    verifyGreaterThan(testCase, F(off_frame-1), 1e-3);  % small but > 0
end