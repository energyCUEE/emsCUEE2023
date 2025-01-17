% In this experiment, we investigate the effect of including 'multibatt'
% objective in the objective function.

clear;clc;
% Read data from the batch_dataset.
dataset_detail = readtable('batch_dataset_15min/dataset_detail.csv');
dataset_name = dataset_detail.name;
pv_type = dataset_detail.solar_type;
load_type = dataset_detail.load_type;
dataset_startdate = dataset_detail.start_date;

% The system size can be set when we vary PV size and battery size.
% Suppose we are interested in PV = 50 kW and Battery size = 125 kWh; 
% the solutions for this system size were solved and saved in the folder.
op = 'pv50kW_batt125kWh';

%%
% First, we investigate the difference of Pchg and Pdchg 
% between 1 big battery and 2 small batteries.

% List to store Pchg and Pdchg of 1 big battery.
Pchg_1batt_diff = [];
Pdchg_1batt_dff = [];

% List to store Pchg and Pdchg of 2 small batteries.
% with multibatt objective
Pchg_2batt_diff_with_sc = [];
Pdchg_2batt_dff_with_sc = [];

% without multibatt objective
Pchg_2batt_diff_without_sc = [];
Pdchg_2batt_dff_without_sc = [];

% For loop for all dataset.
for i = 1:length(dataset_name)
    % 1 big battery
    sol_thcurrent_1batt = load(strcat('solution/EMS1/', op, '/1batt/','THcurrent','_',dataset_name{i},'.mat'));
    sol_smart_1batt = load(strcat('solution/EMS1/', op, '/1batt/','smart1','_',dataset_name{i},'.mat'));
    % 2 small batteries
        % TOU 0
    sol_without_sc_thcurrent_2batt = load(strcat('solution/EMS1/', op, '/2batt/without_sc/', 'THcurrent','_',dataset_name{i},'.mat'));
    sol_with_sc_thcurrent_2batt = load(strcat('solution/EMS1/', op, '/2batt/with_sc/','THcurrent','_',dataset_name{i},'.mat'));
        % TOU 1
    sol_without_sc_smart_2batt = load(strcat('solution/EMS1/', op, '/2batt/without_sc/','smart1','_',dataset_name{i},'.mat'));
    sol_with_sc_smart_2batt = load(strcat('solution/EMS1/', op, '/2batt/with_sc/','smart1','_',dataset_name{i},'.mat'));

    % Expense of 1 battery
    networth_1batt_thcurrent(i,1) = sum(-sol_thcurrent_1batt.u);
    networth_1batt_smart(i,1) = sum(-sol_smart_1batt.u);
    % Expense of 2 batteries
        % TOU 0
    networth_without_sc_2batt_thcurrent(i,1) = sum(-sol_without_sc_thcurrent_2batt.u);
    networth_with_sc_2batt_thcurrent(i,1) = sum(-sol_with_sc_thcurrent_2batt.u);
        % TOU 1
    networth_without_sc_2batt_smart(i,1) = sum(-sol_without_sc_smart_2batt.u);
    networth_with_sc_2batt_smart(i,1) = sum(-sol_with_sc_smart_2batt.u);

    % SoC patterns of 2 batteries 
        % TOU 0
        % 1st batt
    soc_without_sc_1st_batt_thcurrent = sol_without_sc_thcurrent_2batt.soc(:,1);
    soc_with_sc_1st_batt_thcurrent = sol_with_sc_thcurrent_2batt.soc(:,1);
        % 2nd batt
    soc_without_sc_2st_batt_thcurrent = sol_without_sc_thcurrent_2batt.soc(:,2);
    soc_with_sc_2st_batt_thcurrent = sol_with_sc_thcurrent_2batt.soc(:,2);
    
    % Calculate the difference of SoC patterns of both with and without
    % multibatt objective under TOU 0
    soc_without_sc_diff_thcurrent(i,1) = mean(abs(soc_without_sc_1st_batt_thcurrent - soc_without_sc_2st_batt_thcurrent));
    soc_with_sc_diff_thcurrent(i,1) = mean(abs(soc_with_sc_1st_batt_thcurrent - soc_with_sc_2st_batt_thcurrent));

    
    % SoC patterns of 2 batteries 
        % TOU 1
        % 1st batt
    soc_without_sc_1st_batt_smart = sol_without_sc_smart_2batt.soc(:,1);
    soc_with_sc_1st_batt_smart = sol_with_sc_smart_2batt.soc(:,1);
        % 2nd batt
    soc_without_sc_2st_batt_smart = sol_without_sc_smart_2batt.soc(:,2);
    soc_with_sc_2st_batt_smart = sol_with_sc_smart_2batt.soc(:,2);
    
    % Calculate the difference of SoC patterns of both with and without
    % multibatt objective under TOU 1
    soc_without_sc_diff_smart(i,1) = mean(abs(soc_without_sc_1st_batt_smart - soc_without_sc_2st_batt_smart));
    soc_with_sc_diff_smart(i,1) = mean(abs(soc_with_sc_1st_batt_smart - soc_with_sc_2st_batt_smart));
    

    % Compare Pchg and Pdchg between 1 batt vs. 2 batts.
    Pchg_1batt = sol_thcurrent_1batt.Pchg(:,1);
    Pchg_sum2batt = sol_without_sc_thcurrent_2batt.Pchg(:,1) + sol_without_sc_thcurrent_2batt.Pchg(:,2);  
    Pdchg_1batt = sol_thcurrent_1batt.Pdchg(:,1);
    Pdchg_sum2batt = sol_without_sc_thcurrent_2batt.Pdchg(:,1) + sol_without_sc_thcurrent_2batt.Pdchg(:,2);
    
    % Calculate difference of Pchg and Pdchg between 1 big battery and sum
    % of 2 small batteries.
    chg_diff = norm(Pchg_1batt - Pchg_sum2batt, inf);
    dchg_diff = norm(Pdchg_1batt - Pdchg_sum2batt, inf);
    
    % Check condition.
    if chg_diff > 1e-2
        Pchg_1batt_diff{i} = 'diff';
    else
        Pchg_1batt_diff{i} = 'same';
    end

    if dchg_diff > 1e-2
        Pdchg_1batt_diff{i} = 'diff';
    else
        Pdchg_1batt_diff{i} = 'same';
    end
    
