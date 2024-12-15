function project_wireless()
    % Initialize default parameters
    num_users = 10; % Default number of users
    noise_power = 0.001; % Default noise power
    total_power = 10; % Default total power
    bandwidth = 1e6; % Default bandwidth

    % Create the UI for the simulation
    create_ui(num_users, noise_power, total_power, bandwidth);
end

%% Create Interactive UI
function create_ui(num_users, noise_power, total_power, bandwidth)
    % Create a UI to control simulation parameters and run the simulation
    f = figure('Position', [100, 100, 600, 500], 'Name', 'Wireless Dashboard', 'NumberTitle', 'off');

    % Slider for number of users
    uicontrol('Style', 'text', 'Position', [50 420 150 20], 'String', 'Number of Users');
    num_users_slider = uicontrol('Style', 'slider', 'Position', [200 420 150 20], 'Min', 2, 'Max', 50, 'Value', num_users);
    num_users_text = uicontrol('Style', 'text', 'Position', [360 420 50 20], 'String', num2str(num_users));
    addlistener(num_users_slider, 'ContinuousValueChange', @(src, event) update_slider_value(src, num_users_text));

    % Slider for noise power
    uicontrol('Style', 'text', 'Position', [50 380 150 20], 'String', 'Noise Power');
    noise_slider = uicontrol('Style', 'slider', 'Position', [200 380 150 20], 'Min', 0.001, 'Max', 0.1, 'Value', noise_power);
    noise_text = uicontrol('Style', 'text', 'Position', [360 380 50 20], 'String', sprintf('%.3f', noise_power));
    addlistener(noise_slider, 'ContinuousValueChange', @(src, event) update_slider_value(src, noise_text));

    % Button to run simulation and update Firebase
    uicontrol('Style', 'pushbutton', 'Position', [50 330 150 30], 'String', 'Run Simulation', ...
              'Callback', @(src, event) run_simulation_with_ai(num_users_slider, noise_slider, total_power, bandwidth));

    % Axes for NOMA vs OMA Throughput
    axes_noma = axes('Parent', f, 'Position', [0.1, 0.1, 0.35, 0.4]);
    title(axes_noma, 'NOMA vs OMA Throughput');
    xlabel(axes_noma, 'User Index');
    ylabel(axes_noma, 'Throughput (bps)');

    % Axes for AI Analysis
    axes_ai = axes('Parent', f, 'Position', [0.55, 0.1, 0.35, 0.4]);
    title(axes_ai, 'AI Analysis of Noise Impact');
    xlabel(axes_ai, 'Noise Levels');
    ylabel(axes_ai, 'Predicted Throughput (bps)');

    % Store axes handles in app data
    setappdata(f, 'axes_noma', axes_noma);
    setappdata(f, 'axes_ai', axes_ai);
end

%% Update Slider Value Display
function update_slider_value(slider, text)
    value = get(slider, 'Value');
    if get(slider, 'Min') == 0.001 % Check if it's the noise slider
        set(text, 'String', sprintf('%.3f', value));
    else
        set(text, 'String', num2str(round(value)));
    end
end

%% Run Simulation with AI and Update Firebase
function run_simulation_with_ai(num_users_slider, noise_slider, total_power, bandwidth)
    % Extract values from sliders
    num_users = round(get(num_users_slider, 'Value'));
    noise_power = get(noise_slider, 'Value');

    % Perform simulation
    [throughput_noma, throughput_oma, predicted_throughput, noise_levels] = noma_oma_simulation(num_users, noise_power, total_power, bandwidth);

    % Train and use AI model
    ai_predictions = train_and_predict_ai(num_users, noise_power, total_power, throughput_noma, throughput_oma);

    % Update plots
    axes_noma = getappdata(gcf, 'axes_noma');
    axes_ai = getappdata(gcf, 'axes_ai');

    % Plot NOMA vs OMA Throughput
    axes(axes_noma);
    cla;
    plot(1:num_users, throughput_noma, 'o-', 'LineWidth', 2, 'DisplayName', 'NOMA Throughput');
    hold on;
    plot(1:num_users, throughput_oma * ones(1, num_users), 'x--', 'LineWidth', 2, 'DisplayName', 'OMA Throughput');
    hold off;
    legend('show', 'Location', 'best');
    title('NOMA vs OMA Throughput');
    xlabel('User Index');
    ylabel('Throughput (bps)');
    grid on;

    % Plot AI Analysis of Noise Impact
    axes(axes_ai);
    cla;
    plot(noise_levels, predicted_throughput, '-o', 'LineWidth', 2, 'DisplayName', 'Predicted');
    hold on;
    plot(linspace(0.001, 0.1, 10), ai_predictions, '--x', 'LineWidth', 2, 'DisplayName', 'AI Predictions');
    hold off;
    legend('show', 'Location', 'best');
    title('AI Analysis: Impact of Noise on Throughput');
    xlabel('Noise Levels');
    ylabel('Throughput (bps)');
    grid on;

    % Update Firebase automatically
    update_firebase_with_ai(num_users, noise_power, total_power, bandwidth, throughput_noma, throughput_oma, predicted_throughput, ai_predictions);
