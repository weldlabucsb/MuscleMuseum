close all
f = figure;
tg = uitabgroup(f);
t1 = uitab(tg, 'Title', 'Thermal');
t2 = uitab(tg, 'Title', 'Raw');
% tg1 = uitabgroup(t1);
% tg2 = uitabgroup(t2);
% t11 = uitab(tg1, 'Title', '1');
% t12 = uitab(tg1, 'Title', '2');
% ax1 = uiaxes(t11);
% plot(ax1, 1:10, (1:10).^2);
% ax1 = uiaxes(t12);
% plot(ax1, 1:10, (1:10).^2);
[t,l] = findDeepestTab(f);