% startup.m
% set up matlab paths for the marmoset-call-detector project.
%
% what this does:
% - adds src/ and scripts/ (recursively) to the matlab path
% - prints a short summary so you can sanity-check the setup
%
% comment style: lowercase, section-by-section for intent; minimal inline comments.

function startup
% keep cwd as the repo root so relative paths are predictable
repo_root = pwd;

% add project folders
src_path = fullfile(repo_root, 'src');
scripts_path = fullfile(repo_root, 'scripts');
addpath(genpath(src_path));
addpath(genpath(scripts_path));

% print a short summary
fprintf('marmoset-call-detector setup\n');
fprintf('  added to path:\n');
fprintf('    %s\n', src_path);
fprintf('    %s\n', scripts_path);
fprintf('  current folder: %s\n', repo_root);
end
