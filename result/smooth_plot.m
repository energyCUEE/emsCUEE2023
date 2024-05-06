

%%
weight = [0 0.3 4 40];
f = figure('PaperPosition',[0 0 21 24/2],'PaperOrientation','portrait','PaperUnits','centimeters');
t = tiledlayout(4,1,'TileSpacing','tight','Padding','tight');
for i = 1:4
    sol = readtable("C:/Users/User/Desktop/VSCpython/EMS_on_production/ems_experiment/smoothcharge/pareto_solution/sol_Pchg_w_"+num2str(weight(i))+".csv",ReadRowNames=true);
    excess_gen = sol.PARAM_PV - sol.PARAM_PL;
    
    nexttile
    stairs(datetime(sol.datetime),excess_gen,'-k',LineWidth=1.5)
    hold on
    stairs(datetime(sol.datetime),sol.Pchg_1,'-b',LineWidth=1.5)
    hold on
    grid on
    stairs(datetime(sol.datetime),sol.Pdchg_1,'-r',LineWidth=1.5)
    ylabel('Power (kW)')
    ylim([-20 35])
    yticks(-20:10:35)
    title("Charge/discharge power when smoothcharge weight = "+num2str(weight(i)))
    if i == 1
        legend('Excess gen','Pchg','Pdchg',Location='northeastoutside')
    end    
    

end
fontsize(0.6,'centimeters')
print(f,"figures/"+"4plot_smooth",'-depsc')