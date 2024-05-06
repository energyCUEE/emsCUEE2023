clear;clc;
% change path to your solution
DA_sol = readtable('rolling_result/DA_solution.csv',ReadRowNames=true);
HA_sol = readtable('rolling_result/HA_solution.csv',ReadRowNames=true);
DA_sol.cumexpense = cumsum(max(0,-DA_sol.Pnet).*DA_sol.Buy_rate*15/60); % note resolution 15/60 is resolution ant it is not return from python
HA_sol.cumexpense = cumsum(max(0,-HA_sol.Pnet).*HA_sol.Buy_rate*5/60);

Actual_PL = readtable('C:/Users/User/Desktop/VSCpython/EMS_on_production/input_data/historical/load_data_5minresample_concat.csv',ReadRowNames=true);
Actual_PV = readtable('C:/Users/User/Desktop/VSCpython/EMS_on_production/input_data/historical/pv_data_5minresample_concat.csv',ReadRowNames=true);
%%
start_date = datetime('2023-11-01');
end_date = start_date + days(4);
filtered_DA_sol = DA_sol((DA_sol.datetime >= start_date) & (DA_sol.datetime < end_date),: );
filtered_HA_sol = HA_sol((HA_sol.datetime >= start_date) & (HA_sol.datetime < end_date),: );
filtered_PL = Actual_PL((Actual_PL.datetime >= start_date) & (Actual_PL.datetime < end_date),7);
filtered_PV = Actual_PV((Actual_PV.datetime >= start_date) & (Actual_PV.datetime < end_date),7);

[n_row,n_col] = size(filtered_DA_sol);
excess_gen_DA = filtered_DA_sol.PV - filtered_DA_sol.PL;
excess_gen_HA = filtered_HA_sol.PV - filtered_HA_sol.PL;
DA_datetime = datetime(filtered_DA_sol.datetime);
HA_datetime = datetime(filtered_HA_sol.datetime);
PL_datetime = datetime(filtered_PL.datetime);
PV_datetime = datetime(filtered_PV.datetime);
filename = "20231101_20231104";
%%
% Declare the figure size and number of plot
f = figure('PaperPosition',[0 0 21 24],'PaperOrientation','portrait','PaperUnits','centimeters');
t = tiledlayout(4,2,'TileSpacing','tight','Padding','tight');
nexttile
stairs(PV_datetime,filtered_PV.Ptot_kW_*50/8,'-k','LineWidth',1.5)
hold on
grid on
stairs(DA_datetime,filtered_DA_sol.PV,'-b','LineWidth',1.2)
hold on 
stairs(HA_datetime,filtered_HA_sol.PV,'-r','LineWidth',1)
legend('Actual solar','Solar DA','Solar HA','Location','northeastoutside')
ylabel('Power (kW)')
title('Predicted solar profile','FontSize',24)
xlabel('Hour')
xticks(start_date:hours(3):end_date)
datetick('x','HH','keepticks')

nexttile
stairs(DA_datetime,filtered_DA_sol.soc_1,'-b','LineWidth',1.5)
hold on
stairs(HA_datetime,filtered_HA_sol.soc_1,'-r','LineWidth',1.5)
hold on
ylabel('SoC (%)')
ylim([15 85])
yticks(20:10:80)
grid on
hold on
stairs(DA_datetime,[20*ones(n_row,1),80*ones(n_row,1)],'--m','HandleVisibility','off','LineWidth',1.2)
hold on
legend('SoC DA','SoC HA','Location','northeastoutside')
title('State of charge (SoC)','FontSize',24)
xlabel('Hour')
xticks(start_date:hours(3):end_date)
datetick('x','HH','keepticks')

nexttile
stairs(PL_datetime,filtered_PL.Ptot_kW_,'-k','LineWidth',1.5)
grid on
hold on
stairs(DA_datetime,filtered_DA_sol.PL,'-b','LineWidth',1.2)
hold on
stairs(HA_datetime,filtered_HA_sol.PL,'-r','LineWidth',1.2)
legend('Actual load','Load DA','Load HA','Location','northeastoutside')
ylabel('Power (kW)')
title('Predicted load profile','FontSize',24)
xlabel('Hour')
xticks(start_date:hours(3):end_date)
datetick('x','HH','keepticks')

