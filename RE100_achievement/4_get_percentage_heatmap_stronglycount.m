dataset_detail = readtable('batch_dataset_15min/dataset_detail.csv');
dataset_name = dataset_detail.name;
pv_type = dataset_detail.solar_type;
load_type = dataset_detail.load_type;
dataset_startdate = dataset_detail.start_date;

parentFolder = '/Users/CSRL-grad/Documents/nattapong/EMS_setting_in_PC/solution/EMS1';
allItems = dir(parentFolder);
subfolders = allItems([allItems.isdir]);
subfolderNames = {subfolders.name};
operating_points = subfolderNames(~ismember(subfolderNames, {'.', '..'}));

percent_EMS1_thcurrent = [];
percent_EMS1_smart1 = [];
percent_EMS2_thcurrent = [];
percent_EMS2_smart1 = [];
percent_EMS5_thcurrent = [];
percent_EMS5_smart1 = [];

for idx = 1: length(operating_points)
    op = operating_points{idx};
    count_num_RE100_thcurrent_EMS1 = 0;
    count_num_RE100_smart1_EMS1 = 0;
    count_num_RE100_thcurrent_EMS2 = 0;
    count_num_RE100_smart1_EMS2 = 0;
    count_num_RE100_thcurrent_EMS5 = 0;
    count_num_RE100_smart1_EMS5 = 0;
    num_day = 4;
    fprintf(op);
    fprintf('\n')
    for i = 1:length(dataset_name)
        
        sol_EMS1_thcurrent = load(strcat('solution/EMS1/', op, '/','THcurrent','_',dataset_name{i},'.mat'));
        sol_EMS1_smart = load(strcat('solution/EMS1/', op, '/', 'smart1','_',dataset_name{i},'.mat'));
        sol_EMS2_thcurrent = load(strcat('solution/', 'EMS2', '/', op, '/','THcurrent','_',dataset_name{i},'.mat'));
        sol_EMS2_smart = load(strcat('solution/', 'EMS2', '/',op, '/', 'smart1','_',dataset_name{i},'.mat'));
        sol_EMS5_thcurrent = load(strcat('solution/', 'EMS5', '/', op, '/','THcurrent','_',dataset_name{i},'.mat'));
        sol_EMS5_smart = load(strcat('solution/', 'EMS5', '/',op, '/', 'smart1','_',dataset_name{i},'.mat'));
        
        num_index_per_group = round(length(sol_EMS1_thcurrent.Pnet)/num_day,0);

        % strongly count
        for j = 1:num_day
            startIndex = round((j-1)*num_index_per_group)+1;
            endIndex = round(j*num_index_per_group);

            if all(sol_EMS1_thcurrent.Pnet(startIndex:endIndex) >= -1e-5)
                count_num_RE100_thcurrent_EMS1 = count_num_RE100_thcurrent_EMS1 + 1;
            end
            if all(sol_EMS1_smart.Pnet(startIndex:endIndex) >= -1e-5)
                count_num_RE100_smart1_EMS1 = count_num_RE100_smart1_EMS1 + 1;
            end
            if all(sol_EMS2_thcurrent.Pnet(startIndex:endIndex) >= -1e-5)
                count_num_RE100_thcurrent_EMS2 = count_num_RE100_thcurrent_EMS2 + 1;
            end
            if all(sol_EMS2_smart.Pnet(startIndex:endIndex) >= -1e-5)
                count_num_RE100_smart1_EMS2 = count_num_RE100_smart1_EMS2 + 1;
            end
            if all(sol_EMS5_thcurrent.Pnet(startIndex:endIndex) >= -1e-5)
                count_num_RE100_thcurrent_EMS5 = count_num_RE100_thcurrent_EMS5 + 1;
            end
            if all(sol_EMS5_smart.Pnet(startIndex:endIndex) >= -1e-5)
                count_num_RE100_smart1_EMS5 = count_num_RE100_smart1_EMS5 + 1;
            end
        end


    end
    percent_EMS1_thcurrent(idx) = round(count_num_RE100_thcurrent_EMS1/(length(dataset_name)*num_day)*100,2);
    percent_EMS1_smart1(idx) = round(count_num_RE100_smart1_EMS1/(length(dataset_name)*num_day)*100,2);
    percent_EMS2_thcurrent(idx) = round(count_num_RE100_thcurrent_EMS2/(length(dataset_name)*num_day)*100,2);
    percent_EMS2_smart1(idx) = round(count_num_RE100_smart1_EMS2/(length(dataset_name)*num_day)*100,2);
    percent_EMS5_thcurrent(idx) = round(count_num_RE100_thcurrent_EMS5/(length(dataset_name)*num_day)*100,2);
    percent_EMS5_smart1(idx) = round(count_num_RE100_smart1_EMS5/(length(dataset_name)*num_day)*100,2);
   
end
