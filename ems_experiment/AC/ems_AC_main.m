clear; clc;
% ---- user-input parameter ----
start_date   = '2023-11-18 01:00:00';           % Start date (str format: YYYY-MM-DD HH:mm:ss)
                                                % Note that: Default time is 00:00:00                                           
resolution   = 15;                     % Resolution in minutes (int)
time_horizon = 4*24*60;                % Optimization horizon in minutes (int)
                                            % Day-ahead (DA)      : Horizon in xx days (resolution 15 mins)
                                            % Intra-day (HA)      : Horizon in xx hours (resolution 5 mins)
pv_capacity  = 16;                     % Solar panel installation capacity in kWp (int) 

% TOU_CHOICE = 'smart1';             % Choice for TOU
% TOU_CHOICE = 'nosell';
TOU_CHOICE = 'THcurrent';
%end of ----- parameter ----

% read load and pv .csv
root_folder = 'C:/Users/User/Desktop/VSCpython/opt_test/input_data/historical/'; % change this line to your Path
load_data = readtable(strcat(root_folder,'load_data_', num2str(resolution), 'minresample_concat.csv'),VariableNamingRule="preserve");
load_data.Properties.VariableNames{'Ptot (kW)'} = 'Load_kW';
load_data = load_data(:, {'datetime', 'Load_kW'});
pv_data = readtable(strcat(root_folder,'pv_data_', num2str(resolution), 'minresample_concat.csv'),VariableNamingRule="preserve");
pv_data.Properties.VariableNames{'Ptot (kW)'} = 'PV_kW';
pv_data = pv_data(:, {'datetime', 'PV_kW'});
%%
% ---- get load&pv data and buy&sell rate ----
[PARAM.PL,PARAM.PV] = get_load_and_pv_data(load_data,pv_data,start_date, time_horizon, pv_capacity);
[PARAM.Buy_rate,PARAM.Sell_rate] = getBuySellrate(start_date,resolution,time_horizon,TOU_CHOICE);

% ---- save parameters ----
PARAM.start_date  = start_date;
PARAM.Resolution  = resolution;
PARAM.Horizon     = time_horizon; 
PARAM.PV_capacity = pv_capacity;
PARAM.TOU_CHOICE  = TOU_CHOICE;
% ----- weight for each objective if weight_energycost = 0 then it is islanding;
PARAM.weight_energycost = 0;
PARAM.weight_multibatt = 1;
PARAM.weight_chargebatt = 1;
PARAM.weight_smoothcharge  = 0.3; 
%parameter part
% battery(s)
PARAM.battery.charge_effiency = [0.95 0.95]; %bes charge eff
PARAM.battery.discharge_effiency = [0.95*0.93 0.95*0.93]; %  bes discharge eff note inverter eff 0.93-0.96
PARAM.battery.discharge_rate = [30 30]; % kW max discharge rate
PARAM.battery.charge_rate = [30 30]; % kW max charge rate
PARAM.battery.actual_capacity = [125 125]; % kWh soc_capacity 
PARAM.battery.initial = [50 50]; % userdefined int 0-100 %
PARAM.battery.min = [20 20]; %min soc userdefined int 0-100 %
PARAM.battery.max = [80 80]; %max soc userdefined int 0-100 %
PARAM.battery.num_batt = length(PARAM.battery.actual_capacity);
% AC parameters
PARAM.AClab.encourage_weight = 5; %(THB) weight for encourage lab ac usage
PARAM.ACstudent.encourage_weight = 2; %(THB) weight for encourage student ac usage
PARAM.AClab.Paclab_rate = 3.71*3; % (kw) air conditioner input Power for lab
PARAM.ACstudent.Pacstudent_rate = 1.49*2 + 1.82*2; % (kw) air conditioner input Power for lab
PARAM.Puload = min(PARAM.PL) ;% (kW) power of uncontrollable load


% end of parameter part



%%
solution_path = "solution/";
solution_name = "test_AC_sol";
sol = ems_AC_opt(PARAM);
% beware when islanding, the problem might be infeasible
save(solution_path+solution_name+".mat",'-struct','sol')

%%
graph_path = "graph/";
graph_name = "test_AC_graph";
[f,t] = ems_AC_plot(sol);
print(f,graph_path + "png/"+graph_name,'-dpng')   % for png file
print(f,graph_path + "eps/"+graph_name,'-depsc') % for color eps file

