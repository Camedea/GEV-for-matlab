%% GEV Flood Frequency — enlarge plot & move ONLY the title (via annotation)
clc; clear; close all;
% ===== You only need to change this: vertical position of the title (normalized coordinates 0–1) =====
TitleY = 0.91;   % Suggested range: 0.965–0.990; larger values move it higher
TitleStr = 'GEV Flood Frequency Analysis';
% ================================================================================================

%% 1) Load & Prepare
fprintf('Loading data...\n');
excel_file = 'Input.xlsx'; sheet_name = 'Sheet1'; col_index = 1;
pp_method = 'weibull';   % weibull / hazen / cunnane / gringorten

[data, ~, ~] = xlsread(excel_file, sheet_name);
x_all = data(:, col_index);
valid = ~isnan(x_all) & x_all > 0;
x = x_all(valid); n = numel(x);
fprintf('Loaded %d valid points.\n', n);

%% 2) Bottom axis ticks (AEP shown; axis uses Gumbel of F=1-AEP)
prob_exceed = [0.1 0.2 0.5 1 2 5 10 20 30 40 50 ...
               60 70 80 90 95 98 99 99.5 99.8 99.95 99.99];
AEP_ticks = prob_exceed/100;
F_ticks   = 1 - AEP_ticks;
x_ticks   = -log(-log(F_ticks));
[x_ticks_sorted, idx_tick] = sort(x_ticks, 'ascend');
tick_labels_sorted = cellstr(compose('%.2g%%', prob_exceed(idx_tick)));

%% 3) Figure & main axes (ENLARGE plotting area; do not move the top-axis labels)
fig = figure('Name','GEV Flood Frequency Analysis','NumberTitle','off', ...
             'Position',[100 100 1100 650],'Color','w');

ax = axes('Parent',fig,'Units','normalized','Position',[0.10 0.10 0.84 0.74]);
hold(ax,'on'); box(ax,'on'); grid(ax,'on');
set(ax,'GridLineStyle',':','GridAlpha',0.25);
set(ax,'XLim',[x_ticks_sorted(1) x_ticks_sorted(end)], ...
        'XTick',x_ticks_sorted,'XTickLabel',tick_labels_sorted);
xlabel(ax,'Annual Exceedance Probability (%)','FontSize',12);
ylabel(ax,'Discharge','FontSize',12);

% ---- Main title: use annotation for full control (move only the title without affecting the axes) ----
% [left bottom width height] in normalized figure coordinates; width=1 means centered alignment
annotation(fig,'textbox',[0, TitleY, 1, 0.03], ...
    'String', TitleStr, 'HorizontalAlignment','center', ...
    'VerticalAlignment','middle', 'EdgeColor','none', ...
    'FontSize',16, 'FontWeight','bold');

%% 4) Empirical plotting positions
x_sorted = sort(x(:), 'descend'); n = numel(x_sorted);
switch lower(pp_method)
    case 'weibull',    AEP_emp = ((1:n)')/(n+1);
    case 'hazen',      AEP_emp = (((1:n)')-0.5)/n;
    case 'cunnane',    AEP_emp = (((1:n)')-0.4)/(n+0.2);
    case 'gringorten', AEP_emp = (((1:n)')-0.44)/(n+0.12);
    otherwise,         AEP_emp = ((1:n)')/(n+1);
end
AEP_emp = max(min(AEP_emp,0.999999),1e-6);
F_emp   = 1 - AEP_emp;
emp_x   = -log(-log(F_emp));
h_emp = plot(ax, emp_x, x_sorted, 'og','MarkerSize',7, ...
    'MarkerFaceColor','g','DisplayName','Empirical Data');

%% 5) Fit GEV & curves
[parmhat, parmci] = gevfit(x);   % [k, sigma, mu]
k_fit=parmhat(1); s_fit=parmhat(2); m_fit=parmhat(3);

F_line = linspace(0.001,0.999,400)'; x_line = -log(-log(F_line));
Y_fit  = gevinv(F_line, k_fit, s_fit, m_fit);
Y_lo   = gevinv(F_line, parmci(1,1), parmci(1,2), parmci(1,3));
Y_hi   = gevinv(F_line, parmci(2,1), parmci(2,2), parmci(2,3));

h_fit = plot(ax, x_line, Y_fit,'-r','LineWidth',2,'DisplayName','GEV Fit');
h_ci  = plot(ax, x_line, Y_lo,'--b','LineWidth',1.3,'DisplayName','95% CI');
        plot(ax, x_line, Y_hi,'--b','LineWidth',1.3,'HandleVisibility','off');
legend(ax,[h_emp,h_fit,h_ci],'Location','northwest','Box','off','FontSize',10);

%% 6) Top X axis: Return period (years)
T_ticks = [2 5 10 20 50 100 200 500 1000];
F_top   = 1 - 1./T_ticks; x_top = -log(-log(F_top));
ax_top = axes('Parent',fig,'Units','normalized','Position',get(ax,'Position'), ...
              'Color','none','XAxisLocation','top','YAxisLocation','right', ...
              'YTick',[],'YColor','none','XLim',get(ax,'XLim'));
set(ax_top,'XTick',x_top,'XTickLabel',cellstr(string(T_ticks)));
xlabel(ax_top,'Return Period (years)','FontSize',12);
linkaxes([ax ax_top],'x');

%% 7) Optional: table, test, and save
return_periods = [2,5,10,25,50,100,200,500,1000]';
F_return = 1 - 1./return_periods;
Q  = gevinv(F_return,k_fit,s_fit,m_fit);
QL = gevinv(F_return,parmci(1,1),parmci(1,2),parmci(1,3));
QU = gevinv(F_return,parmci(2,1),parmci(2,2),parmci(2,3));

x_test = sort(x(:)); F0 = gevcdf(x_test,k_fit,s_fit,m_fit);
[h_ks,p_ks] = kstest(x_test,'CDF',[x_test,F0]);
theo_q_emp = gevinv(F_emp,k_fit,s_fit,m_fit);
rmse = sqrt(mean((x_sorted-theo_q_emp).^2));
fprintf('KS p=%.4f; RMSE=%.4f\n', p_ks, rmse);

tbl = table(return_periods,(1-F_return)*100,Q,QL,QU, ...
    'VariableNames',{'T_years','AEP_percent','Q','Q_L','Q_U'});
try, writetable(tbl,'GEV.xlsx','Sheet','ReturnPeriods');
catch, writetable(tbl,'GEV.csv'); end

try, exportgraphics(fig,'GEV.png','Resolution',300);
catch, saveas(fig,'GEV.png'); end
savefig(fig,'GEV.fig');