nexttile
stairs(DA_datetime,excess_gen_DA,'-b','LineWidth',1.5)
grid on
hold on
stairs(HA_datetime,excess_gen_HA,'-r','LineWidth',1.5)
hold on
ylim([-20 20])
ylabel('Power (kW)')
yyaxis right
stairs(HA_datetime,filtered_HA_sol.xchg_1,'-g','LineWidth',1)
hold on
stairs(HA_datetime,-filtered_HA_sol.xdchg_1,'-m','LineWidth',1)
ylim([-1.5 1.5])
yticks(-1:1)
legend('Excess gen DA','Excess gen HA','x_{chg} HA','x_{dchg} HA','Location','northeastoutside')
ylabel('Power (kW)')
title('Excess power = P_{pv} - P_{load} and battery charge/discharge status','FontSize',24)
xlabel('Hour')
xticks(start_date:hours(3):end_date)
datetick('x','HH','keepticks')



nexttile
stairs(DA_datetime,filtered_DA_sol.Pnet,'-b','LineWidth',1.5)
grid on
hold on
stairs(HA_datetime,filtered_HA_sol.Pnet,'-r','LineWidth',1.5)
legend('Pnet DA','Pnet HA','Location','northeastoutside')
ylabel('Power (kW)')
title('Pnet = Generation - Consumption','FontSize',24)
xlabel('Hour')
xticks(start_date:hours(3):end_date)
datetick('x','HH','keepticks')

nexttile
stairs(DA_datetime,filtered_DA_sol.Pchg_1,'-b','LineWidth',1.5)
grid on
hold on
stairs(HA_datetime,filtered_HA_sol.Pchg_1,'-r','LineWidth',1.5)
legend('Pchg DA','Pchg HA','Location','northeastoutside')
ylabel('Power (kW)')
title('Power charged to battery','FontSize',24)
xlabel('Hour')
xticks(start_date:hours(3):end_date)
ylim([0 35])
datetick('x','HH','keepticks')

nexttile
stairs(DA_datetime,filtered_DA_sol.u,'-b','LineWidth',1.5)
hold on
grid on
stairs(HA_datetime,filtered_HA_sol.u,'-r','LineWidth',1.5)
hold on
ylabel('Expense (THB)')
ylim([-1 50])
yyaxis right
stairs(DA_datetime,filtered_DA_sol.cumexpense,'--b','LineWidth',1.2)
hold on
stairs(HA_datetime,filtered_HA_sol.cumexpense,'--r','LineWidth',1.2)
legend('Expense DA','Expense HA','Cumulative expense DA','Cumulative expense HA','Location','northeastoutside')
ylabel('Cumulative expense (THB)')
title('Expense when using energy cost as objective','FontSize',24)
xlabel('Hour')
xticks(start_date:hours(3):end_date)
datetick('x','HH','keepticks')


nexttile
stairs(DA_datetime,filtered_DA_sol.Pdchg_1,'-b','LineWidth',1.5)
grid on
hold on
stairs(HA_datetime,filtered_HA_sol.Pdchg_1,'-r','LineWidth',1.5)
legend('Pdchg DA','Pdchg HA','Location','northeastoutside')
ylabel('Power (kW)')
title('Power discharged from battery','FontSize',24)
xlabel('Hour')
xticks(start_date:hours(3):end_date)
ylim([0 35])
datetick('x','HH','keepticks')

fontsize(0.6,'centimeters')
%print(f,filename,'-dpdf')
%%
% suggest plot
f = figure('PaperPosition',[0 0 21/2 24/3],'PaperOrientation','portrait','PaperUnits','centimeters');
t = tiledlayout(3,1,'TileSpacing','tight','Padding','tight');

