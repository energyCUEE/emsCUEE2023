% In this experiment, we solve the optimization problem  under RE100 EMS by varying system size. 
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
EMS_list = {'RE100'};

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
                length_optimvar = h*fs; % length of variable
                Npoint1day = length_optimvar/4; % the number op points in 1 day

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

                    Pnet =      optimvar('Pnet',length_optimvar,'LowerBound',-inf,'UpperBound',inf);
                    Pdchg =     optimvar('Pdchg',length_optimvar,PARAM.battery.num_batt,'LowerBound',0,'UpperBound',inf);
                    xdchg =     optimvar('xdchg',length_optimvar,PARAM.battery.num_batt,'LowerBound',0,'UpperBound',1,'Type','integer');
                    Pchg =      optimvar('Pchg',length_optimvar,PARAM.battery.num_batt,'LowerBound',0,'UpperBound',inf);
                    xchg =      optimvar('xchg',length_optimvar,PARAM.battery.num_batt,'LowerBound',0,'UpperBound',1,'Type','integer');
                    soc =       optimvar('soc',length_optimvar+1,PARAM.battery.num_batt,'LowerBound',ones(k+1,PARAM.battery.num_batt).*PARAM.battery.min,'UpperBound',ones(k+1,PARAM.battery.num_batt).*PARAM.battery.max);
                    u =         optimvar('u',length_optimvar,'LowerBound',0,'UpperBound',inf);    % Upper bound of Pnet
                    maxPnet1day = optimvar('maxPnet1day',PARAM.Horizon,'LowerBound',0,'UpperBound',inf);    % Upper bound of q
                    total_obj = sum(maxPnet1day);

                    if PARAM.weight_multibatt > 0 % Add soc diff objective
                        % Define optimvar for 'multibatt' objective
                        % s = Upper bound of |SoC diff| 
                        % for 2 batt use batt difference for >= 3 batt use central soc
                        if PARAM.battery.num_batt == 2
                            s =         optimvar('s',length_optimvar,'LowerBound',0,'UpperBound',inf);
                            total_obj = total_obj + PARAM.weight_multibatt*sum(s,'all'); % Add soc diff objective           
                          
                        elseif PARAM.battery.num_batt >= 3
                            s =         optimvar('s',length_optimvar,PARAM.battery.num_batt,'LowerBound',0,'UpperBound',inf);
                            central_soc = optimvar('central_soc',length_optimvar,'LowerBound',0,'UpperBound',inf);
                            total_obj = total_obj + PARAM.weight_multibatt*sum(s,'all');           
                        end
                    end
                    if PARAM.weight_chargebatt > 0  
                        % Add term for 'chargebatt' objective
                        %for i = 1:PARAM.battery.num_batt
                            total_obj = total_obj + PARAM.weight_chargebatt*sum(sum((PARAM.battery.max.*(ones(length_optimvar+1,PARAM.battery.num_batt)) - soc) ...
                                                ./(ones(length_optimvar+1,PARAM.battery.num_batt).*(PARAM.battery.max - PARAM.battery.min)),2));  
                    
                        %end
                    end
                    if PARAM.weight_smoothcharge > 0 % Add non fluctuation charge and discharge objective
                        % Define optimvars for 'smoothcharge' objective
                        % upper_bound_Pchg is Upper bound of |Pchg(t)-Pchg(t-1)| objective
                        % upper_bound_Pdchg is Upper bound of |Pdchg(t)-Pdchg(t-1)| objective
                        upper_bound_Pchg = optimvar('upper_bound_Pchg',length_optimvar-1,PARAM.battery.num_batt,'LowerBound',0,'UpperBound',inf);      
                        upper_bound_Pdchg = optimvar('upper_bound_Pdchg',length_optimvar-1,PARAM.battery.num_batt,'LowerBound',0,'UpperBound',inf);        
                        % Add non fluctuation charge and discharge objective.
                        % Assume that the weight is equal for both Pchg and Pdchg.
                        total_obj = total_obj + PARAM.weight_smoothcharge * (sum(upper_bound_Pchg,'all') + sum(upper_bound_Pdchg,'all')); 
                       
                    end 

                    prob =      optimproblem('Objective', total_obj);

                    if PARAM.weight_multibatt > 0 % Add soc diff objective
                        % Define optimvar for 'multibatt' objective
                        % s = Upper bound of |SoC diff| 
                        % for 2 batt use batt difference for >= 3 batt use central soc
                        if PARAM.battery.num_batt == 2                     
                            prob.Constraints.battdeviate1 = soc(2:length_optimvar+1,1) - soc(2:length_optimvar+1,2) <= s;
                            prob.Constraints.battdeviate2 = -s <= soc(2:length_optimvar+1,1) - soc(2:length_optimvar+1,2);
                        elseif PARAM.battery.num_batt >= 3     
                            prob.Constraints.battdeviate1 = soc(2:length_optimvar+1,:) - central_soc.*ones(length_optimvar,PARAM.battery.num_batt) <= s.*ones(length_optimvar,PARAM.battery.num_batt);
                            prob.Constraints.battdeviate2 = -s.*ones(length_optimvar,PARAM.battery.num_batt) <= soc(2:length_optimvar+1,:) - central_soc.*ones(length_optimvar,PARAM.battery.num_batt);
                        end
                    end  

                    if PARAM.weight_smoothcharge > 0 % Add non fluctuation charge and discharge objective           
                        % %-- Constraint non fluctuating charge and discharge
                        % abs(Pchg(t)-Pchg(t-1)) <= upper_bound_Pchg
                        prob.Constraints.non_fluct_Pchg_con1 = Pchg(1:end-1,:)-Pchg(2:end,:) <= upper_bound_Pchg;
                        prob.Constraints.non_fluct_Pchg_con2 = -upper_bound_Pchg <= Pchg(1:end-1,:)-Pchg(2:end,:);
                        % abs(Pdchg(t)-Pdchg(t-1)) <= upper_bound_Pdchg
                        prob.Constraints.non_fluct_Pdchg_con1 = Pdchg(1:end-1,:)-Pdchg(2:end,:) <= upper_bound_Pdchg;
                        prob.Constraints.non_fluct_Pdchg_con2 = -upper_bound_Pdchg <= Pdchg(1:end-1,:)-Pdchg(2:end,:);
                    end

                    % Constraint part
                    %-- RE100 constraint
                    REcons =  optimconstr(length_optimvar,2);
                    for j = 0:(PARAM.Horizon - 1)

                        REcons(Npoint1day*j + 1:Npoint1day*(j+1),1) = -Pnet(Npoint1day*j + 1:Npoint1day*(j+1)) <= u(Npoint1day*j + 1:Npoint1day*(j+1)); % max(0,-Pnet) <= u
                        REcons(Npoint1day*j + 1:Npoint1day*(j+1),2) = u(Npoint1day*j + 1:Npoint1day*(j+1)) <= maxPnet1day(j+1); % u <= maxPnet1day
                    end
                    prob.Constraints.RE = REcons;

                    %--battery constraint
                
                    prob.Constraints.chargeconsbatt = Pchg <= xchg.*(ones(length_optimvar,PARAM.battery.num_batt).*PARAM.battery.charge_rate);
                    
                    prob.Constraints.dischargeconsbatt = Pdchg   <= xdchg.*(ones(length_optimvar,PARAM.battery.num_batt).*PARAM.battery.discharge_rate);
                    
                    prob.Constraints.NosimultDchgAndChgbatt = xchg + xdchg >= 0;
                    
                    prob.Constraints.NosimultDchgAndChgconsbatt1 = xchg + xdchg <= 1;
                    
                    %--Pnet constraint
                    prob.Constraints.powercons = Pnet == PARAM.PV + sum(Pdchg,2) - PARAM.PL - sum(Pchg,2);
                    
                    %end of static constraint part
                    
                    %--soc dynamic constraint 
                    soccons = optimconstr(length_optimvar+1,PARAM.battery.num_batt);
                    
                    soccons(1,1:PARAM.battery.num_batt) = soc(1,1:PARAM.battery.num_batt)  == PARAM.battery.initial ;
                    for j = 1:PARAM.battery.num_batt
                        soccons(2:length_optimvar+1,j) = soc(2:length_optimvar+1,j)  == soc(1:length_optimvar,j) + ...
                                                 (PARAM.battery.charge_effiency(:,j)*100*resolution_in_hour/PARAM.battery.actual_capacity(:,j))*Pchg(1:length_optimvar,j) ...
                                                    - (resolution_in_hour*100/(PARAM.battery.discharge_effiency(:,j)*PARAM.battery.actual_capacity(:,j)))*Pdchg(1:length_optimvar,j);
                        
                    end
                    prob.Constraints.soccons = soccons;

                    %---solve for optimal sol
                    % [sol, ~, exitflag] = solve(prob,'Options',options);
                    [sol, ~, exitflag] = solve(prob);
                    sol.dataset_name = dataset_name{i};
                    sol.exitflag = exitflag;
                    sol.PARAM = PARAM; 
                    
                    % Save solution.
                    save(strcat('solution/RE100/pv',num2str(PARAM.PV_capacity), 'kW_batt', ...
                                    num2str(batt),'kWh/', TOU_CHOICE,'_',dataset_name{i},'.mat'), '-struct','sol')
 
                end
            end
        end
    end
end
