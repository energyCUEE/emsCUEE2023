% ---- user-input desired optimize modules and each module's weight
% Each weight must corresponds to each module.

% ---- user-input parameter ----
start_date   = '2023-04-18 01:00:00';           % Start date (str format: YYYY-MM-DD HH:mm:ss)
                                                % Note that: Default time is 00:00:00                                           
resolution   = 15;                     % Resolution in minutes (int)
time_horizon = 4*24*60;                % Optimization horizon in minutes (int)
                                            % Day-ahead (DA)      : Horizon in xx days (resolution 15 mins)
                                            % Intra-day (HA)      : Horizon in xx hours (resolution 5 mins)
pv_capacity  = 50;                     % Solar panel installation capacity in kWp (int) 

% TOU_CHOICE = 'smart1';             % Choice for TOU
% TOU_CHOICE = 'nosell';
TOU_CHOICE = 'THcurrent';
% read load and pv .csv
load_data = readtable(strcat('historical/load_data_', num2str(resolution), 'minresample_concat.csv'),VariableNamingRule="preserve");
load_data.Properties.VariableNames{'Ptot (kW)'} = 'Load_kW';
load_data = load_data(:, {'datetime', 'Load_kW'});
pv_data = readtable(strcat('historical/pv_data_', num2str(resolution), 'minresample_concat.csv'),VariableNamingRule="preserve");
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
PARAM.weight_energyfromgrid = 1;
PARAM.weight_energycost = 0;
PARAM.weight_profit = 0;
PARAM.weight_multibatt = 1;
PARAM.weight_chargebatt = 1;
PARAM.weight_smoothcharge  = 2; 


% % Battery parameters
% PARAM.battery.charge_effiency = [0.95]; %bes charge eff
% PARAM.battery.discharge_effiency = [0.95*0.93]; %  bes discharge eff note inverter eff 0.93-0.96
% PARAM.battery.discharge_rate = [30]; % kW max discharge rate
% PARAM.battery.charge_rate = [30]; % kW max charge rate
% PARAM.battery.actual_capacity = [125]; % kWh soc_capacity 
% PARAM.battery.initial = [50]; % userdefined int 0-100 %
% PARAM.battery.min = [20]; %min soc userdefined int 0-100 %
% PARAM.battery.max = [80]; %max soc userdefined int 0-100 %
% %end of batt

% Battery parameters
PARAM.battery.charge_effiency = [0.95 0.95]; %bes charge eff
PARAM.battery.discharge_effiency = [0.95*0.93 0.95*0.93]; %  bes discharge eff note inverter eff 0.93-0.96
PARAM.battery.discharge_rate = [30 30]; % kW max discharge rate
PARAM.battery.charge_rate = [30 30]; % kW max charge rate
PARAM.battery.actual_capacity = [125 125]; % kWh soc_capacity 
PARAM.battery.initial = [50 50]; % userdefined int 0-100 %
PARAM.battery.min = [20 20]; %min soc userdefined int 0-100 %
PARAM.battery.max = [80 80]; %max soc userdefined int 0-100 %
%end of batt

% % Battery parameters
% PARAM.battery.charge_effiency = [0.95 0.95 0.95]; %bes charge eff
% PARAM.battery.discharge_effiency = [0.95*0.93 0.95*0.93 0.95*0.93]; %  bes discharge eff note inverter eff 0.93-0.96
% PARAM.battery.discharge_rate = [30 30 30]; % kW max discharge rate
% PARAM.battery.charge_rate = [30 30 30]; % kW max charge rate
% PARAM.battery.actual_capacity = [125 125 125]; % kWh soc_capacity 
% PARAM.battery.initial = [50 50 50]; % userdefined int 0-100 %
% PARAM.battery.min = [20 20 20]; %min soc userdefined int 0-100 %
% PARAM.battery.max = [80 80 80]; %max soc userdefined int 0-100 %
% %end of batt


PARAM.battery.num_batt = length(PARAM.battery.actual_capacity);

% end of ---- parameters ----
%%
solution_path = 'solution';
sol = ems_econ_opt(PARAM);
%%
[f,t] = ems_energyfromgrid_plot(sol);