nexttile
stairs(PV_datetime,filtered_PV.Ptot_kW_*50/8,'-k','LineWidth',1.5)
hold on
grid on
stairs(DA_datetime,filtered_DA_sol.PV,'-b','LineWidth',1.2)
hold on 
stairs(HA_datetime,filtered_HA_sol.PV,'-r','LineWidth',1)
legend('Actual solar','Solar DA','Solar HA','Location','northeastoutside')
ylabel('Power (kW)')
title('Predicted solar profile','FontSize',24)
xlabel('Hour')
xticks(start_date:hours(3):end_date)
ylim([0 25])
yticks(0:5:25)
datetick('x','HH','keepticks')
xline(start_date+hours(24):hours(24):end_date-hours(24),'-k','LineWidth',1,'HandleVisibility','off')

nexttile
stairs(PL_datetime,filtered_PL.Ptot_kW_,'-k','LineWidth',1.5)
grid on
hold on
stairs(DA_datetime,filtered_DA_sol.PL,'-b','LineWidth',1.2)
hold on
stairs(HA_datetime,filtered_HA_sol.PL,'-r','LineWidth',1.2)
legend('Actual load','Load DA','Load HA','Location','northeastoutside')
ylabel('Power (kW)')
title('Predicted load profile','FontSize',24)
xlabel('Hour')
xticks(start_date:hours(3):end_date)
ylim([0 25])
yticks(0:5:25)
datetick('x','HH','keepticks')
xline(start_date+hours(24):hours(24):end_date-hours(24),'-k','LineWidth',1,'HandleVisibility','off')

nexttile
stairs(DA_datetime,excess_gen_DA,'-b','LineWidth',1.5)
grid on
hold on
ylim([-10 10])
yticks(-10:5:10)
ylabel('Power (kW)')
yyaxis right
stairs(DA_datetime,filtered_DA_sol.xchg_1,'-','LineWidth',1,'Color','#0072BD')
hold on
stairs(DA_datetime,-filtered_DA_sol.xdchg_1,'-','LineWidth',1,'Color','#D95319')
ylim([-1.5 1.5])
yticks(-1:1)
legend('Excess gen DA','x_{chg} DA','x_{dchg} DA','Location','northeastoutside')
title('Excess power = P_{pv} - P_{load} and battery charge/discharge status','FontSize',24)
xlabel('Hour')
xticks(start_date:hours(3):end_date)
datetick('x','HH','keepticks')
xline(start_date+hours(24):hours(24):end_date-hours(24),'-k','LineWidth',1,'HandleVisibility','off')
fontsize(0.6,'centimeters')
%print(f,"figures/rolling/" + filename+"_DA3plot",'-dpng')
%print(f,"figures/rolling/" + filename+"_DA3plot",'-depsc')
%%
f = figure('PaperPosition',[0 0 21/2 24/3],'PaperOrientation','portrait','PaperUnits','centimeters');
t = tiledlayout(3,1,'TileSpacing','tight','Padding','tight');

nexttile
stairs(DA_datetime,filtered_DA_sol.soc_1,'-b','LineWidth',1.5)
hold on
stairs(HA_datetime,filtered_HA_sol.soc_1,'-r','LineWidth',1.5)
hold on
ylabel('SoC (%)')
ylim([15 85])
yticks(20:10:80)
grid on
hold on
stairs(DA_datetime,[20*ones(n_row,1),80*ones(n_row,1)],'--m','HandleVisibility','off','LineWidth',1.2)
hold on
legend('SoC DA','SoC HA','Location','northeastoutside')
title('State of charge (SoC)','FontSize',24)
xlabel('Hour')
xticks(start_date:hours(3):end_date)
datetick('x','HH','keepticks')
xline(start_date+hours(24):hours(24):end_date-hours(24),'-k','LineWidth',1,'HandleVisibility','off')

