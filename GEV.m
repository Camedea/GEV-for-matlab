clc;

%============================ User-defined settings ============================%
fileName  = 'test.xlsx';   % Name of the Excel file
sheetName = 'Sheet1';      % Name of the worksheet
dataCol   = 1;             % Column index to be imported
nUse      = 40;            % Number of samples to use from the beginning
showCI    = false;         % Plot 95% confidence bounds if true
yTickVals = 0:5000:56000;  % Y-axis tick values
yLimVals  = [0 56000];     % Y-axis limits
%=============================================================================%

%=============================== Load the data ================================%
dataRaw = read_excel_numeric(fileName, sheetName);

if size(dataRaw, 2) < dataCol
    error('Insufficient number of columns: the worksheet contains only %d columns, but dataCol is set to %d.', ...
        size(dataRaw,2), dataCol);
end

data = dataRaw(:, dataCol);
data = data(~isnan(data));   % Remove empty entries and non-numeric values

if isempty(data)
    error('No valid numeric data were imported. Please check the Excel file, worksheet name, or selected column.');
end

if numel(data) < nUse
    warning('The number of valid samples is less than %d. Only %d samples will be used.', nUse, numel(data));
    nUse = numel(data);
end

data = data(1:nUse, 1);

%===================== Construct the probability plotting grid =================%
figure;
ax = gca;
hold(ax, 'on');
grid(ax, 'on');

s = [0.01 0.05 0.1 0.2 0.5 1 2 5 10 20 30 40 50 ...
     60 70 80 90 95 98 99 99.5 99.8 99.95 99.99];
s1 = 100 ./ s;   % Return period corresponding to exceedance probability

t = norminv(s./100, 0, 1);
t = t - norminv(0.0001, 0, 1);

handles.data.p = s;
handles.data.x = t;

set(ax, 'XTick', t);
set(ax, 'XLim', [t(1) t(end)]);
set(ax, 'XTickLabel', s1);
set(ax, 'XDir', 'reverse');
set(ax, 'YTick', yTickVals, 'YLim', yLimVals);  % Adjust as needed for different datasets

%======================== Plot the historical sample points ===================%
x = data(:);
n = size(x,1); %#ok<NASGU>  % Retained for consistency with the original code

% Use the external getpoint.m if available; otherwise use the local fallback
if exist('getpoint', 'file') == 2
    [a,b] = getpoint(x);   % Empirical plotting positions
else
    [a,b] = getpoint_local(x);
end

handles.data.sample  = a;
handles.data.psample = b;

p = plot(norminv(b,0,1) - norminv(0.0001,0,1), a, 'o');
% set(p, 'markersize', 10);
% handles.plot1 = p;

%==================== Fit and plot the theoretical GEV curve ==================%
[parmhat, parmci] = gevfit(x);

k = parmhat(1);   % Shape parameter
S = parmhat(2);   % Scale parameter
u = parmhat(3);   % Location parameter

q = (s * 0.01)';
Y = gev_quantile_safe(k, S, u, q);

p1 = plot(t, Y, '-b', 'LineWidth', 1.2);
hold on

%======================== Plot the 95% confidence bounds ======================%
p2 = [];
p3 = [];

if showCI
    % Lower/upper parameter bound set 1
    k = parmci(1,1);
    S = parmci(1,2);
    u = parmci(1,3);

    q = (s * 0.01)';
    Y = gev_quantile_safe(k, S, u, q);
    p2 = plot(t, Y, '-b');

    % Lower/upper parameter bound set 2
    k = parmci(2,1);
    S = parmci(2,2);
    u = parmci(2,3);

    q = (s * 0.01)';
    Y = gev_quantile_safe(k, S, u, q);
    p3 = plot(t, Y, '-b');
end

% Retain this calculation from the original script
b  = b * 100;
t1 = norminv(b./100, 0, 1); %#ok<NASGU>
t1 = t1 - norminv(0.0001, 0, 1);

%============================= Legend and labels ==============================%
if showCI
    legend([p, p1, p2, p3], ...
        'EWL (Historical)', 'Design EWL', ...
        'Upper 95% limit', 'Lower 95% limit', ...
        'Location', 'best');
else
    legend([p, p1], 'EWL (Historical)', 'Design EWL', 'Location', 'best');
end

box on;
xlabel('Return period');
ylabel('EWL');

%% ============================ Local functions ============================ %%
function data = read_excel_numeric(fileName, sheetName)
%READ_EXCEL_NUMERIC Read numeric data from an Excel worksheet.
%   This function is compatible with both newer and older MATLAB versions.

    if ~isfile(fileName)
        error('File not found: %s', fileName);
    end

    try
        % Preferred method for newer MATLAB versions
        data = readmatrix(fileName, 'Sheet', sheetName);
    catch
        % Fallback for older MATLAB versions
        [data, ~, ~] = xlsread(fileName, sheetName);
    end

    if isempty(data)
        error('No numeric data could be read from file %s, worksheet %s.', fileName, sheetName);
    end
end

function [a,b] = getpoint_local(x)
%GETPOINT_LOCAL Compute empirical plotting positions.
%   If an external GETPOINT function is available, it will be used instead.
%   This local version is provided only as a fallback.

    x = x(:);
    x = x(~isnan(x));

    if isempty(x)
        error('Input data for getpoint is empty.');
    end

    % Sort data in ascending order and compute empirical probabilities
    % using the m/(n+1) plotting-position formula
    a = sort(x, 'ascend');
    n = numel(a);
    b = (1:n)' ./ (n + 1);
end

function Y = gev_quantile_safe(k, S, u, q)
%GEV_QUANTILE_SAFE Compute GEV quantiles with improved numerical stability.
%   When k approaches zero, the distribution reduces to the Gumbel form.

    q = q(:);

    % Avoid numerical issues when q is exactly 0 or 1
    q(q <= 0) = eps;
    q(q >= 1) = 1 - eps;

    if abs(k) < 1e-8
        % Gumbel limiting case
        Y = u - S .* log(-log(q));
    else
        % GEV quantile formula
        Y = u - (S ./ k) .* (1 - (-log(1 - q)).^(-k));
    end
end