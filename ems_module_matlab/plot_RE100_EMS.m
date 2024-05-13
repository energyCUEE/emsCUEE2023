% The solution of RE100 EMS is plot by this function.
% The characteristic of achieving RE is shown as follows.
%name = 'high_load_low_solar_10'; %% cannot be RE 100
%name = 'high_load_high_solar_4'; %% some days can be RE 100
%name = 'low_load_high_solar_4'; %% all days can be RE 100

% The graph consists 3 rows.
% Row (i): Load consumption and solar generation profile.
% Row (ii): Pnet, an important variable to investigate if the system require the grid power.
% Row (iii): statuses of charging and discharging pattern of the 1st battery on excess genration power.

clear; clc;
% The system size can be set when we vary PV size and battery size.
% Suppose we are interested in PV = 50 kW and Battery size = 125 kWh; 
% the solutions for this system size were solved and saved in the folder.
op = 'pv50kW_batt125kWh';

% List to store file name to investigate the plot.
name_list = {'high_load_low_solar_10', 'high_load_high_solar_4', 'low_load_high_solar_4'};

%%
f = figure(1);
% Define the figure which is divided into 3 rows and 3 columns.
num_col = length(name_list);
t = tiledlayout(3,num_col,'TileSpacing','tight','Padding','tight');
colororder({'k','k','k','k'})

% For loop for each file name.
for idx = 1:numel(name_list)
    name = name_list{idx};
    
    % Load solution.
    sol = load(fullfile('solution', 'EMS5', op, ['THcurrent_', name, '.mat']));
    PARAM = sol.PARAM;
    
    % Change unit
    h = 24 * PARAM.Horizon; % Optimization horizon in hours
    Horizon = PARAM.Horizon; % Optimization horizon in days
    % End of change unit

    %----------------prepare solution for plotting
    % Calculate excess generation power.
    excess_gen = PARAM.PV - PARAM.PL; 
    
    start_date = '2023-04-24';  %a start date for plotting graph
    start_date = datetime(start_date);
    end_date = start_date + Horizon;
  
    t1 = start_date; t2 = end_date; 
    vect = t1:minutes(PARAM.Resolution*60):t2 ; vect(end) = []; vect = vect';
    %end of prepare for solution for plotting

    % Row (i): Solar generation profile and Load consumption profile
    nexttile(idx)
    stairs(vect,PARAM.PV,'-b','LineWidth',1.2) 
    ylabel('Solar power (kW)')
    ylim([0 40])
    yticks(0:10:40)
    grid on
    hold on
    yyaxis right
    stairs(vect,PARAM.PL,'-r','LineWidth',1.2)
    legend('Solar','Load','Location','northeastoutside')
    ylim([0 40])
    yticks(0:10:40)
    ylabel('Load (kW)')
    xlabel('Hour')
    xticks(start_date:hours(6):end_date)
    title('Solar generation and load consumption')
    datetick('x','HH','keepticks')
    hold off
    
    % Row (ii): Pnet > 0 and Pnet < 0
    nexttile(idx+num_col)
    stairs(vect,max(0,sol.Pnet), '-','Color',[0.294 0.577 0.2],'LineWidth',1)
    hold on 
    grid on
    stairs(vect,min(0,sol.Pnet),'-r','LineWidth',1)
    hold on 
    stairs(vect,kron(sol.day_limit,ones(h,1)), 'b')
    legend('P_{net} > 0 (sold to grid)','P_{net} < 0 (bought from grid)', 'UB of |P_{net}|', 'Location','northeastoutside')
    xlabel('Hour')
    ylabel('P_{net} (kW)')
    ylim([-round(max(abs(sol.Pnet)))-1, round(max(abs(sol.Pnet)))+1])
    xticks(start_date:hours(6):end_date)
    title('P_{net} = PV + P_{dchg} - P_{chg} - P_{load}')
    datetick('x','HH','keepticks')
    
    % Row (iii): xchg/xdchg and excess gen of the 1st batt
    nexttile(idx+2*num_col)
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
    xlabel('Hour')
    xticks(start_date:hours(6):end_date)
    datetick('x','HH','keepticks')
    yticks(-1:1)
    ylim([-1.5,1.5])
    hold off
end

% Add title to the figure.
title(t,"High load low solar         " + "High load high solar          " + "Low load high solar  ")
% fontsize(0.6,'centimeters')
% print(f,'plot_RE100_result','-dpng')
