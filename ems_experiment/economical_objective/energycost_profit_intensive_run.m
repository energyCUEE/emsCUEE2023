clear; clc;
% ---- user-input parameter ----
start_date   = '2023-04-18 00:00:00';  % dummy start date for intensive run                                                                                     
resolution   = 15;                     % Resolution in minutes (int)
time_horizon = 4*24*60;                % Optimization horizon in minutes (int)
                                            % Day-ahead (DA)      : Horizon in xx days (resolution 15 mins)
                                            % Intra-day (HA)      : Horizon in xx hours (resolution 5 mins)
pv_capacity  = 48;                     % Solar panel installation capacity in kWp (int) 

TOU_CHOICE = 'smart1';             % Choice for TOU
%TOU_CHOICE = 'THcurrent';
% read load and pv .csv

root_folder = "C:/Users/User/Desktop/VSCpython/opt_test/input_data/48_batch/"; % change this line to your Path
dataset_detail = readtable(root_folder+"dataset_detail.csv");  
dataset_name = dataset_detail.name; % list of dataset name

[PARAM.Buy_rate,PARAM.Sell_rate] = getBuySellrate(start_date,resolution,time_horizon,TOU_CHOICE);

%% intensive run EMS
for i = 1:length(dataset_name)
    % %get solar/load profile 
    
    [PARAM.PL,PARAM.PV] = get_batch_load_and_pv_data(root_folder,dataset_name{i}, pv_capacity);
        
    %end of solar/load 
    
    %parameter part
    % ---- save parameters ----
    PARAM.start_date  = start_date;
    PARAM.Resolution  = resolution;
    PARAM.Horizon     = time_horizon; 
    PARAM.PV_capacity = pv_capacity;
    PARAM.TOU_CHOICE  = TOU_CHOICE;
    % for energycost just change PARAM.weight_energycost to 1
    % for profit change PARAM.weight_profit to 1
    PARAM.weight_energyfromgrid = 0;
    PARAM.weight_energycost = 1;
    PARAM.weight_profit = 0;    
    PARAM.weight_multibatt = 0;
    PARAM.weight_chargebatt = 0;
    PARAM.weight_smoothcharge  = 0;  
    %for 1 batt 
    PARAM.battery.charge_effiency = [0.95]; %bes charge eff
    PARAM.battery.discharge_effiency = [0.95*0.93]; %  bes discharge eff note inverter eff 0.93-0.96
    PARAM.battery.discharge_rate = [45]; % kW max discharge rate
    PARAM.battery.charge_rate = [75]; % kW max charge rate
    PARAM.battery.actual_capacity = [150]; % kWh soc_capacity 
    PARAM.battery.initial = [50]; % userdefined int 0-100 %
    PARAM.battery.min = [40]; %min soc userdefined int 0-100 %
    PARAM.battery.max = [70]; %max soc userdefined int 0-100 %
    PARAM.battery.num_batt = length(PARAM.battery.actual_capacity);
    % end of parameter part
    sol = ems_econ_opt(PARAM);
    save(strcat('solution/energycost/',TOU_CHOICE,'_',dataset_name{i},'.mat'),'-struct','sol')
    %save(strcat('solution/profit/',TOU_CHOICE,'_',dataset_name{i},'.mat'),'-struct','sol')
end
