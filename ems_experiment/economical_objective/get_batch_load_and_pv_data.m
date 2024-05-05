function [PL,PV] = get_batch_load_and_pv_data(dataset_path,dataset_name, desired_PVcapacity)
    data = readtable(dataset_path + dataset_name + ".csv");
    PL = data.PLtot;
    PV = data.PVtot*desired_PVcapacity/8; %scale PV from to desired_PVcapacity
end