% Compare Pchg and Pdchg of each battery in double battery system under
% with and without multibatt objective.

% with multibatt objective
    % Pchg diff = Pchg 1st batt - Pchg 2nd batt
    Pchg_diff_with_sc = sol_with_sc_thcurrent_2batt.Pchg(:,1)- sol_with_sc_thcurrent_2batt.Pchg(:,2);
    % Pdchg diff = Pdchg 1st batt - Pdchg 2nd batt
    Pdchg_diff_with_sc = sol_with_sc_thcurrent_2batt.Pdchg(:,1)- sol_with_sc_thcurrent_2batt.Pdchg(:,2);

    if norm(Pchg_diff_with_sc, inf) > 1e-2
        Pchg_2batt_diff_with_sc{i} = 'diff';
    else
        Pchg_2batt_diff_with_sc{i} = 'same';
    end

    if norm(Pdchg_diff_with_sc, inf) > 1e-2
        Pdchg_2batt_diff_with_sc{i} = 'diff';
    else
        Pdchg_2batt_dff_with_sc{i} = 'same';
    end

% without multibatt objective
    % Pchg diff = Pchg 1st batt - Pchg 2nd batt
    Pchg_diff_without_sc = sol_without_sc_thcurrent_2batt.Pchg(:,1)- sol_without_sc_thcurrent_2batt.Pchg(:,2);
    % Pdchg diff = Pdchg 1st batt - Pdchg 2nd batt
    Pdchg_diff_without_sc = sol_without_sc_thcurrent_2batt.Pdchg(:,1)- sol_without_sc_thcurrent_2batt.Pdchg(:,2);
    
    if norm(Pchg_diff_without_sc, inf) > 1e-2
        Pchg_2batt_diff_without_sc{i} = 'diff';
    else
        Pchg_2batt_diff_without_sc{i} = 'same';
    end

    if norm(Pdchg_diff_without_sc, inf) > 1e-2
        Pdchg_2batt_diff_without_sc{i} = 'diff';
    else
        Pdchg_2batt_dff_without_sc{i} = 'same';
    end

end

