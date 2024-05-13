function [PV,PL] = loadPVandPLcsv(Resolution,name)
    PV_scale_factor = 6; % scale up from 8kW to 48 kW
    step = Resolution*4;
    source = strcat(name,'.csv');
    data = readtable(strcat('batch_dataset_15min/',name));
    PV = PV_scale_factor*data.PVtot;
    PL = data.PLtot;
    PV = PV(1:step:end);
    PL = PL(1:step:end);
  
end