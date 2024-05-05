clear;clc;

root_folder = "C:/Users/User/Desktop/VSCpython/opt_test/input_data/48_batch/"; % change this line to your Path
dataset_detail = readtable(root_folder+"dataset_detail.csv");  
dataset_name = dataset_detail.name; % list of dataset name
pv_type = dataset_detail.pv_type;
load_type = dataset_detail.load_type;
dataset_startdate = dataset_detail.start_date;

for i = 1:length(dataset_name)
    solution_path = 'C:/Users/User/Desktop/VSCpython/EMS_on_production/ems_experiment/AC/solution/AC/';
    sol_thcurrent = load(strcat(solution_path,'THcurrent','_',dataset_name{i},'.mat'));
    sol_smart = load(strcat(solution_path,'smart1','_',dataset_name{i},'.mat'));
    Resolution_HR = sol_smart.PARAM.Resolution/60;
    
    expense_with_ems_thcurrent(i,1) = sum(max(0,-sol_thcurrent.Pnet).*sol_thcurrent.PARAM.Buy_rate*Resolution_HR);
    expense_with_ems_smart(i,1) = sum(max(0,-sol_smart.Pnet).*sol_smart.PARAM.Buy_rate*Resolution_HR);
    Pnet_thcurrent = sol_thcurrent.PARAM.PV - sol_thcurrent.PARAM.Puload - sol_thcurrent.Pac_lab - sol_thcurrent.Pac_student;
    Pnet_smart = sol_smart.PARAM.PV - sol_smart.PARAM.Puload - sol_smart.Pac_lab - sol_smart.Pac_student; %pnet when force ac to use the same load as ems
    
    expense_without_ems_thcurrent(i,1) = -sum(sol_thcurrent.PARAM.Buy_rate.*min(0,Pnet_thcurrent)*Resolution_HR );
    expense_without_ems_smart(i,1) = -sum(sol_smart.PARAM.Buy_rate.*min(0,Pnet_smart)*Resolution_HR );
    
    percent_ACstudent_util_thcurr(i,1) =  floor(100*sol_thcurrent.PARAM.ACschedule'*sum(sol_thcurrent.Xac_student,2)/sum(sol_thcurrent.PARAM.ACschedule));
    percent_ACstudent_util_smart(i,1) =  floor(100*sol_smart.PARAM.ACschedule'*sum(sol_smart.Xac_student,2)/sum(sol_smart.PARAM.ACschedule));
    
    percent_AClab_util_thcurr(i,1) =  floor(100*sol_thcurrent.PARAM.ACschedule'*sum(sol_thcurrent.Xac_lab,2)/sum(sol_thcurrent.PARAM.ACschedule));
    percent_AClab_util_smart(i,1) =  floor(100*sol_smart.PARAM.ACschedule'*sum(sol_smart.Xac_lab,2)/sum(sol_smart.PARAM.ACschedule));
    
    
end
%%

expense_save_thcurrent = - expense_with_ems_thcurrent + expense_without_ems_thcurrent;
expense_save_smart = -expense_with_ems_smart + expense_without_ems_smart;
percent_save_thcurrent = expense_save_thcurrent*100./expense_without_ems_thcurrent;
percent_save_smart = expense_save_smart*100./expense_without_ems_smart;
a = table(percent_AClab_util_smart, ...
            percent_AClab_util_thcurr, ...
            percent_ACstudent_util_smart, ...
            percent_ACstudent_util_thcurr, ...
            percent_save_thcurrent, ...
            percent_save_smart, ...
            expense_with_ems_thcurrent, ...
            expense_with_ems_smart, ...
            expense_without_ems_thcurrent, ...
            expense_without_ems_smart, ...
            expense_save_thcurrent, ...
            expense_save_smart, ...
            pv_type, ...
            load_type);
%%
% actual expense save histogram
pv_list = {'low_solar','high_solar'};
for i = 1:2
    f = figure('Position', [0 0 2480 1000]);
    t = tiledlayout(2,2);
    plot_case = a(strcmp(a.pv_type,pv_list{i}),:);
    
    nexttile;
    bar([plot_case.expense_with_ems_thcurrent,plot_case.expense_without_ems_thcurrent])
    grid on
    legend('with EMS3','without EMS3','Location','north')
    title('Expense when TOU 0 is used')
    ylabel('Expense (THB)')
    xlabel('Data set index')
    yticks(0:100:700)
    ylim([0 700])
    
    nexttile;
    histogram(plot_case.expense_save_thcurrent,10,'BinWidth',50,'Normalization','percentage')
    grid on
    title('Histogram of expense save by EMS 3 when TOU 0 is used')
    xlabel('Expense save (THB)')
    ylabel('Percent')
    xticks(175:50:600)
    xlim([150 600])
    ylim([0 100])
    yticks(0:20:100)
    
    nexttile;
    bar([plot_case.expense_with_ems_smart,plot_case.expense_without_ems_smart])
    grid on
    legend('with EMS3','without EMS3','Location','north')
    title('Expense when TOU 1 is used')
    ylabel('Expense (THB)')
    xlabel('Data set index')
    yticks(0:100:700)
    ylim([0 700])

    nexttile;
    histogram(plot_case.expense_save_smart,10,'BinWidth',50,'Normalization','percentage')
    grid on
    title('Histogram of expense save by EMS 3 when TOU 1 is used')
    xlabel('Expense save (THB)')
    ylabel('Percent')
    xticks(175:50:600)
    xlim([150 600])
    ylim([0 100])
    yticks(0:20:100)
    fontsize(0.6,'centimeters')
    exportgraphics(t,strcat('figures/AC/',pv_list{i},'_bar_actual_hist.png'))
    exportgraphics(t,strcat('figures/AC/',pv_list{i},'_bar_actual_hist.eps'))
end
%%
% ac utilization
pv_list = {'low_solar','high_solar'};
for i = 1:2
    f = figure('PaperPosition',[0 0 21 20*2/3],'PaperOrientation','portrait','PaperUnits','centimeters');
    t = tiledlayout(2,2,'TileSpacing','tight','Padding','tight');
    plot_case = a(strcmp(a.pv_type,pv_list{i}),:);

    nexttile;
    histogram(plot_case.percent_AClab_util_thcurr,10,'BinWidth',5,'Normalization','percentage','BinLimits',[0 100])
    grid on
    title('Histogram of machine laboratory AC utilization under TOU 0')
    xlabel('AC utilization (%)')
    ylabel('Percent')
    xticks(0:10:100)
    xlim([0 110])
    ylim([0 100])
    yticks(0:10:100)
    
    

    nexttile;
    histogram(plot_case.percent_ACstudent_util_thcurr,10,'BinWidth',5,'Normalization','percentage','BinLimits',[0 100])
    grid on
    title('Histogram of student room AC utilization under TOU 0')
    xlabel('AC utilization (%)')
    ylabel('Percent')
    xticks(0:10:100)
    xlim([0 110])
    ylim([0 100])
    yticks(0:10:100)
    
    nexttile;
    histogram(plot_case.percent_AClab_util_smart,10,'BinWidth',5,'Normalization','percentage','BinLimits',[0 100])
    grid on
    title('Histogram of machine laboratory AC utilization under TOU 1')
    xlabel('AC utilization (%)')
    ylabel('Percent')
    xticks(0:10:100)
    xlim([0 110])
    ylim([0 100])
    yticks(0:10:100)
    
    nexttile;
    histogram(plot_case.percent_ACstudent_util_smart,10,'BinWidth',5,'Normalization','percentage','BinLimits',[0 100])
    grid on
    title('Histogram of student room AC utilization under TOU 1')
    xlabel('AC utilization (%)')
    ylabel('Percent')
    xticks(0:10:100)
    xlim([0 110])
    ylim([0 100])
    yticks(0:10:100)

    fontsize(0.6,'centimeters')
    print(f,strcat('figures/AC/',pv_list{i},'_ac_hist'),'-dpng')
    print(f,strcat('figures/AC/',pv_list{i},'_ac_hist'),'-depsc')
end

