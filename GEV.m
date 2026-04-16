clc;

%------------------------------用户可修改参数------------------------------%
fileName = 'test.xlsx';   % Excel文件名
sheetName = 'Sheet1';     % 工作表名
dataCol   = 1;            % 读取第几列数据
nUse      = 40;           % 使用前多少个样本
showCI    = false;        % 是否绘制95%置信线（原代码中这部分被注释）
yTickVals = 0:5000:56000; % y轴刻度
yLimVals  = [0 56000];    % y轴范围
%-------------------------------------------------------------------------%

%------------------------------------load data----------------------------%
dataRaw = read_excel_numeric(fileName, sheetName);

if size(dataRaw,2) < dataCol
    error('数据列不足：当前表只有 %d 列，但你设置要读取第 %d 列。', size(dataRaw,2), dataCol);
end

data = dataRaw(:, dataCol);
data = data(~isnan(data));   % 去掉空值/非数值

if isempty(data)
    error('读取到的数据为空，请检查Excel文件、工作表名称或数据列。');
end

if numel(data) < nUse
    warning('有效数据少于 %d 个，实际仅使用 %d 个样本。', nUse, numel(data));
    nUse = numel(data);
end

data = data(1:nUse,1);

%------------------------------绘制海森几率网格----------------------------%
figure;
ax = gca;
hold(ax, 'on');
grid(ax, 'on');

s = [0.01 0.05 0.1 0.2 0.5 1 2 5 10 20 30 40 50 ...
     60 70 80 90 95 98 99 99.5 99.8 99.95 99.99];
s1 = 100 ./ s;

t = norminv(s./100, 0, 1);
t = t - norminv(0.0001, 0, 1);

handles.data.p = s;
handles.data.x = t;

set(ax, 'XTick', t);
set(ax, 'XLim', [t(1) t(end)]);
set(ax, 'XTickLabel', s1);
set(ax, 'XDir', 'reverse');
set(ax, 'YTick', yTickVals, 'YLim', yLimVals);  % 若样本变化，y范围视情况修改

%-------------------------绘制1961-2015年期间的散点图----------------------%
x = data(:);
n = size(x,1); %#ok<NASGU>  % 保留原变量，不改变逻辑

% 优先调用你已有的 getpoint.m；若没有，则使用下方本地兼容函数
if exist('getpoint', 'file') == 2
    [a,b] = getpoint(x);   % getpoint函数依期望值公式计算经验频率
else
    [a,b] = getpoint_local(x);
end

handles.data.sample  = a;
handles.data.psample = b;

p = plot(norminv(b,0,1)-norminv(0.0001,0,1), a, 'o');
% set(p,'markersize',10);
% handles.plot1 = p;

%----------------------------绘制理论GEV分布和95%置信线--------------------%
%--------------------- ----绘制理论GEV分布曲线------------------------------%
[parmhat, parmci] = gevfit(x);

k = parmhat(1);
S = parmhat(2);
u = parmhat(3);

q = (s * 0.01)';
Y = gev_quantile_safe(k, S, u, q);

p1 = plot(t, Y, '-b', 'LineWidth', 1.2);
hold on

%--------------------------------绘制95%置信线-----------------------------%
p2 = [];
p3 = [];

if showCI
    % 绘制第一条
    k = parmci(1,1);
    S = parmci(1,2);
    u = parmci(1,3);

    q = (s * 0.01)';
    Y = gev_quantile_safe(k, S, u, q);
    p2 = plot(t, Y, '-b');

    % 绘制第二条
    k = parmci(2,1);
    S = parmci(2,2);
    u = parmci(2,3);

    q = (s * 0.01)';
    Y = gev_quantile_safe(k, S, u, q);
    p3 = plot(t, Y, '-b');
end

% 保留你原代码中的这部分计算
b  = b * 100;
t1 = norminv(b./100, 0, 1); %#ok<NASGU>
t1 = t1 - norminv(0.0001, 0, 1);

%------------------------------图例与坐标轴-------------------------------%
if showCI
    legend([p, p1, p2, p3], ...
        'EWL(Historical)', 'Design EWL', ...
        'Upper limit of 95%', 'Lower limit of 95%', ...
        'Location', 'best');
else
    legend([p, p1], 'EWL(Historical)', 'Design EWL', 'Location', 'best');
end

box on;
xlabel('Return period');
ylabel('EWL');

%% ============================ 本地函数区 ============================= %%
function data = read_excel_numeric(fileName, sheetName)
% 兼容不同MATLAB版本的Excel读取方式
    if ~isfile(fileName)
        error('找不到文件：%s', fileName);
    end

    try
        % 新版本MATLAB优先
        data = readmatrix(fileName, 'Sheet', sheetName);
    catch
        % 旧版本兼容
        [data, ~, ~] = xlsread(fileName, sheetName);
    end

    if isempty(data)
        error('未能从文件 %s 的工作表 %s 读取到数值数据。', fileName, sheetName);
    end
end

function [a,b] = getpoint_local(x)
% 兼容版经验频率计算
% 若你已有自己的 getpoint.m，程序会优先调用你原来的函数
% 这里只作为备用，不改变"按经验频率画点"的核心逻辑

    x = x(:);
    x = x(~isnan(x));

    if isempty(x)
        error('输入到 getpoint 的数据为空。');
    end

    % 年最大值频率分析中常按从小到大排序，经验频率用 m/(n+1)
    a = sort(x, 'ascend');
    n = numel(a);
    b = (1:n)' ./ (n + 1);
end

function Y = gev_quantile_safe(k, S, u, q)
% 保持原GEV公式逻辑，同时增强数值稳定性
% 当 k 接近 0 时，退化为 Gumbel 分布形式

    q = q(:);

    % 避免 q 取到 0 或 1 导致 log 出问题
    q(q <= 0) = eps;
    q(q >= 1) = 1 - eps;

    if abs(k) < 1e-8
        % Gumbel 极限形式
        Y = u - S .* log(-log(q));
    else
        % 原代码中的GEV分位数表达式
        Y = u - (S ./ k) .* (1 - (-log(1 - q)).^(-k));
    end
end