nexttile
stairs(DA_datetime,filtered_DA_sol.Pchg_1,'-','LineWidth',1.5)
grid on
hold on
stairs(HA_datetime,filtered_HA_sol.Pchg_1,'-','LineWidth',1.5)
hold on
ylabel('Power (kW)')
ylim([0 10])
yticks(0:2.5:20)
yyaxis right
stairs(DA_datetime,excess_gen_DA,'-b','LineWidth',1)
hold on
stairs(HA_datetime,excess_gen_HA,'-r','LineWidth',1)
ylim([-20 20])
yticks(-20:5:20)
ylabel('Excess gen (kW)')
legend('P_{chg} DA','P_{chg} HA','Excess gen DA','Excess gen HA','Location','northeastoutside')
title('Excess power = P_{pv} - P_{load} and power charged to battery')
xlabel('Hour')
xticks(start_date:hours(3):end_date)
datetick('x','HH','keepticks')
xline(start_date+hours(24):hours(24):end_date-hours(24),'-k','LineWidth',1,'HandleVisibility','off')


nexttile
stairs(DA_datetime,filtered_DA_sol.Pdchg_1,'-','LineWidth',1.5)
grid on
hold on
stairs(HA_datetime,filtered_HA_sol.Pdchg_1,'-','LineWidth',1.5)
hold on
ylabel('Power (kW)')
yticks(0:10:30)
yyaxis right
stairs(DA_datetime,excess_gen_DA,'-b','LineWidth',1)
hold on
stairs(HA_datetime,excess_gen_HA,'-r','LineWidth',1)
ylim([-20 20])
yticks(-20:5:20)
ylabel('Excess gen (kW)')
legend('P_{dchg} DA','P_{dchg} HA','Excess gen DA','Excess gen HA','Location','northeastoutside')
title('Excess power = P_{pv} - P_{load} and power discharged from battery')
xlabel('Hour')
xticks(start_date:hours(3):end_date)
datetick('x','HH','keepticks')
xline(start_date+hours(24):hours(24):end_date-hours(24),'-k','LineWidth',1,'HandleVisibility','off')
fontsize(0.6,'centimeters')
%print(f,"figures/rolling/" + filename + "_DAHA",'-dpng')
%print(f,"figures/rolling/" + filename + "_DAHA",'-depsc')
%%
f = figure('PaperPosition',[0 0 21/2 24/3],'PaperOrientation','portrait','PaperUnits','centimeters');
t = tiledlayout(2,1,'TileSpacing','tight','Padding','tight');

nexttile
stairs(DA_datetime,filtered_DA_sol.Pnet,'-b','LineWidth',1.5)
grid on
hold on
stairs(HA_datetime,filtered_HA_sol.Pnet,'-r','LineWidth',1.5)
legend('Pnet DA','Pnet HA','Location','northeastoutside')
ylabel('Power (kW)')
title('Pnet = Generation - Consumption','FontSize',24)
xlabel('Hour')
xticks(start_date:hours(3):end_date)
datetick('x','HH','keepticks')
xline(start_date+hours(24):hours(24):end_date-hours(24),'-k','LineWidth',1,'HandleVisibility','off')
nexttile
stairs(DA_datetime,filtered_DA_sol.u,'-b','LineWidth',1.5)
hold on
grid on
stairs(HA_datetime,filtered_HA_sol.u,'-r','LineWidth',1.5)
hold on
ylabel('Expense (THB)')
ylim([-1 50])
yyaxis right
stairs(DA_datetime,filtered_DA_sol.cumexpense,'--b','LineWidth',1.2)
hold on
stairs(HA_datetime,filtered_HA_sol.cumexpense,'--r','LineWidth',1.2)
legend('Expense DA','Expense HA','Cumulative expense DA','Cumulative expense HA','Location','northeastoutside')
ylabel('Cumulative expense (THB)')
title('Expense when using energy cost as objective','FontSize',24)
xlabel('Hour')
xticks(start_date:hours(3):end_date)
datetick('x','HH','keepticks')
xline(start_date+hours(24):hours(24):end_date-hours(24),'-k','LineWidth',1,'HandleVisibility','off')
fontsize(0.6,'centimeters')
%print(f,"figures/rolling/" + filename+"_Pnet",'-dpng')
%print(f,"figures/rolling/" + filename+"_Pnet",'-depsc')

