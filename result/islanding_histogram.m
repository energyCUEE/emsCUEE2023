clear;clc;

root_folder = "C:/Users/User/Desktop/VSCpython/opt_test/input_data/48_batch/"; % change this line to your Path
dataset_detail = readtable(root_folder+"dataset_detail.csv");  
dataset_name = dataset_detail.name; % list of dataset name
pv_type = dataset_detail.pv_type;
load_type = dataset_detail.load_type;
dataset_startdate = dataset_detail.start_date;

for i = 1:length(dataset_name)
    solution_path = 'C:/Users/User/Desktop/VSCpython/EMS_on_production/ems_experiment/AC/solution/islanding/';
    sol = load(strcat(solution_path,dataset_name{i},'.mat'));
    if isempty(sol.soc)  == 0
        PARAM = sol.PARAM;
        percent_ACstudent_util(i,1) =  floor(100*PARAM.ACschedule'*sum(sol.Xac_student,2)/sum(PARAM.ACschedule));
        percent_AClab_util(i,1) = floor(100*PARAM.ACschedule'*sum(sol.Xac_lab,2)/sum(PARAM.ACschedule));
        pv(i,1) = pv_type(i);
    end  
    
end
%%
a = table(pv,percent_ACstudent_util,percent_AClab_util);
%%
% ac utilization histogram
pv_list = {'low_solar','high_solar'};
for i = 1:2
    f = figure('PaperPosition',[0 0 21 20/3],'PaperOrientation','portrait','PaperUnits','centimeters');
    t = tiledlayout(1,2,'TileSpacing','tight','Padding','tight');
    plot_case = a(strcmp(a.pv,pv_list{i}),:);

    nexttile;
    histogram(plot_case.percent_AClab_util,10,'BinWidth',5,'Normalization','percentage','BinLimits',[0 100])
    grid on
    title('Histogram of machine laboratory AC utilization')
    xlabel('AC utilization (%)')
    ylabel('Percent')
    xticks(0:10:100)
    xlim([0 110])
    ylim([0 100])
    yticks(0:20:100)
    
    

    nexttile;
    histogram(plot_case.percent_ACstudent_util,10,'BinWidth',5,'Normalization','percentage','BinLimits',[0 100])
    grid on
    title('Histogram of student room AC utilization')
    xlabel('AC utilization (%)')
    ylabel('Percent')
    xticks(0:10:100)
    xlim([0 110])
    ylim([0 100])
    yticks(0:20:100)
    
    fontsize(0.6,'centimeters')
    print(f,strcat('figures/islanding/',pv_list{i},'_ac_hist'),'-dpng')
    print(f,strcat('figures/islanding/',pv_list{i},'_ac_hist'),'-depsc')
end