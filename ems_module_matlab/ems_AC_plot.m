function [f,t] = EMS3_plot(sol)
    PARAM = sol.PARAM;
    %----------------prepare solution for plotting
    
    Pload = sol.Pac_lab + PARAM.Puload + sol.Pac_student; % Load + Battery charge
    excess_gen = PARAM.PV - Pload;
    %end of prepare for solution for plotting
    resolution_HR = PARAM.Resolution/60; % (min) Resolution in minutes
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
    stairs(vect,Pload,'LineWidth',1.2)
    ylabel('Power (kW)')
    legend('Solar','load','Location','northeastoutside')
    title('Solar generation and load consumption (P_{load} = P_{uload} + P_{ac,s} + P_{ac,m})')
    xlabel('Hour')
    xticks(start_date:hours(3):end_date)
    datetick('x','HH','keepticks')
    hold off
    
        
    nexttile
    stairs(vect,sol.soc(1:k,1),'k','LineWidth',1.5) 
    ylabel('SoC (%)')
    ylim([15 85])
    hold on
    stairs(vect,[PARAM.battery.min(1)*ones(k,1),PARAM.battery.max(1)*ones(k,1)],'--m','LineWidth',1.5,'HandleVisibility','off') 
    grid on
    hold on
    yyaxis right
    stairs(vect,Pload,'-r','LineWidth',1.2)
    ylim([0 10])
    
    yticks(0:2.5:10)
    ylabel('Load (kW)')
    legend('SoC','Load','Location','northeastoutside')
    title('State of charge (SoC) and load consumption (P_{uload} + P_{ac,s} + P_{ac,m})')
    xlabel('Hour')
    xticks(start_date:hours(3):end_date)
    datetick('x','HH','keepticks')
    hold off
    
    nexttile
    hold all
    stairs(vect,excess_gen,'-k','LineWidth',1.2) 
    grid on
    ylim([-10 10])
    yticks(-10:5:10)
    ylabel('Excess power (kW)')
    yyaxis right 
    stairs(vect,sol.xchg(:,1),'-b','LineWidth',1)
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
    stairs(vect,sol.Pac_lab*100/PARAM.AClab.Paclab_rate,'-r','LineWidth',1.2)
    ylim([0 100])
    ylabel('AC level (%)')
    yticks([0 50 70 80 100])
    hold on 
    grid on
    yyaxis right
    stairs(vect,PARAM.ACschedule,'-.k','LineWidth',1.2)
    ylim([0 1.5])
    yticks([0 1])
    legend('AC level','ACschedule')
    title('Lab AC level')
    xlabel('Hour')
    xticks(start_date:hours(3):end_date)
    datetick('x','HH','keepticks')
    hold off
    
    nexttile
    stairs(vect,max(0,sol.Pnet),'-r','LineWidth',1.2)
    hold on 
    grid on
    stairs(vect,min(0,sol.Pnet),'-b','LineWidth',1.2)
    legend('P_{net} > 0 (curtail)','P_{net} < 0 (bought from grid)','Location','northeastoutside')
    title('P_{net} = PV + P_{dchg} - P_{chg} - P_{load}')
    xlabel('Hour')
    ylim([-20 10])
    yticks(-25:5:10)
    ylabel('P_{net} (kW)')
    xticks(start_date:hours(3):end_date)
    datetick('x','HH','keepticks')
    hold off
    
    
    nexttile
    stairs(vect,sol.Pac_student*100/PARAM.ACstudent.Pacstudent_rate,'-r','LineWidth',1.2)
    ylim([0 100])
    yticks([0 50 70 80 100])
    ylabel('AC level (%)')
    hold on 
    grid on
    yyaxis right
    stairs(vect,PARAM.ACschedule,'-.k','LineWidth',1.2)
    yticks([0 1])
    ylim([0 1.5])
    legend('AC level','ACschedule')
    title('Student AC level')
    xlabel('Hour')
    xticks(start_date:hours(3):end_date)
    datetick('x','HH','keepticks')
    hold off
    fontsize(0.6,'centimeters')

end