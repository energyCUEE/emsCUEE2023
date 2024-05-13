% Since, in this EMS, double battery system is considered. The battery functionality is plot by this file.
% The graph consists 2 rows.
% Row (i): (left) SoC pattern of the 1st battery
%          (right) SoC pattern of the 2nd battery
% Row (ii): (left) statuses of charging and discharging pattern of the 1st battery on excess genration power.
%          (right) statuses of charging and discharging pattern of the 2nd battery on excess genration power.

clear;clc;
% The system size can be set when we vary PV size and battery size.
% Suppose we are interested in PV = 50 kW and Battery size = 125 kWh; 
% the solutions for this system size were solved and saved in the folder.
op = 'pv50kW_batt125kWh';
name = 'high_load_high_solar_4'; %% some days can be RE 100

% Load solution and parameters.
sol = load(strcat('solution/EMS5/', op,'/THcurrent','_',name,'.mat'));
PARAM = sol.PARAM;

% Change unit
h = 24 * PARAM.Horizon; % Optimization horizon in hours
fs = 1/PARAM.Resolution; % sampling freq(1/Hr)
Horizon = PARAM.Horizon; % Optimization horizon in days
% End of change unit
k = h*fs; %length of variable

PARAM_batt = PARAM.battery;
%parameter part
PARAM.battery.charge_effiency = PARAM_batt.charge_effiency(1); %bes charge eff
PARAM.battery.discharge_effiency = PARAM_batt.discharge_effiency(1); %  bes discharge eff note inverter eff 0.93-0.96
PARAM.battery.discharge_rate = PARAM_batt.discharge_rate(1); % kW max discharge rate
PARAM.battery.charge_rate = PARAM_batt.charge_rate(1); % kW max charge rate
PARAM.battery.actual_capacity = PARAM_batt.actual_capacity(1); % kWh soc_capacity 
PARAM.battery.initial = PARAM_batt.initial(1); % userdefined int 0-100 %
PARAM.battery.min = PARAM_batt.min(1); %min soc userdefined int 0-100 %
PARAM.battery.max = PARAM_batt.max(1); %max soc userdefined int 0-100 %
% % end of parameter part

%----------------prepare solution for plotting
excess_gen = PARAM.PV - PARAM.PL;
start_date = '2023-04-24';  %a start date for plotting graph
start_date = datetime(start_date);
end_date = start_date + Horizon;

t1 = start_date; t2 = end_date; 
vect = t1:minutes(PARAM.Resolution*60):t2 ; vect(end) = []; vect = vect';
%end of prepare for solution for plotting
%%
f = figure('PaperPosition',[0 0 21 20/2],'PaperOrientation','portrait','PaperUnits','centimeters');
t = tiledlayout(2,2,'TileSpacing','tight','Padding','tight');

colororder({'k','k','k','k'})

% fig(1,1): the 1st SoC pattern
nexttile
stairs(vect,sol.soc(1:k,1),'-k','LineWidth',1.5)
ylabel('SoC (%)')
ylim([0 100])
grid on
hold on
stairs(vect,[PARAM.battery.min*ones(k,1),PARAM.battery.max*ones(k,1)],'--m','HandleVisibility','off','LineWidth',1.2)
hold on
yyaxis right
stairs(vect,sol.Pchg(:,1),'-b','LineWidth',1)
hold on 
stairs(vect,sol.Pdchg(:,1),'-r','LineWidth',1)
legend('SoC_1','P_{chg}','P_{dchg}','Location','northeastoutside')
ylabel('Power (kW)')
title('State of charge for battery 1 (SoC_1)')
xlabel('Hour')
xticks(start_date:hours(3):end_date)
datetick('x','HH','keepticks')

% fig(1,2): the 2nd SoC pattern
nexttile
stairs(vect,sol.soc(1:k,2),'-k','LineWidth',1.5)
ylabel('SoC (%)')
ylim([0 100])
grid on
hold on
stairs(vect,[PARAM.battery.min*ones(k,1),PARAM.battery.max*ones(k,1)],'--m','HandleVisibility','off','LineWidth',1.2)
hold on
yyaxis right
stairs(vect,sol.Pchg(:,2),'-b','LineWidth',1)
hold on 
stairs(vect,sol.Pdchg(:,2),'-r','LineWidth',1)
legend('SoC_2','P_{chg}','P_{dchg}','Location','northeastoutside')
ylabel('Power (kW)')
title('State of charge for battery 2 (SoC_2)')
xlabel('Hour')
xticks(start_date:hours(3):end_date)
datetick('x','HH','keepticks')

% fig(2,1): xchg/xdchg and excess gen of the 1st batt
nexttile
stairs(vect,excess_gen,'-k','LineWidth',1.2) 
ylabel('Excess power (kW)')
yticks(-30:10:30)
ylim([-30 30])
hold on
grid on
yyaxis right 
stairs(vect,sol.xchg(:,1),'-b','LineWidth',1)
hold on 
grid on
stairs(vect,-sol.xdchg(:,1),'-r','LineWidth',1)
legend('Excess power','x_{chg}','x_{dchg}','Location','northeastoutside')
title('Excess power = P_{pv} - P_{load} and Battery No.1 charge/discharge status')
xlabel('Hour')
xticks(start_date:hours(3):end_date)
datetick('x','HH','keepticks')
yticks(-1:1)
ylim([-1.5,1.5])
hold off

% fig(2,2): xchg/xdchg and excess gen of the 2nd batt
nexttile
stairs(vect,excess_gen,'-k','LineWidth',1.2) 
ylabel('Excess power (kW)')
yticks(-30:10:30)
ylim([-30 30])
hold on
grid on
yyaxis right 
stairs(vect,sol.xchg(:,2),'-b','LineWidth',1)
hold on 
grid on
stairs(vect,-sol.xdchg(:,2),'-r','LineWidth',1)
legend('Excess power','x_{chg}','x_{dchg}','Location','northeastoutside')
title('Excess power = P_{pv} - P_{load} and Battery No.2 charge/discharge status')
xlabel('Hour')
xticks(start_date:hours(3):end_date)
datetick('x','HH','keepticks')
yticks(-1:1)
ylim([-1.5,1.5])
hold off

fontsize(0.6,'centimeters')