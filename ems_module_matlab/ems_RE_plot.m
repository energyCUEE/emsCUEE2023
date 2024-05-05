function [f,t] = ems_RE_plot(sol)
    PARAM = sol.PARAM;
    %----------------prepare solution for plotting
    excess_gen = PARAM.PV - PARAM.PL;
    resolution_HR = PARAM.Resolution/60; % (min) Resolution in minutes
    Npoint1day = 24*60/PARAM.Resolution; % the number op points in 1 day
    start_date = datetime(PARAM.start_date);
    end_date = (datetime(PARAM.start_date)+minutes(PARAM.Horizon));
    vect = start_date:minutes(PARAM.Resolution):end_date;
    vect = vect(1:end-1);
    k = PARAM.Horizon/PARAM.Resolution; % length of variable
   
    f = figure('PaperPosition',[0 0 21 24/2],'PaperOrientation','portrait','PaperUnits','centimeters');
    t = tiledlayout(2,2,'TileSpacing','tight','Padding','tight');    
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
    ylim([PARAM.battery.min(:,1)-5 PARAM.battery.max(:,1)+5])
    yticks(PARAM.battery.min(:,1):10:PARAM.battery.max(:,1))
    grid on
    hold on
    stairs(vect,[PARAM.battery.min(:,1)*ones(k,1),PARAM.battery.max(:,1)*ones(k,1)],'--m','HandleVisibility','off','LineWidth',1.2)
    hold on
    yyaxis right
    stairs(vect,sol.Pchg(:,1),'-b','LineWidth',1)
    hold on 
    stairs(vect,sol.Pdchg(:,1),'-r','LineWidth',1)
    yticks(0:10:PARAM.battery.charge_rate(:,1)+10)
    ylim([0 PARAM.battery.charge_rate(:,1)+10])
    legend('Soc','P_{chg}','P_{dchg}','Location','northeastoutside')
    ylabel('Power (kW)')
    title('State of charge 1 (SoC)','FontSize',24)
    xlabel('Hour')
    xticks(start_date:hours(3):end_date)
    datetick('x','HH','keepticks')

    nexttile
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
    title('Excess power = P_{pv} - P_{load} and Battery charge/discharge status')
    xlabel('Hour')
    xticks(start_date:hours(3):end_date)
    datetick('x','HH','keepticks')
    yticks(-1:1)
    ylim([-1.5,1.5])
    hold off

    nexttile
    stairs(vect,max(0,sol.Pnet),'-g','LineWidth',1)
    hold on 
    grid on
    stairs(vect,min(0,sol.Pnet),'-r','LineWidth',1)
    hold on
    stairs(vect,-kron(sol.maxPnet1day,ones(Npoint1day,1)),'-b','LineWidth',1)
    legend('P_{net} > 0 (curtail)','P_{net} < 0 (bought from grid)','Upper bound of Pnet < 0','Location','northeastoutside')
    title('P_{net} = PV + P_{dchg} - P_{chg} - P_{load}','FontSize',24)
    xlabel('Hour')
    ylabel('Power (kW)')
    xticks(start_date:hours(3):end_date)
    datetick('x','HH','keepticks')
    hold off
    fontsize(0.6,'centimeters')

end