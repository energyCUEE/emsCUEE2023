function sol = ems_AC_opt(PARAM) 
    %%% This function is used to solve optimization problem, consisting 3 parts. 
    %%% (I) Define optimization variables.
    %%% (II) Define constraints.
    %%% (III) Call the solver and save parameters.
    % Set optimization solving time. 
    options = optimoptions('intlinprog','MaxTime',120);
    
    if rem(PARAM.Horizon, PARAM.Resolution) % Check if the optimization horizon and resolution are compatible.
        error('horizon must be a multiple of resolution')            
    end
    if   (PARAM.weight_energycost < 0) || (PARAM.weight_multibatt  < 0) || (PARAM.weight_chargebatt < 0) || (PARAM.weight_smoothcharge < 0 ) 
        error('Weights must >= 0')
    end
    
    if (PARAM.weight_multibatt > 0 ) && (PARAM.battery.num_batt == 1)
        error('The number of battery must >= 2 to use this objective')
    end
    length_optimvar = PARAM.Horizon/PARAM.Resolution; % Length of optimization variable.    
    % Change the unit of Resolution from (minute => hour) to be used in Expense calculation.
    minutes_in_hour = 60;
    resolution_in_hour = PARAM.Resolution/minutes_in_hour; 
    % Get AC schedule
    PARAM.ACschedule = getSchedule(PARAM.start_date,PARAM.Resolution,PARAM.Horizon);
    
    Pnet =      optimvar('Pnet',length_optimvar,'LowerBound',-inf,'UpperBound',inf);
    Pdchg =     optimvar('Pdchg',length_optimvar,PARAM.battery.num_batt,'LowerBound',0,'UpperBound',inf);
    xdchg =     optimvar('xdchg',length_optimvar,PARAM.battery.num_batt,'LowerBound',0,'UpperBound',1,'Type','integer');
    Pchg =      optimvar('Pchg',length_optimvar,PARAM.battery.num_batt,'LowerBound',0,'UpperBound',inf);
    xchg =      optimvar('xchg',length_optimvar,PARAM.battery.num_batt,'LowerBound',0,'UpperBound',1,'Type','integer');
    soc =       optimvar('soc',length_optimvar+1,PARAM.battery.num_batt,'LowerBound',ones(length_optimvar+1,PARAM.battery.num_batt).*PARAM.battery.min,'UpperBound',ones(length_optimvar+1,PARAM.battery.num_batt).*PARAM.battery.max);
    Pac_lab =       optimvar('Pac_lab',length_optimvar,'LowerBound',0,'UpperBound',inf);
    Pac_student =       optimvar('Pac_student',length_optimvar,'LowerBound',0,'UpperBound',inf);
    Xac_lab =      optimvar('Xac_lab',length_optimvar,4,'LowerBound',0,'UpperBound',1,'Type','integer');
    Xac_student =      optimvar('Xac_student',length_optimvar,4,'LowerBound',0,'UpperBound',1,'Type','integer');
    total_obj =  - PARAM.AClab.encourage_weight*sum( PARAM.ACschedule.*sum(Xac_lab,2))... 
                         - PARAM.ACstudent.encourage_weight*sum(PARAM.ACschedule.*sum(Xac_student,2) );
    if PARAM.weight_energycost > 0 % if weight_energycost = 0 -> it is islanding 
        % u is the upper bound of the expense.
        u = optimvar('u', length_optimvar, 'LowerBound', 0, 'UpperBound', inf);   
        total_obj = total_obj + sum(u);  
    end
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

    prob =      optimproblem('Objective',total_obj);
    if PARAM.weight_energycost > 0          
        %--constraint for buying electricity
        prob.Constraints.epicons1 = -resolution_in_hour*PARAM.Buy_rate.*Pnet - u <= 0;
    end
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

    %constraint part

    %---------- AC constraint---------
    prob.Constraints.Paclabcons = Pac_lab  == PARAM.AClab.Paclab_rate*(Xac_lab(:,1) + 0.5*Xac_lab(:,2) + 0.7*Xac_lab(:,3) + 0.8*Xac_lab(:,4));
    
    prob.Constraints.AClabcons1 = sum(Xac_lab,2) <= 1;
    
    prob.Constraints.AClabcons2 = sum(Xac_lab,2) >= 0;
    
    prob.Constraints.Pacstudentcons = Pac_student  == PARAM.ACstudent.Pacstudent_rate*(Xac_student(:,1) + 0.5*Xac_student(:,2) + 0.7*Xac_student(:,3) + 0.8*Xac_student(:,4));
    
    prob.Constraints.ACstudentcons1 = sum(Xac_student,2) <= 1;
    
    prob.Constraints.ACstudentcons2 = sum(Xac_student,2) >= 0;
    
    %--battery constraint
    
    prob.Constraints.chargeconsbatt = Pchg <= xchg.*(ones(length_optimvar,PARAM.battery.num_batt).*PARAM.battery.charge_rate);
    
    prob.Constraints.dischargeconsbatt = Pdchg   <= xdchg.*(ones(length_optimvar,PARAM.battery.num_batt).*PARAM.battery.discharge_rate);
    
    prob.Constraints.NosimultDchgAndChgbatt = xchg + xdchg >= 0;
    
    prob.Constraints.NosimultDchgAndChgconsbatt1 = xchg + xdchg <= 1;
    
    %--Pnet constraint
    prob.Constraints.powercons = Pnet == PARAM.PV + sum(Pdchg,2) - PARAM.Puload - sum(Pchg,2) - Pac_lab - Pac_student;
    if PARAM.weight_energycost == 0
        prob.Constraints.islanding = Pnet == 0;
    end
    %preservePnet = Pnet == 0;
    
    
    
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
    
    [sol, ~, exitflag] = solve(prob,Options=options);
    sol.exitflag = exitflag;
    sol.PARAM = PARAM;

end
function schedule = getSchedule(start_date,Resolution,Horizon)
    date = datetime(start_date):minutes(Resolution):(datetime(start_date)+minutes(Horizon));
    date = date(1:end-1)';
    schedule = zeros(Horizon/Resolution,1); 
    
    % set status during 13:00 - 16:00 to 1
    schedule((hour(date) >= 13) & (hour(date) < 16)) = 1;
    schedule((hour(date) == 16) & (minute(date) == 0)) = 1;
    %schedule = schedule.status;
end 