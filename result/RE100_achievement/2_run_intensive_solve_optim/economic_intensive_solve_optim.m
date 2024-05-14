% In this experiment, we solve the optimization problem  under econimic EMS by varying system size. 
%   PV size 50 - 70 kW and A single battery size 125 - 333 kWh
% Note that: The double battery system is considered in this EMS.

clear; clc;

dataset_detail = readtable('batch_dataset_15min/dataset_detail.csv');
dataset_name = dataset_detail.name;
dataset_start_date = dataset_detail.start_date;

options = optimoptions('intlinprog','MaxTime',40);

% User-input option specification
resolution   = 15;                     % Resolution in minutes (int)
time_horizon = 4*24*60;                % Optimization horizon in minutes (int)
                                            % Day-ahead (DA)      : Horizon in xx days (resolution 15 mins)
                                            % Intra-day (HA)      : Horizon in xx hours (resolution 5 mins)

% Define system size.
% The pv installation capacity varies for 50 - 70 kWp
min_pv_installation_cap = 50; % unit: kW
max_pv_installation_cap = 70; % unit: kW
pv_size_list = (min_pv_installation_cap:1:max_pv_installation_cap); % pv installation capacity

% Note that: the usable capacity of battery is in the range 20% - 80% which is 60%.
% The total usable capacity varies for 150 - 400 kWh (sum of 2 batteries)
min_total_usable_battcap = 150; % unit: kWh
max_total_usable_battcap = 400; % unit: kWh
usable_cap_percentage = 60; % unit: %
batt_size_list = round((min_total_usable_battcap:5:max_total_usable_battcap) .* (100/usable_cap_percentage) / 2); % A single battery size

TOU_CHOICE_list = {'smart1', 'THcurrent'};

% read load and pv .csv
root_folder = 'historical_data/'; % change this line to your Path
load_data = readtable(strcat(root_folder,'load_data_', num2str(resolution), 'minresample_concat.csv'),VariableNamingRule="preserve");
load_data.Properties.VariableNames{'Ptot (kW)'} = 'Load_kW';
load_data = load_data(:, {'datetime', 'Load_kW'});
pv_data = readtable(strcat(root_folder,'pv_data_', num2str(resolution), 'minresample_concat.csv'),VariableNamingRule="preserve");
pv_data.Properties.VariableNames{'Ptot (kW)'} = 'PV_kW';
pv_data = pv_data(:, {'datetime', 'PV_kW'});

%%
% For loop for all PV size, all battery size, and all TOU types.
for pv = pv_size_list
    for batt = batt_size_list
        for idx = 1:length(TOU_CHOICE_list)
    
            %--- user-input parameter ----
            PARAM.Resolution  = resolution;
            PARAM.Horizon     = time_horizon; 
            PARAM.PV_capacity = pv;   % Solar panel installation capacity in kWp (int) 
            TOU_CHOICE = TOU_CHOICE_list{idx} ; % Choice for TOU    
                      
            PARAM.weight_energyfromgrid = 0;
            PARAM.weight_energycost = 1;
            PARAM.weight_profit = 0;
            PARAM.weight_multibatt = 1;
            PARAM.weight_chargebatt = 0;
            PARAM.weight_smoothcharge = 0;

            % Battery parameters
            PARAM.battery.charge_effiency = [0.95 0.95]; %bes charge eff
            PARAM.battery.discharge_effiency = [0.95*0.93 0.95*0.93]; %  bes discharge eff note inverter eff 0.93-0.96
            PARAM.battery.discharge_rate = [30 30]; % kW max discharge rate
            PARAM.battery.charge_rate = [30 30]; % kW max charge rate
            PARAM.battery.actual_capacity = [batt batt]; % kWh soc_capacity
            PARAM.battery.initial = [50 50]; % userdefined int 0-100 %
            PARAM.battery.min = [20 20]; %min soc userdefined int 0-100 %
            PARAM.battery.max = [80 80]; %max soc userdefined int 0-100 %
            
            PARAM.battery.num_batt = length(PARAM.battery.actual_capacity);
            %end of ---- parameters ----
            
           
            for i = 1:length(dataset_name)
                % ---- get load&pv data ----
                start_date  = dataset_start_date(i);
                [PARAM.PL,PARAM.PV] = get_load_and_pv_data(load_data,pv_data,start_date, time_horizon, pv);
                [PARAM.Buy_rate,PARAM.Sell_rate] = getBuySellrate(start_date,resolution,time_horizon,TOU_CHOICE);
                
                %---solve for optimal sol
                % Use function to solve optimization problem.
                sol = ems_econ_opt(PARAM);
                % Save solutions.
                save(strcat('solution/energy_cost/pv',num2str(PARAM.PV_capacity), 'kW_batt', ...
                     num2str(batt),'kWh/', TOU_CHOICE,'_',dataset_name{i},'.mat'), '-struct','sol')  
            end
            
        end
    end
end

