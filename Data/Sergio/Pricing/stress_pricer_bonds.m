function [bonds_value, bond_prices, abs_bond_price_error, bond_durations] = stress_pricer_bonds(file_path,CAD_rates,EUR_rates,USD_rates)

global h_line
fprintf([h_line 'Pricing the bonds...\n' h_line])

% Global variables
global raw_data
global column_labels
% Days in a year: days per annum
global dpa

% Plotting parameters
global line_width font_size

%% Import data
sheet = 'Bonds';
range = 'A1:Y26';
% All the data will be in raw_data
[~, ~, raw_data] = xlsread(file_path, sheet, range);

% Read the headers of the excel file to know where is what
column_labels = raw_data(1, :);
% Remove the headers once for all to avoid offsetting all the time
raw_data(1, :) = [];
num_of_bonds = size(raw_data, 1);

%% Collect and process the data necessary for the calculations.
% Store values from raw_data into separate arrays for clarity and
% convenience. The names of the variables are self-explanatory.

% Positions
position = values_of('No. Securities');
% Face values
notionals = values_of('Face Value');
% Bond prices
bond_market_prices = values_of('Price');
% Coupon frequencies
coupon_frequencies = values_of('Coupon Frequency');
% Coupons
coupons = values_of('Coupon')./coupon_frequencies.*notionals;
% Yields
y = values_of('YTM')/100;
% Time to maturity in years
T = (cellfun(@datenum, raw_data(:, find(strcmp(column_labels, 'Maturity'...
    )))) - repmat(today, num_of_bonds, 1))/dpa;
% Number of coupons to be paid
num_of_coupons = ceil(coupon_frequencies.*T);
% The sectors represented in the portfolio
sectors = labels_of('Sector');
% The spreads for each sector
unique_sectors = unique(sectors);
spreads = cell(size(unique_sectors));
for k = 1:length(unique_sectors)
    [~, ~, spreads{k}] = xlsread(file_path, unique_sectors{k}, 'A1:H16');
end
% The currency each bond is in
currency = labels_of('Currency');
% The ratings of the bonds
ratings = labels_of('S&P');
% Tenor in years for the corporate spreads
tenor = [0.25; 0.5; 1; 2; 3; 4; 5; 7; 8; 9; 10; 15; 20; 25; 30]';

% Read the zero rates
zero_time_structure = [0.25 0.5 1:10 15 20 30];
% % CAD rates
% [CAD_rates, ~, ~] = xlsread(file_path, 'CAD');
% % Keep the most recent rates. They are contained in the the last row of the
% % Excel file.
% CAD_rates = CAD_rates(end, 1:end);
% % EURO rates
% [EUR_rates, ~, ~] = xlsread(file_path, 'EUR');
% % Keep the most recent rates. They are contained in the the last row of the
% % Excel file.
% EUR_rates = EUR_rates(end, 1:end);
% % USD rates
% [USD_rates, ~, ~] = xlsread(file_path, 'USD');
% % Keep the most recent rates. They are contained in the the last row of the
% % Excel file.
% USD_rates = USD_rates(end, 1:end);

%% Durations and prices
% Pre-allocate an array where the durations will be stored
bond_prices = zeros(size(bond_market_prices));
bond_prices_r_s = bond_prices;
bond_durations = bond_prices;

for k = 1:size(bond_durations, 1)
    
%     fprintf('\nBond %d\n', k)
%     fprintf('Sector: %s\n', sectors{k})
%     fprintf('Rating: %s\n', ratings{k})
%     fprintf('Currency: %s\n', currency{k})
    % The spreads
    the_spreads = sector2spreads(sectors{k}, unique_sectors, spreads);
    the_spreads(:, 1) = [];
    the_spreads = cell2mat(the_spreads(2:end, rating2bin(ratings{k})))'*1e-4;
    % The rates, depending on currency
    switch currency{k}
        case 'CAD'
            % fprintf('Will use CAD rates\n')
            zero_rates = CAD_rates;
        case 'EUR'
            % fprintf('Will use EUR rates\n')
            zero_rates = EUR_rates;
        case 'USD'
            % fprintf('Will use USD rates\n')
            zero_rates = USD_rates;
    end
    
    % t(k) is the time from today to the k-th cashflow
    t = zeros(1, num_of_coupons(k));
    % c(k) is the k-th cashflow
    c = t;
    t(2:end) = -1/coupon_frequencies(k);
    t = fliplr(cumsum(t)) + T(k);
    c(:) = coupons(k);
    c(end) = c(end) + notionals(k);
    
    s = interp1([0 tenor], [the_spreads(1) the_spreads], t);
    r = interp1([0 zero_time_structure], [zero_rates(1) zero_rates], t)/100;
    
    bond_prices_r_s(k) = sum(c.*exp(-(s + r).*t));
    bond_prices(k) = sum(c.*exp(-y(k)*t));
    bond_durations(k) = sum(c.*t.*exp(-y(k)*t))/bond_prices(k);
    
end

% DEV MODE [[[
% figure
% hold on
% plot([bond_market_prices bond_prices bond_prices_r_s], 'LineWidth', ...
%     line_width)
% legend({'Market', 'Yield', 'r+s'})
% set(gca, 'FontSize', font_size)
% plot(abs(bond_prices - bond_market_prices), 'LineWidth', line_width)
% title('Absolute difference between bond prices and bond market prices')
% ]]] DEV MODE

abs_bond_price_error = abs(bond_prices - bond_market_prices);

bonds_value = position'*bond_prices_r_s;

clearvars raw_data column_labels

end % price_bonds function

% fprintf('\nBond Prices\t |Price - Mkt Price|\t Bond Durations')
% fprintf('\n%f\t%15.6f\t%20.6f', [bond_prices, abs_bond_price_error, bond_durations]')
% fprintf('\n')
% fprintf('\n')
% fprintf('max|Price - Mkt Price| = %f', max(abs_bond_price_error))
% fprintf('\n')
% 
% % Write bond-related information to Excel files
% % xlswrite('../Data/bond_prices.xlsx', bond_prices)
% % xlswrite('../Data/durations.xlsx', bond_durations)