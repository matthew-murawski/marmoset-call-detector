function tests = test_runner_smoke
% smoke-test the runner script by stubbing detector/export and verifying the i/o behavior.
tests = functiontests(localfunctions);
end

function setupOnce(t)
    % locate repo root and ensure scripts/ is on path so we can call the runner by name
    here = fileparts(mfilename('fullpath'));
    repo_root = fileparts(fileparts(here));   % tests/e2e -> tests -> repo root
    scripts_dir = fullfile(repo_root, 'scripts');
    assert(isfolder(scripts_dir), 'expected scripts/ folder at %s', scripts_dir);
    addpath(scripts_dir);

    % make a temp working dir for fixtures + stubs
    t.TestData.tmp = tempname;
    mkdir(t.TestData.tmp);

    % create a simple wav fixture
    fs = 16000;
    dur_s = 0.5;
    tvec = (0:1/fs:dur_s).';
    y = 0.01 * randn(size(tvec));  % tiny noise, content irrelevant for this smoke test
    wav_path = fullfile(t.TestData.tmp, 'dummy.wav');
    audiowrite(wav_path, y, fs);
    t.TestData.wav_path = wav_path;

    % create a simple self_labels MAT (Nx2 double); can be empty or arbitrary
    self_labels = zeros(0,2); %#ok<NASGU>
    labels_mat = fullfile(t.TestData.tmp, 'self_labels.mat');
    save(labels_mat, 'self_labels');
    t.TestData.labels_mat = labels_mat;

    % path for exported labels
    out_txt = fullfile(t.TestData.tmp, 'heard_labels.txt');
    t.TestData.out_txt = out_txt;

    % create stub dependencies in the temp dir and ensure they are first on path
    addpath(t.TestData.tmp, '-begin');

    % stub: detect_heard_calls_v1 returns a fixed 3-event table with proper columns
    det_fn = fullfile(t.TestData.tmp, 'detect_heard_calls_v1.m');
    fid = fopen(det_fn, 'w');
    cleanupObj1 = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, '%s\n', [
        'function heard = detect_heard_calls_v1(~, ~, ~)', newline, ...
        '% stub detector: fixed three events', newline, ...
        'on  = [0.10; 0.50; 1.00];', newline, ...
        'off = [0.20; 0.70; 1.30];', newline, ...
        'dur = off - on;', newline, ...
        'confidence = [0.9; 0.8; 0.95];', newline, ...
        'heard = table(on, off, dur, confidence);', newline, ...
        '% attach params in table userdata to mimic spec ''plus meta.params''', newline, ...
        'heard.Properties.UserData.params = struct(''stub'', true);', newline, ...
        'end' ...
    ]);

    % stub: export_audacity_labels writes start<TAB>stop<TAB>label per row
    exp_fn = fullfile(t.TestData.tmp, 'export_audacity_labels.m');
    fid2 = fopen(exp_fn, 'w');
    cleanupObj2 = onCleanup(@() fclose(fid2)); %#ok<NASGU>
    fprintf(fid2, '%s\n', [
        'function export_audacity_labels(filename_txt, events_table, label_text)', newline, ...
        '% stub exporter: write one line per event', newline, ...
        'fid = fopen(filename_txt, ''w'');', newline, ...
        'cobj = onCleanup(@() fclose(fid)); %#ok<NASGU>', newline, ...
        'for i = 1:height(events_table)', newline, ...
        '    fprintf(fid, ''%.6f\t%.6f\t%s\n'', events_table.on(i), events_table.off(i), label_text);', newline, ...
        'end', newline, ...
        'end' ...
    ]);
end

function teardownOnce(t)
    % remove temp dir from path and delete it
    if isfield(t.TestData, 'tmp') && ~isempty(t.TestData.tmp)
        rmpath(t.TestData.tmp);
        try, rmdir(t.TestData.tmp, 's'); end %#ok<TRYNC>
    end
end

function test_runner_writes_labels_file(t)
    % call the runner with arguments, capturing console output
    cmd = sprintf('run_detect_heard_calls(''%s'',''%s'',''%s'')', ...
        t.TestData.wav_path, t.TestData.labels_mat, t.TestData.out_txt);
    evalc(cmd);  % suppress printed summary; errors will still surface

    % verify file exists
    assert(isfile(t.TestData.out_txt), 'expected labels file at %s', t.TestData.out_txt);

    % verify expected number of non-empty lines (3 from the stub)
    txt = fileread(t.TestData.out_txt);
    % split on either \n or \r\n, filter empties
    lines = regexp(txt, '\r?\n', 'split');
    if ~isempty(lines) && isempty(lines{end})
        lines(end) = []; % drop trailing empty after final newline
    end
    verifyEqual(t, numel(lines), 3);
end