pv_size_list = (50:1:70);
batt_size_list = round((150:5:400) .* (100/60) / 2);

pv_size_all = [];
batt_size_all = [];
i = 1;

for pv = pv_size_list
    for batt = batt_size_list
        pv_size_all(i, 1) = pv;
        batt_size_all(i, 1) = batt;
        i = i + 1;
    end
end

cMap = interp1(0:2, [1 0 0; 1 1 0; 0 0.8 0], linspace(0,2,256));
cMap = cMap .^(1/2.4);

percent_EMS1_thcurrent = load("data_heatmap_plot/percent_EMS1_thcurrent.mat");
percent_EMS1_smart1 = load("data_heatmap_plot/percent_EMS1_smart1.mat");
percent_EMS2_thcurrent = load("data_heatmap_plot/percent_EMS2_thcurrent.mat");
percent_EMS2_smart1 = load("data_heatmap_plot/percent_EMS2_smart1.mat");
% EMS5: The TOU does not affect the RE 100 EMS, so we select only TOU 0
percent_EMS5_thcurrent = load("data_heatmap_plot/percent_EMS5_thcurrent.mat");

figure(1)
tbl = table(pv_size_all, batt_size_all, percent_EMS1_thcurrent.percent_EMS1_thcurrent');
hm = heatmap(tbl, 'pv_size_all', 'batt_size_all', 'ColorMap', cMap, 'ColorLimits', [0, 100], 'ColorVariable', 'Var3');
hm.YDisplayData = flip(hm.YDisplayData);
hm.Colormap = cMap;
hm.XLabel = 'PV size (kW)';
hm.YLabel = 'A battery size (kWh)';
hm.Title = 'RE percentage by Energy cost under TOU 0';
fontsize(0.4, "centimeters")

figure(2)
tbl = table(pv_size_all, batt_size_all, percent_EMS1_smart1.percent_EMS1_smart1');
hm = heatmap(tbl, 'pv_size_all', 'batt_size_all', 'ColorMap', cMap, 'ColorLimits', [0, 100], 'ColorVariable', 'Var3');
hm.YDisplayData = flip(hm.YDisplayData);
hm.Colormap = cMap;
hm.XLabel = 'PV size (kW)';
hm.YLabel = 'A battery size (kWh)';
hm.Title = 'RE percentage by Energy cost under TOU 1';
fontsize(0.4, "centimeters")

figure(3)
tbl = table(pv_size_all, batt_size_all, percent_EMS2_thcurrent.percent_EMS2_thcurrent');
hm = heatmap(tbl, 'pv_size_all', 'batt_size_all', 'ColorMap', cMap, 'ColorLimits', [0, 100], 'ColorVariable', 'Var3');
hm.YDisplayData = flip(hm.YDisplayData);
hm.Colormap = cMap;
hm.XLabel = 'PV size (kW)';
hm.YLabel = 'A battery size (kWh)';
hm.Title = 'RE percentage by Profit under TOU 0';
fontsize(0.4, "centimeters")

figure(4)
tbl = table(pv_size_all, batt_size_all, percent_EMS2_smart1.percent_EMS2_smart1');
hm = heatmap(tbl, 'pv_size_all', 'batt_size_all', 'ColorMap', cMap, 'ColorLimits', [0, 100], 'ColorVariable', 'Var3');
hm.YDisplayData = flip(hm.YDisplayData);
hm.Colormap = cMap;
hm.XLabel = 'PV size (kW)';
hm.YLabel = 'A battery size (kWh)';
hm.Title = 'RE percentage by Profit under TOU 1';
fontsize(0.4, "centimeters")

figure(5)
tbl = table(pv_size_all, batt_size_all, percent_EMS5_thcurrent.percent_EMS5_thcurrent');
hm = heatmap(tbl, 'pv_size_all', 'batt_size_all', 'ColorMap', cMap, 'ColorLimits', [0, 100], 'ColorVariable', 'Var3');
hm.YDisplayData = flip(hm.YDisplayData);
hm.Colormap = cMap;
hm.XLabel = 'PV size (kW)';
hm.YLabel = 'A battery size (kWh)';
hm.Title = 'RE percentage by Profit under TOU 1';
fontsize(0.4, "centimeters")
