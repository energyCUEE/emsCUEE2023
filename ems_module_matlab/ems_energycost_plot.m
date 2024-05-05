function [f,t] = ems_energycost_plot(sol)
    PARAM = sol.PARAM;
    %----------------prepare solution for plotting
    excess_gen = PARAM.PV - PARAM.PL;
    %end of prepare for solution for plotting
    resolution_HR = PARAM.Resolution/60; % (min) Resolution in minutes
    expense = -min(0,sol.Pnet)*resolution_HR.*PARAM.Buy_rate;
    expense_noems = -min(0,excess_gen)*resolution_HR.*PARAM.Buy_rate;
    start_date = datetime(PARAM.start_date);
    end_date = (datetime(PARAM.start_date)+minutes(PARAM.Horizon));
    vect = start_date:minutes(PARAM.Resolution):end_date;
    vect = vect(1:end-1);
    k = PARAM.Horizon/PARAM.Resolution; % length of variable
    f = figure('PaperPosition',[0 0 21 20],'PaperOrientation','portrait','PaperUnits','centimeters');
    t = tiledlayout(3,2,'TileSpacing','tight','Padding','tight');
    
    
    nexttile
    stairs(vect,PARAM.PV,'LineWidth',1.2) 
    grid on
    hold on
    stairs(vect,PARAM.PL,'LineWidth',1.2)
    ylabel('Power (kW)')
    legend('Solar','load','Location','northeastoutside')
    title('Solar generation and load consumption power')
    xlabel('Hour')
    xticks(start_date:hours(3):end_date)
    datetick('x','HH','keepticks')
    hold off
    
    nexttile
    stairs(vect,sol.soc(1:k,1),'-k','LineWidth',1.5)
    ylabel('SoC (%)')
    ylim([PARAM.battery.min(1)-5 PARAM.battery.max(1)+5])
    grid on
    hold on
    stairs(vect,[PARAM.battery.min(1)*ones(k,1),PARAM.battery.max(1)*ones(k,1)],'--m','HandleVisibility','off','LineWidth',1.2)
    hold on
    yyaxis right
    stairs(vect,sol.Pchg(:,1),'-b','LineWidth',1.2)
    hold on 
    stairs(vect,sol.Pdchg(:,1),'-r','LineWidth',1.2)    
    legend('Soc','P_{chg}','P_{dchg}','Location','northeastoutside')
    ylabel('Power (kW)')
    title('State of charge (SoC)')
    xlabel('Hour')
    xticks(start_date:hours(3):end_date)
    datetick('x','HH','keepticks')
    
    nexttile
    stairs(vect,excess_gen,'-k','LineWidth',1.2)
    yticks(-30:10:30)
    ylim([-30 30])
    ylabel('Excess power (kW)')
    hold on
    grid on
    yyaxis right 
    stairs(vect,sol.xchg(:,1),'-b','LineWidth',1)
    hold on 
    grid on
    stairs(vect,-sol.xdchg(:,1),'-r','LineWidth',1)
    legend('Excess power','x_{chg}','x_{dchg}','Location','northeastoutside')
    title('Excess power = P_{pv} - P_{load} and Battery charge/discharge status')
    xlabel('Hour')
    xticks(start_date:hours(3):end_date)
    datetick('x','HH','keepticks')
    yticks(-2:1:2)
    ylim([-1.5,1.5])
    hold off
    
    nexttile
    stairs(vect,expense,'-b','LineWidth',1)
    ylim([0 50])
    ylabel('Expense (THB)')
    hold on
    yyaxis right
    stairs(vect,cumsum(expense),'-k','LineWidth',1.5)
    ylabel('Cumulative expense (THB)')
    title('With EMS 1') 
    legend('Expense','Cumulative expense','Location','northeastoutside') 
    grid on
    xlabel('Hour')
    ylim([0 3500])
    xticks(start_date:hours(3):end_date)
    datetick('x','HH','keepticks')
    hold off
    
    nexttile
    hold all
    stairs(vect,sol.Pchg,'-b','LineWidth',1.2)
    stairs(vect,max(0,sol.Pnet),'-g','LineWidth',1.2)
    grid on
    stairs(vect,min(0,sol.Pnet),'-r','LineWidth',1.2)
    ylim([-100 100])
    ylabel('P_{net} / P_{chg} (kW)')
    yyaxis right
    stairs(vect,PARAM.Buy_rate,'-m','LineWidth',1.1)
    ylim([0 8])
    yticks(0:2:8)
    ylabel('TOU (THB)')
    legend('P_{chg}','P_{net} > 0 (curtail)','P_{net} < 0 (bought from grid)','Buy rate','Location','northeastoutside')
    title('P_{net} = PV + P_{dchg} - P_{chg} - P_{load}')
    xlabel('Hour')
    xticks(start_date:hours(3):end_date)
    datetick('x','HH','keepticks')
    
    nexttile
    stairs(vect,expense_noems,'-b','LineWidth',1)
    ylabel('Expense (THB)')
    ylim([0 50])
    hold on
    yyaxis right
    stairs(vect,cumsum(expense_noems),'-k','LineWidth',1.5)
    ylabel('Cumulative expense (THB)')
    title('Without EMS 1') 
    legend('Expense','Cumulative expense','Location','northeastoutside') 
    grid on
    xlabel('Hour')
    ylim([0 3500])
    xticks(start_date:hours(3):end_date)
    datetick('x','HH','keepticks')
    hold off
    fontsize(0.6,'centimeters')
end