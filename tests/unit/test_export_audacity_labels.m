function tests = test_export_audacity_labels
% unit tests for export_audacity_labels:
% - writes sorted on/off with a constant label
% - empty table → empty file
% - missing required fields → error 'export:badInput'
    tests = functiontests(localfunctions);
end

function setupOnce(t)
    % make sure our implementation in src/io is first on the path
    here = fileparts(mfilename('fullpath'));
    repo = fileparts(fileparts(here));               % tests/.. -> repo root
    src_io = fullfile(repo, 'src', 'io');
    t.applyFixture(matlab.unittest.fixtures.PathFixture(src_io));
end

function test_write_and_readback(t)
    % make a small, unsorted events table
    on  = [1.200, 0.500, 2.000];
    off = [1.500, 0.800, 2.300];
    events = table(on(:), off(:), 'VariableNames', {'on','off'});

    % temp file path
    fp = [tempname, '.txt'];
    label = 'heard';

    % export
    export_audacity_labels(fp, events, label);

    % read back
    raw = '';
    if exist(fp, 'file')
        raw = fileread(fp);
    end
    t.assertNotEmpty(raw, 'export should write non-empty file for non-empty table');

    % split into lines (robust to different newline styles)
    lines = regexp(raw, '\r\n|\n|\r', 'split');
    lines = lines(~cellfun('isempty', lines));

    % expected: sorted by onset
    [~, idx] = sort(on);
    on_s  = on(idx);
    off_s = off(idx);

    exp = cell(numel(on_s),1);
    for i = 1:numel(on_s)
        exp{i} = sprintf('%.6f\t%.6f\t%s', on_s(i), off_s(i), label);
    end

    t.verifyEqual(lines(:), exp(:));
end

function test_empty_table_writes_empty_file(t)
    % empty events table with required vars
    events = table('Size',[0 2], ...
        'VariableTypes', {'double','double'}, ...
        'VariableNames', {'on','off'});

    fp = [tempname, '.txt'];
    export_audacity_labels(fp, events, "heard");

    % file should exist and be empty
    t.assertTrue(exist(fp, 'file') == 2, 'file was not created');
    info = dir(fp);
    t.verifyEqual(info.bytes, 0, 'empty table should produce empty file');

    % also confirm fileread returns empty
    if info.bytes == 0
        raw = fileread(fp);
        t.verifyEqual(raw, '', 'empty file should read as empty string');
    end
end

function test_missing_fields_errors(t)
    % table missing 'on'/'off' should error with 'export:badInput'
    bad = table( (1:3).', (2:4).', 'VariableNames', {'start','stop'});
    fp = [tempname, '.txt'];
    t.verifyError(@() export_audacity_labels(fp, bad, 'heard'), 'export:badInput');
end