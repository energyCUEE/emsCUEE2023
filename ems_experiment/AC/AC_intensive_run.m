clear; clc;
% ---- user-input parameter ----
start_date   = '2023-04-18 00:00:00';  % dummy start date for intensive run                                                                                     
resolution   = 15;                     % Resolution in minutes (int)
time_horizon = 4*24*60;                % Optimization horizon in minutes (int)
                                            % Day-ahead (DA)      : Horizon in xx days (resolution 15 mins)
                                            % Intra-day (HA)      : Horizon in xx hours (resolution 5 mins)
pv_capacity  = 16;                     % Solar panel installation capacity in kWp (int) 

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
    % ----- weight for each objective if weight_energycost = 0 then it is islanding;
    PARAM.weight_energycost = 0;
    PARAM.weight_multibatt = 0;
    PARAM.weight_chargebatt = 0.1;
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

    % AC parameters
    PARAM.AClab.encourage_weight = 5; %(THB) weight for encourage lab ac usage
    PARAM.ACstudent.encourage_weight = 2; %(THB) weight for encourage student ac usage
    PARAM.AClab.Paclab_rate = 3.71*3; % (kw) air conditioner input Power for lab
    PARAM.ACstudent.Pacstudent_rate = 1.49*2 + 1.82*2; % (kw) air conditioner input Power for lab
    PARAM.Puload = min(PARAM.PL) ;% (kW) power of uncontrollable load
    
    
    % end of parameter part
   
    sol = ems_AC_opt(PARAM);
    %save(strcat('solution/AC/',TOU_CHOICE,'_',dataset_name{i},'.mat'),'-struct','sol')
    save(strcat('solution/islanding/',dataset_name{i},'.mat'),'-struct','sol')
end