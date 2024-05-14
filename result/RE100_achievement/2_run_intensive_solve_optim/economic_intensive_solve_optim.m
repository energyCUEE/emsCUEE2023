% In this experiment, we solve the optimization problem  under econimic EMS by varying system size. 
% Two econimic EMS are 'energy_cost' and 'profit'.
%   PV size 50 - 70 kW and A single battery size 125 - 333 kWh
% Note that: The double battery system is considered in this EMS.

clear; clc;
dataset_detail = readtable('batch_dataset_15min/dataset_detail.csv');
dataset_name = dataset_detail.name;

options = optimoptions('intlinprog','MaxTime',40);

% Define system size.
pv_size_list = (50:1:70);
batt_size_list = round((150:5:400) .* (100/60) / 2);
TOU_CHOICE_list = {'smart1', 'THcurrent'};
EMS_list = {'energy_cost', 'profit'};

% For loop for all EMS types, all PV size, all battery size, and all TOU types.
for ide = 1: length(EMS_list)
    for pv = pv_size_list
        for batt = batt_size_list
            for idx = 1:length(TOU_CHOICE_list)
        
                %--- user-input parameter ----
                PARAM.Resolution = 15;    % Resolution in minutes (int)
                PARAM.Horizon = 4;  % Optimization horizon in days (int)
                PARAM.PV_capacity = pv;   % Solar panel installation capacity in kWp (int) 
                TOU_CHOICE = TOU_CHOICE_list{idx} ; % Choice for TOU    
                    
                % Change unit
                h = 24*PARAM.Horizon; % Change unit days => hour 
                PARAM.Resolution = PARAM.Resolution/60; % Change unit minutes => hour
                fs = 1/PARAM.Resolution; % Sampling frequency (1/Hr)
                Horizon = PARAM.Horizon;
                % End of change unit
                length_optimvar = h*fs; %length of variable
                
                % ---- get buy&sell rate ----
                [PARAM.Buy_rate,PARAM.Sell_rate] = getBuySellrate(fs,Horizon,TOU_CHOICE);
                          
                PARAM.weight_multibatt = 1;
                PARAM.weight_chargebatt = 0;
                PARAM.weight_smoothcharge  = 0; 

                % Battery parameters
                PARAM.battery.charge_effiency = [0.95 0.95]; %bes charge eff
                PARAM.battery.discharge_effiency = [0.95*0.93 0.95*0.93]; %  bes discharge eff note inverter eff 0.93-0.96
                PARAM.battery.discharge_rate = [30 30]; % kW max discharge rate
                PARAM.battery.charge_rate = [30 30]; % kW max charge rate
                PARAM.battery.actual_capacity = [batt batt]; % kWh soc_capacity
                PARAM.battery.initial = [50 50]; % userdefined int 0-100 %
                PARAM.battery.min = [20 20]; %min soc userdefined int 0-100 %
                PARAM.battery.max = [80 80]; %max soc userdefined int 0-100 %
                %end of batt

                PARAM.battery.num_batt = length(PARAM.battery.actual_capacity);
                %end of ---- parameters ----
                
                EMS = EMS_list{ide};
                for i = 1:length(dataset_name)
                    % ---- get load&pv data ----

                    % Note that function loadPVandPLcsv is not the same as function get_load_and_pv_data.
                    % Because, the input must include start_date and others.
                    [PARAM.PV,PARAM.PL] = loadPVandPLcsv(PARAM.Resolution,dataset_name{i});
                    PARAM.PV = PARAM.PV*(PARAM.PV_capacity/48); % divide by 8 kW * 6 (scaling factor) = 48  
                    
                    switch EMS
                        case 'energy_cost'
                            % u is the upper bound of the expense.
                            u = optimvar('u',length_optimvar,'LowerBound',0,'UpperBound',inf);
                        case 'profit'
                            % u is the upper bound of the profit.
                            u = optimvar('u',length_optimvar,'LowerBound',-inf,'UpperBound',inf);
                    end
                    Pnet =      optimvar('Pnet',length_optimvar,'LowerBound',-inf,'UpperBound',inf);
                    s =         optimvar('s',length_optimvar,'LowerBound',0,'UpperBound',inf); % s = Upper bound of |SoC diff| 
                    Pdchg =     optimvar('Pdchg',length_optimvar,PARAM.battery.num_batt,'LowerBound',0,'UpperBound',inf);
                    xdchg =     optimvar('xdchg',length_optimvar,PARAM.battery.num_batt,'LowerBound',0,'UpperBound',1,'Type','integer');
                    Pchg =      optimvar('Pchg',length_optimvar,PARAM.battery.num_batt,'LowerBound',0,'UpperBound',inf);
                    xchg =      optimvar('xchg',length_optimvar,PARAM.battery.num_batt,'LowerBound',0,'UpperBound',1,'Type','integer');
                    soc =       optimvar('soc',length_optimvar+1,PARAM.battery.num_batt,'LowerBound',ones(k+1,PARAM.battery.num_batt).*PARAM.battery.min,'UpperBound',ones(k+1,PARAM.battery.num_batt).*PARAM.battery.max);
                    
                    obj_fcn = sum(u) + sum(s);
                    prob =      optimproblem('Objective', obj_fcn);
                    
                    %constraint part
                    %--constraint for buy and sell electricity
                    switch EMS
                        case 'energy_cost'
                            prob.Constraints.epicons1 = -PARAM.Resolution*PARAM.Buy_rate.*Pnet - u <= 0;
                        case 'profit'
                            prob.Constraints.epicons1 = -PARAM.Resolution*PARAM.Buy_rate.*Pnet - u <= 0;
                            prob.Constraints.epicons2 = -PARAM.Resolution*PARAM.Sell_rate.*Pnet - u <= 0 ;
                    end
                    
                     % %--battery should be used equally
                     prob.Constraints.battdeviate1 = soc(2:k+1,1) - soc(2:k+1,2) <= s;
                     prob.Constraints.battdeviate2 = -s <= soc(2:k+1,1) - soc(2:k+1,2);

                
                    %--battery constraint
                
                    prob.Constraints.chargeconsbatt = Pchg <= xchg.*(ones(k,PARAM.battery.num_batt).*PARAM.battery.charge_rate);
                    
                    prob.Constraints.dischargeconsbatt = Pdchg   <= xdchg.*(ones(k,PARAM.battery.num_batt).*PARAM.battery.discharge_rate);
                    
                    prob.Constraints.NosimultDchgAndChgbatt = xchg + xdchg >= 0;
                    
                    prob.Constraints.NosimultDchgAndChgconsbatt1 = xchg + xdchg <= 1;
                    
                    %--Pnet constraint
                    prob.Constraints.powercons = Pnet == PARAM.PV + sum(Pdchg,2) - PARAM.PL - sum(Pchg,2);
                    
                    %end of static constraint part
                    
                    %--soc dynamic constraint 
                    soccons = optimconstr(k+1,PARAM.battery.num_batt);
                    
                    soccons(1,1:PARAM.battery.num_batt) = soc(1,1:PARAM.battery.num_batt)  == PARAM.battery.initial ;
                    for j = 1:PARAM.battery.num_batt
                        soccons(2:k+1,j) = soc(2:k+1,j)  == soc(1:k,j) + ...
                                                 (PARAM.battery.charge_effiency(:,j)*100*PARAM.Resolution/PARAM.battery.actual_capacity(:,j))*Pchg(1:k,j) ...
                                                    - (PARAM.Resolution*100/(PARAM.battery.discharge_effiency(:,j)*PARAM.battery.actual_capacity(:,j)))*Pdchg(1:k,j);
                        
                    end
                    prob.Constraints.soccons = soccons;
                    
                    %---solve for optimal sol
                    %[sol, ~, exitflag] = solve(prob,'Options',options);
                    [sol, ~, exitflag] = solve(prob);
                    sol.dataset_name = dataset_name{i};
                    sol.exitflag = exitflag;
                    sol.PARAM = PARAM;    
                    
                    % Save solutions.
                    save(strcat('solution/', EMS,'/pv',num2str(PARAM.PV_capacity), 'kW_batt', ...
                         num2str(batt),'kWh/', TOU_CHOICE,'_',dataset_name{i},'.mat'), '-struct','sol')
                    
                    
                end
            end
        end
    end
end