% Show the result to analyze.
% (i) Pchg and Pdchg patterns between 1 big batt and sum of 2 small batt under TOU 0
% (ii) Pchg and Pdchg patterns of double battery system between 1st batt and 2nd batt with multibatt objectuve under TOU 0
% (iii) Pchg and Pdchg patterns of double battery system between 1st batt and 2nd batt without multibatt objectuve under TOU 0
fprintf('Pattern of chg/dchg between 1 batt vs. sum of 2 batt under TOU 0')
fprintf('\n')
fprintf('% 15s % 20s %10s', 'name', 'Pchg', 'Pdchg')
fprintf('\n')
for i = 1:length(dataset_name)
    fprintf('% s  % 10s  %10s', dataset_name{i}, Pchg_1batt_diff{i}, Pdchg_1batt_diff{i})
    fprintf('\n')
end
fprintf('----------------------------------------------------')
fprintf('\n')

fprintf('Similarity of two batteries between 1st batt and 2nd batt with sum(s) under TOU 0')
fprintf('\n')
fprintf('% 15s % 20s %10s', 'name', 'Pchg', 'Pdchg')
fprintf('\n')
for i = 1:length(dataset_name)
    fprintf('% s  % 10s  %10s', dataset_name{i}, Pchg_2batt_diff_with_sc{i}, Pchg_2batt_diff_with_sc{i})
    fprintf('\n')
end
fprintf('----------------------------------------------------')
fprintf('\n')

fprintf('Similarity of two batteries between 1st batt and 2nd batt without sum(s) under TOU 0')
fprintf('\n')
fprintf('% 15s % 20s %10s', 'name', 'Pchg', 'Pdchg')
fprintf('\n')
for i = 1:length(dataset_name)
    fprintf('% s  % 10s  %10s', dataset_name{i}, Pchg_2batt_diff_without_sc{i}, Pchg_2batt_diff_without_sc{i})
    fprintf('\n')
end
fprintf('----------------------------------------------------')
fprintf('\n')


%%
% Plot results.
% Row (i): (left)    Expense under TOU 0 between 1 big batt and 2 small batt without multibatt objective
%          (right)   Expense under TOU 1 between 1 big batt and 2 small batt without multibatt objective
% Row (ii): (left)   Expense under TOU 0 of 2 small batteries between with and without multibatt objective
%           (right)  Expense under TOU 1 of 2 small batteries between with and without multibatt objective
% Row (iii): (left)  Average SoC diff of each dataset between TOU 0 and TOU 1 without multibatt objective
%            (right) Average SoC diff of each dataset between TOU 0 and TOU 1 with multibatt objective
% Row (iv): (left)   Expense vs. Percentage diff without multibatt objective
%           (right)  Expense vs. Percentage diff with multibatt objective

f = figure('PaperPosition',[0 0 21 20/4],'PaperOrientation','portrait','PaperUnits','centimeters');
t = tiledlayout(4,2,'TileSpacing','tight','Padding','tight');

% Compare the expense under TOU 0 between 1 big batt vs. 2 small batteries.
% without multibatt objective
% (1,1)
nexttile
stairs(networth_1batt_thcurrent,'-b','LineWidth',1) 
ylabel('Expense (THB)')
ylim([min(networth_1batt_thcurrent)-200 max(networth_1batt_thcurrent)+200])
hold on
grid on
yyaxis right
ylim([min(networth_without_sc_2batt_thcurrent)-200 max(networth_without_sc_2batt_thcurrent)+200])
stairs(networth_without_sc_2batt_thcurrent,'-r','LineWidth',1)
xlabel('Dataset index')
legend('Single batt system','Double batt system','Location','northeastoutside')
title('Expense under TOU 0 without SoC diff objective')

% Compare the expense under TOU 1 between 1 big batt vs. 2 small batteries.
% without multibatt objective
% (1,2)
nexttile
stairs(networth_1batt_smart,'-b','LineWidth',1) 
ylabel('Expense (THB)')
ylim([min(networth_1batt_smart)-200 max(networth_1batt_smart)+200])
hold on
grid on
yyaxis right 
ylim([min(networth_without_sc_2batt_smart)-200 max(networth_without_sc_2batt_smart)+200])
stairs(networth_without_sc_2batt_smart,'-r','LineWidth',1)
xlabel('Dataset index')
legend('Single batt system','Double batt system','Location','northeastoutside')
title('Expense under TOU 1 without SoC diff objective')


