classdef test_runner_prewindow_smoke < matlab.unittest.TestCase
    % checks that the runner, when given produced onsets and a 5 s pre-window,
    % only emits heard events inside [0, 5) for a toy clip with an obvious burst.
    
    methods (Test)
        function prewindow_heard_only_in_roi(testCase)
            % --- setup temp workspace
            tmpdir = tempname;
            mkdir(tmpdir);
            wav_path = fullfile(tmpdir, 'toy.wav');
            produced_txt = fullfile(tmpdir, 'produced.txt');
            heard_txt = fullfile(tmpdir, 'heard.txt');
            
            % --- synthesize a tiny clip with one obvious narrowband burst (9 kHz) at 3.9–4.1 s
            fs = 48000;                             % <-- raised fs so 12 kHz bandpass is valid
            T = 10.0;
            t = (0:round(T*fs)-1)'/fs;
            x = 0.01*randn(size(t));               % low background
            burst_idx = t >= 3.9 & t <= 4.1;
            x(burst_idx) = x(burst_idx) + 0.15*sin(2*pi*9000*t(burst_idx));  % 9 kHz sits well inside 5–12 kHz
            
            audiowrite(wav_path, x, fs);
            
            % --- produced onset at exactly 5.0 s → ROI is [0, 5)
            fid = fopen(produced_txt, 'w');
            fprintf(fid, '5.000\t5.250\tproduced\n');
            fclose(fid);
            
            % --- run the conservative pre-window mode
            run_detect_heard_calls(wav_path, heard_txt, ...
                'ProducedLabels', produced_txt, ...
                'PreWindowSec', 5, ...
                'Conservative', true);
            
            % --- parse the heard labels back in
            [on, off] = local_read_audacity(heard_txt);
            
            testCase.assertGreaterThanOrEqual(numel(on), 1, ...
                'expected at least one heard event inside the ROI');
            testCase.assertGreaterThanOrEqual(min(on), 0.0, 'onsets must be >= 0');
            testCase.assertLessThan(max(on), 5.0, 'onsets must be < 5.0 s (inside ROI)');
            testCase.assertLessThanOrEqual(max(off), 5.0, 'offsets must be <= 5.0 s (inside ROI)');
        end
    end
end

function [on, off] = local_read_audacity(txt)
    raw = fileread(txt);
    if isempty(strtrim(raw))
        on = []; off = [];
        return;
    end
    C = textscan(raw, '%f%f%s', 'Delimiter', '\t', 'CollectOutput', true);
    on = C{1}(:,1);
    off = C{1}(:,2);
end