end

%% Update Firebase Data with Test Counter
function update_firebase_with_ai(num_users, noise_power, total_power, bandwidth, throughput_noma, throughput_oma, predicted_throughput, ai_predictions)
    % Firebase URL
    firebaseURL = 'https://wireless-f8c8a-default-rtdb.firebaseio.com/results';

    % Read the current counter from Firebase
    counter_url = [firebaseURL, '/counter.json'];
    options = weboptions('RequestMethod', 'get', 'MediaType', 'application/json');
    try
        counter = webread(counter_url, options);
        if isempty(counter)
            counter = 0; % If no counter exists, start from 0
        end
    catch
        disp('Error reading counter from Firebase. Starting from 0.');
        counter = 0;
    end

    % Increment the counter
    counter = counter + 1;
    test_name = ['test', num2str(counter)];

    % Prepare data
    data = struct();
    data.num_users = num_users;
    data.noise_power = noise_power;
    data.total_power = total_power;
    data.bandwidth = bandwidth;
    data.throughput_noma = throughput_noma;
    data.throughput_oma = throughput_oma;
    data.predicted_throughput = predicted_throughput;
    data.ai_predictions = ai_predictions; % Add AI Predictions

    % Upload data for the new test
    options = weboptions('RequestMethod', 'put', 'MediaType', 'application/json');
    try
        webwrite([firebaseURL, '/', test_name, '.json'], data, options);
        disp(['Data successfully sent to Firebase as ', test_name]);

        % Update the counter in Firebase
        webwrite(counter_url, counter, options);
        disp(['Counter updated to ', num2str(counter)]);
    catch ME
        disp('Error uploading to Firebase:');
        disp(ME.message);
    end
end

%% Simulation Function
function [throughput_noma, throughput_oma, predicted_throughput, noise_levels] = noma_oma_simulation(num_users, noise_power, total_power, bandwidth)
    % Generate realistic channel conditions
    channel_gain = abs(sqrt(0.5) * (randn(1, num_users) + 1i * randn(1, num_users))); % Rayleigh fading

    % NOMA Power Allocation
    noma_power = total_power * (1 ./ (1:num_users)); % Power allocation
    interference_power = sum(noma_power) - noma_power;
    sinr_noma = noma_power ./ (noise_power + interference_power);
    throughput_noma = log2(1 + sinr_noma);

    % OMA Power Allocation
    oma_power = total_power / num_users;
    sinr_oma = oma_power / noise_power;
    throughput_oma = log2(1 + sinr_oma);

    % AI Prediction for Noise Levels
    noise_levels = [0.001, 0.01, 0.05, 0.1];
    predicted_throughput = zeros(1, length(noise_levels));
    for i = 1:length(noise_levels)
        predicted_throughput(i) = mean(log2(1 + noma_power ./ (noise_levels(i) + interference_power)));
    end
end

%% Train and Use AI Model
function ai_predictions = train_and_predict_ai(num_users, noise_power, total_power, throughput_noma, throughput_oma)
    % Prepare training data
    num_samples = length(throughput_noma);
    features = [num_users .* ones(num_samples, 1), noise_power .* ones(num_samples, 1), total_power .* ones(num_samples, 1)];
    labels = throughput_noma(:); % Use NOMA throughput as target for now

    % Train a regression model
    model = fitrgp(features, labels, 'KernelFunction', 'squaredexponential', 'Standardize', true);

    % Predict throughput for different conditions
    test_data = [linspace(2, 50, 10)', linspace(0.001, 0.1, 10)', total_power .* ones(10, 1)];
    ai_predictions = predict(model, test_data);
end