% Compare the expense under TOU 0 between with and without multibatt objective.
% with multibatt objective
% (2,1)
nexttile
stairs(networth_without_sc_2batt_thcurrent,'-b','LineWidth',1) 
ylabel('Expense (THB)')
ylim([min(networth_without_sc_2batt_thcurrent)-200 max(networth_without_sc_2batt_thcurrent)+200])
hold on
grid on
yyaxis right 
ylim([min(networth_with_sc_2batt_thcurrent)-200 max(networth_with_sc_2batt_thcurrent)+200])
stairs(networth_with_sc_2batt_thcurrent,'-r','LineWidth',1)
xlabel('Dataset index')
legend('without SoC diff obj.','with SoC diff obj.','Location','northeastoutside')
title('Expense of 2 batteries under TOU 0')

% Compare the expense under TOU 1 between with and without multibatt objective.
% with multibatt objective
% (2,2)
nexttile
stairs(networth_without_sc_2batt_smart,'-b','LineWidth',1) 
ylabel('Expense (THB)')
ylim([min(networth_without_sc_2batt_smart)-200 max(networth_without_sc_2batt_smart)+200])
hold on
grid on
yyaxis right 
ylim([min(networth_with_sc_2batt_smart)-200 max(networth_with_sc_2batt_smart)+200])
stairs(networth_with_sc_2batt_smart,'-r','LineWidth',1)
xlabel('Dataset index')
legend('without SoC diff obj.','SoC diff obj.','Location','northeastoutside')
title('Expense of 2 batteries under TOU 1')


% Compare average SoC diff under TOU 0 vs. TOU 1
% without multibatt objective
% (3,1)
nexttile
stairs(soc_without_sc_diff_thcurrent,'-b','LineWidth',1) 
ylabel('Percent Error (%)','Fontsize',16)
ylim([0 max(soc_without_sc_diff_thcurrent)+5])
hold on
grid on
yyaxis right 
ylim([0 max(soc_without_sc_diff_smart)+5])
stairs(soc_without_sc_diff_smart,'-r','LineWidth',1)
xlabel('Dataset index','Fontsize',16)
legend('TOU 0','TOU 1','Location','northeastoutside','Fontsize',12)
title('Avg. SoC diff (%) without SoC diff objective','Fontsize',16)

% Compare average SoC diff under TOU 0 vs. TOU 1
% with multibatt objective
% (3,2)
nexttile
stairs(soc_with_sc_diff_thcurrent,'-b','LineWidth',1) 
ylabel('Percent Error (%)','Fontsize',16)
ylim([0 max(soc_with_sc_diff_thcurrent)+5])
hold on
grid on
yyaxis right 
ylim([0 max(soc_with_sc_diff_smart)+5])
stairs(soc_with_sc_diff_smart,'-r','LineWidth',1)
xlabel('Dataset index','Fontsize',16)
legend('TOU 0','TOU 1','Location','northeastoutside','Fontsize',12)
title('Avg. SoC diff (%) with SoC diff objective','Fontsize',16)
fontsize(0.6,'centimeters')

% If deviation is high => Expense is low (one battery is enough).
% If deviation is low => two batteries are used.
% (4,1)
nexttile
scatter(soc_without_sc_diff_thcurrent, networth_without_sc_2batt_thcurrent) 
ylabel('Expense (THB)','Fontsize',16 )
ylim([min(networth_without_sc_2batt_thcurrent)-200 max(networth_without_sc_2batt_thcurrent)+200])
xlabel('Percent Difference (%)','Fontsize',16)
hold on
grid on
legend('Expense','Location','northeastoutside','Fontsize',12)
title('Expense with percent difference without SoC diff objective','Fontsize',16)

% (4,2)
nexttile
scatter(soc_with_sc_diff_thcurrent, networth_with_sc_2batt_thcurrent) 
ylabel('Expense (THB)','Fontsize',16 )
ylim([min(networth_with_sc_2batt_thcurrent)-200 max(networth_with_sc_2batt_thcurrent)+200])
xlabel('Percent Difference (%)','Fontsize',16)
hold on
grid on
legend('Expense','Location','northeastoutside','Fontsize',12)
title('Expense with percent difference with SoC diff objective','Fontsize',16)


% fontsize(0.6,'centimeters')
% print(f,'mul_batt_fig', '-depsc') 