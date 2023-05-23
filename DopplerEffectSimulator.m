classdef DopplerEffectSimulator < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        Figure               matlab.ui.Figure
        metersPanel          matlab.ui.container.Panel
        speedometer          matlab.ui.control.Gauge
        speedometerLabel     matlab.ui.control.Label
        machmeter            matlab.ui.control.Gauge
        machmeterLabel       matlab.ui.control.Label
        SourceMetersLabel    matlab.ui.control.Label
        controlsPanel        matlab.ui.container.Panel
        StatusLamp           matlab.ui.control.Lamp
        SourceControlsLabel  matlab.ui.control.Label
        speedKnob            matlab.ui.control.Knob
        speedKnobLabel       matlab.ui.control.Label
        frequencyKnob        matlab.ui.control.Knob
        frequencyKnobLabel   matlab.ui.control.Label
    end

    
    properties (Access = private)
        
        %% Simulation properties

        dt = 0.05               % Time resolution in s
        Tc = 0                  % Time elapsed within current period
        Te = 0                  % Observed period estimate
        f = 0;                  % Observed frequency 
        f0 = 0;                 % Source frequency
        T = 0;                  % Source period
        c = 343;                % Wave speed (Sound in dry air at 20 °C)
        vs = 0;                 % Source velocity
        mach_num = 0;           % Mach number   
        src = [0 0]             % Source position
        obs = [0 0]             % Observer position
        lim = 2*1e3;            % Simulation space boundary
        obs_lim = 0.2;          % Source-Observer distance boundary
        sim_space_lim = 0.1;    % Source-Simulation space distance boundary        
       
        %% Utility properties

        wavefronts_num = 28;    % Max number of wavefronts to buffer        
        wavefronts = struct();  % Wavefronts circular buffer          
        w = 0;                  % Wavefronts circular buffer index
        theta = 0:0.01:2*pi;    % 360° angle vector
        t = 0:0.005:1;          % 1s time vector
        span = 1                % Samples display range for waveforms plots
        blink                   % Blinking indicator status

        %% GUI Handles

        fig                     % Visualization Window figure handle
        ax                      % Simulation subplot axes handle
        src_ax                  % Source waveform subplot axes handle
        obs_ax                  % Observed waveform subplot axes handle
        src_plot                % Source waveform plot handle
        obs_plot                % Observer waveform plot handle
                         
    end
    
    methods (Access = private)

        %% Source Position & Observed Frequency Update

        % This function updates the observed frequency using an estimate of the observed period 
        % based on time resolution and an estimate of the wavelength 
        % (i.e. the distance between two subsequent wavefronts)
        function observeFrequency(app)
            
            % Update observed period estimate
            app.Te = app.Te + app.dt;

            % If observevd period estimate is greater than the observed period + 10dt           
            if(app.Te > 1/app.f + 10 * app.dt)

                % Reset observed frequency 
                app.f = 0; 
                
                % Reset observed period estimate
                app.Te = 0; 

            end           
            
            % Loop over the wavefronts buffer to estimate observed frequency
            for i = 2 : app.wavefronts_num

                % Calculate wavefront distance
                d = app.wavefronts(i-1).x0 - app.wavefronts(i-1).r;

                % If the wavefront has reached the observer and has not been observed yet
                if(d <= app.obs.XData && app.wavefronts(i-1).obs ~= 1)

                    % Calculate distance of the next wavefront
                    d_next = app.wavefronts(i).x0 - app.wavefronts(i).r;

                    % If the next wavefront has also reached the observer and has not been observed yet
                    if(d_next <= app.obs.XData  && app.wavefronts(i).obs ~= 1)

                        % Calculate wavelength
                        lambda = d_next - d;

                        % Calculate observed frequency using the speed of
                        % the wave (c) and the wavelength (lambda)
                        app.f = round(app.c/lambda, 2);

                        % The first wavefront has been observed
                        app.wavefronts(i-1).obs = 1 ;

                        % Reset observed period estimate
                        app.Te = 0;

                    end
                end                
            end
        end

        % This function updates the position of the source by calculating
        % the distance traveled within the time resolution given the source's velocity
        % (position = position + vs * dt)
        function updateSourcePosition(app)

            % Update the position of the source using its velocity, current position, and time resolution            
            app.src.XData = app.src.XData + app.vs * app.dt;   

            % If the source is within the set boundaries of the simulation area or the observer
            if(app.src.XData < app.lim*app.obs_lim || app.src.XData > app.lim - (app.lim * app.sim_space_lim))    

                    % Invert source's direction by flipping velocity sign
                    app.vs = -app.vs; 

            end
        end
             
        %% Wavefronts Handling
        
        % This function initializes the wavefronts circular buffer
        function initWavefronts(app)

            % Allocate space for wavefronts_num wavefronts
            app.wavefronts(app.wavefronts_num) = struct();

            % Loop over the circular buffer to initialize each wavefront
            for i = 1:app.wavefronts_num

                % Set wavefront radius outside the visible boundaries
                app.wavefronts(i).r = 2*app.lim;

                % Set the x coordinate of the center 
                app.wavefronts(i).x0 = 0;

                % Set the y coordinate of the center 
                app.wavefronts(i).y0 = 0;

                % Set the wavefront as already observed
                app.wavefronts(i).obs = 1;

                % Calculate circle's parametric equation for the x component
                x = app.wavefronts(i).r * cos(app.theta); 

                % Calculate circle's parametric equation for the y component
                y = app.wavefronts(i).r * sin(app.theta);

                % Plot the waveform and save plot handle
                app.wavefronts(i).w = plot(app.ax, 0, 0, 'r');

                % Set plot XData to x
                app.wavefronts(i).w.XData = x;
                
                % Set plot YData to y
                app.wavefronts(i).w.YData = y;

            end
        end

        % This function is responsible for updating the wavefronts size
        % at each time interval. In other words it is responsible for 
        % animating the wavefronts
        function updateWavefronts(app) 
        
            % Loop over the wavefronts circular buffer
            for i = 1 : app.wavefronts_num  
                
                % Update the radius by calculating how much it should have
                % increased based on the time elapsed (dt) and the
                % propagation speed of the wave (c)
                app.wavefronts(i).r = app.wavefronts(i).r + app.c * app.dt;

                % Calculate updated circle's parametric equation for the x component
                x = app.wavefronts(i).r * cos(app.theta) + app.wavefronts(i).x0; 

                % Calculate updated circle's parametric equation for the y component
                y = app.wavefronts(i).r * sin(app.theta) + app.wavefronts(i).y0;

                % Update plot XData
                app.wavefronts(i).w.XData = x;

                % Update plot YData
                app.wavefronts(i).w.YData = y;
                      
            end          
        end

        % This function updates the wavefronts circular buffer by
        % resetting the oldest wavefront so that it can be propagated from
        % the source as a new wavefront
        function updateWavefrontsBuffer(app)

                % Calculate time elapsed within current period
                app.Tc = round(mod(app.Tc, app.T) , 2) + app.dt;      

                % If the time elapsed is, within a dt/10, tolerance equal to T
                if(abs(app.Tc - app.T) < app.dt / 10)     

                    % Update the wavefronts circular buffer index
                    app.w = mod(app.w, app.wavefronts_num) + 1;  

                    % Reset the w-th wavefront
                    app.resetWavefront(app.w)

                end
        end

        % This function is responsible for resetting the i-th wavefront,
        % positioning it in accordance to the source's position
        function resetWavefront(app, i) 

            % Reset wavefront's radius
            app.wavefronts(i).r = 0;

            % Set wavefront's center x coordinate to source's x coordinate
            app.wavefronts(i).x0 = app.src.XData;

            % Set wavefront's center y coordinate to source's y coordinate
            app.wavefronts(i).y0 = app.src.YData;

            % Set the wavefront as not observed yet
            app.wavefronts(i).obs = 0;    

        end
                
        %% GUI Setup & Update

        function setupVisualizationWindow(app)
                        
            % Create and setup figure for the Visualization Window
            app.fig = figure('NumberTitle', 'off', 'Name', 'Doppler Effect Simulator - Visualization Window');  
            set(app.fig, 'CloseRequestFcn',  @(~, ~)app.cleanUp());
            set(app.fig, 'Toolbar', 'none', 'Menubar', 'none','Color', 'white');
            app.fig.Position = [300 300 860 400];

            % Create and setup subplot for source frequency
            subplot(2,2,2,'Parent', app.fig)
            app.src_ax = gca;
            app.src_ax.Position = [0.50 0.60 0.48 0.27];
            app.src_plot = plot(app.src_ax, app.t, sin(2*pi*app.f0*app.t), 'Color', 'green');          
            axis([0 1 -1.5 1.5])
            xlabel('Time')
            ylabel('Amplitude')
            grid on
            
            % Create and setup subplot for observed frequency
            subplot(2,2,4,'Parent', app.fig)               
            app.obs_ax = gca;
            app.obs_ax.Position = [0.50 0.125 0.48 0.27];
            app.obs_plot = plot(app.t, sin(2*pi*0*app.t), 'Color', 'blue');     
            axis([0 1 -1.5 1.5])
            xlabel('Time')
            ylabel('Amplitude')
            grid on
        
            % Create and setup subplot for simulation space
            subplot(2,2,[1 3], 'Parent', app.fig)          
            app.ax = gca;
            app.ax.Position = [-0.12 0.12 0.75 0.75];          
            app.src = plot(app.ax, app.lim/2, app.lim/2, 'o', 'MarkerFaceColor','green', 'MarkerEdgeColor', 'black', 'MarkerSize', 10);            
            hold on
            app.obs = plot(app.ax, app.lim*0.1, app.lim/2, 'o', 'MarkerFaceColor','blue', 'MarkerEdgeColor', 'black', 'MarkerSize', 10);
            legend(app.ax,'Source', 'Observer', 'AutoUpdate', 'off', 'Location', 'southeast');
            title(app.ax, {'Simulation', ''})                 
            xlabel('Meters')
            ylabel('Meters')     
            axis([0 app.lim 0 app.lim])
            app.ax.FontSize = 8;
            xticks(0:500:2000);   
            yticks(0:500:2000);  
            axis square
            grid on
                       
        end

        % This function is responsible for plotting source and observed
        % frequencies over time according to the sample span
        function plotWaveforms(app)

            % Calculate current sample display range
            app.span = mod(app.span, length(app.t) - 1) + (length(app.t) - 1) / 20;

            % Plot source frequency over time 
            set(app.obs_plot, 'XData', app.t(1:app.span), 'YData', sin(2*pi*app.f*app.t(1:app.span)), 'LineWidth', 1.5)
            set(app.obs_ax.Title, 'string', {['Observed Frequency: ' sprintf('%.2f', app.f) ' Hz'], ''})  

            % Plot observed frequency over time
            set(app.src_plot, 'XData', app.t(1:app.span), 'YData', sin(2*pi*app.f0*app.t(1:app.span)), 'LineWidth', 1.5)
            set(app.src_ax.Title, 'string', {['Source Frequency: ' sprintf('%.2f', app.f0) ' Hz'], ''})       

        end

        % This function is responsible for updating the speedometer and
        % machmeter
        function updateGauges(app)

            % Update machmeter
            app.machmeter.Value = app.mach_num;
            app.machmeterLabel.Text = sprintf('Mach Number: %.02f \n (Wave Speed: %d m/s)',app.mach_num, app.c);

            % Update speedometer
            app.speedometer.Value = abs(app.vs);
            app.speedometerLabel.Text = sprintf('Speed: %.02f m/s \n ', abs(app.vs));

        end

        % This function is responsible for checking if the execution time
        % is within the time resolution
        function canKeepUp(app)

            % If time resolution (dt) - execution time (toc) is negative
            if(app.dt - toc < 0)

                % Warn the user that the simulation can't be run correctly
                % at the current time resolution by blinking the indicator red
                if(app.blink == 0)
                    app.StatusLamp.Color = [0.5 0.5 0.5];
                    app.blink = 1;
                else
                    app.StatusLamp.Color = 'red';
                    app.blink = 0;
                end

            % If time resolution (dt) - execution time (toc) is positive
            else

                % Inform the user that the simulation is running correctly
                % by blinking the indicator green
                if(app.blink == 0)
                    app.StatusLamp.Color = [0.5 0.5 0.5];
                    app.blink = 1;
                else
                    app.StatusLamp.Color = 'green';
                    app.blink = 0;
                end

            end

        end
        
    end

    methods (Static)

        %% Utilities  

        % This function is responsible for retrieving and deleting all
        % figures on app closure
        function cleanUp()        

            % Retrieve all figures handles
            figs = findall(0, 'Type', 'figure');

            % Delete associated figures
            delete(figs);

        end
        
        % This function is responsible for rounding the provided input to
        % match the current time resolution. It is used mainly for period
        % (T, Tc, Te) calculations.
        function num = roundToResolution(num)      

            % Multiply number by 10
            num = num * 10;

            % Calculate integer part
            int_part = floor(num);

            % Calculate decimal part
            dec_part = num - int_part;

            % If decimal part is less than 0.25
            if(dec_part < 0.25)

                % Set decimal part to zero
                dec_part = 0;

            % If decimal part is greater than or equal to 0.75
            elseif(dec_part >= 0.75)

                % Set decimal part to zero
                dec_part = 0;

                % Add one to the integer part
                int_part = int_part + 1;
            
            % If decimal part is less than 0.75 and greater then or equal to 0.25
            else

                % Set decimal part to 0.5
                dec_part = 0.5;

            end 

            % Calculate rounded number
            num = (int_part + dec_part) / 10; 

        end

    end


    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
         
            % Setup Visualization Windows
            app.setupVisualizationWindow();

            % Initialize wavefronts circular buffer
            app.initWavefronts();

            % While the app is running
            while isvalid(app)

                % Start timer
                tic          

                % Update source position according to its velocity
                app.updateSourcePosition();                

                % Animate wavefronts
                app.updateWavefronts();

                % Periodically reset the oldest wave to create a new one
                app.updateWavefrontsBuffer();

                % Calculate observed frequency
                app.observeFrequency();

                % Plot source and observed frequency over time
                app.plotWaveforms();

                % Update speedometer and machmeter
                app.updateGauges();               

                % Check if the simulation is running within timing
                % constraints
                app.canKeepUp();

                % Pause for a total of dt - execution time (toc) second to
                % obtain an overall execution time equal to dt seconds
                pause(app.dt-  toc);   

            end     

            % When app is closed execute clean up operations
            app.cleanUp()            
            
        end

        % Value changed function: speedKnob
        function speedKnobValueChanged(app, event)
            
            % Get rounded speed value
            app.vs = app.roundToResolution(round(event.Value, 2));

            % Update mach number
            app.mach_num = abs(app.vs)/app.c;   

        end

        % Value changed function: frequencyKnob
        function frequencyKnobValueChanged(app, event)
            
            % Get rounded source frequency value
            value = round(event.Value, 2); 

            % If value is zero
            if(value == 0)

                % Set source period to zero
                app.T = 0;

                % Set source frequency to zero
                app.f0 = 0;

            % If value is not zero  
            else  

                % Update source period with its rounded approximation
                app.T = app.roundToResolution(1/value);

                % Calculate corresponding source frequency
                app.f0 = round(1/app.T, 2);

            end
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create Figure and hide until all components are created
            app.Figure = uifigure('Visible', 'off');
            app.Figure.Color = [0.8 0.8 0.8];
            app.Figure.Position = [1180 300 312 400];
            app.Figure.Name = 'Doppler Effect Simulator';
            app.Figure.WindowStyle = 'alwaysontop';

            % Create controlsPanel
            app.controlsPanel = uipanel(app.Figure);
            app.controlsPanel.BorderColor = [0.902 0.902 0.902];
            app.controlsPanel.ForegroundColor = [0.149 0.149 0.149];
            app.controlsPanel.BorderWidth = 2;
            app.controlsPanel.BackgroundColor = [0.9412 0.9412 0.9412];
            app.controlsPanel.Position = [12 12 140 378];

            % Create frequencyKnobLabel
            app.frequencyKnobLabel = uilabel(app.controlsPanel);
            app.frequencyKnobLabel.HorizontalAlignment = 'center';
            app.frequencyKnobLabel.FontSize = 10;
            app.frequencyKnobLabel.Position = [16 194 108 22];
            app.frequencyKnobLabel.Text = 'Source Frequency (Hz)';

            % Create frequencyKnob
            app.frequencyKnob = uiknob(app.controlsPanel, 'continuous');
            app.frequencyKnob.Limits = [0 5];
            app.frequencyKnob.MajorTicks = [0 1 2 3 4 5];
            app.frequencyKnob.ValueChangedFcn = createCallbackFcn(app, @frequencyKnobValueChanged, true);
            app.frequencyKnob.FontSize = 10;
            app.frequencyKnob.Position = [39 240 60 60];

            % Create speedKnobLabel
            app.speedKnobLabel = uilabel(app.controlsPanel);
            app.speedKnobLabel.HorizontalAlignment = 'center';
            app.speedKnobLabel.FontSize = 10;
            app.speedKnobLabel.Position = [23 50 94 22];
            app.speedKnobLabel.Text = 'Source Speed (m/s)';

            % Create speedKnob
            app.speedKnob = uiknob(app.controlsPanel, 'continuous');
            app.speedKnob.Limits = [0 500];
            app.speedKnob.MajorTicks = [0 100 200 300 400 500];
            app.speedKnob.ValueChangedFcn = createCallbackFcn(app, @speedKnobValueChanged, true);
            app.speedKnob.FontSize = 10;
            app.speedKnob.Position = [39 92 60 60];

            % Create SourceControlsLabel
            app.SourceControlsLabel = uilabel(app.controlsPanel);
            app.SourceControlsLabel.FontWeight = 'bold';
            app.SourceControlsLabel.Position = [24 342 98 22];
            app.SourceControlsLabel.Text = 'Source Controls';

            % Create StatusLamp
            app.StatusLamp = uilamp(app.controlsPanel);
            app.StatusLamp.Position = [59 17 20 20];

            % Create metersPanel
            app.metersPanel = uipanel(app.Figure);
            app.metersPanel.BorderColor = [0.902 0.902 0.902];
            app.metersPanel.BorderWidth = 2;
            app.metersPanel.BackgroundColor = [0.9412 0.9412 0.9412];
            app.metersPanel.Position = [162 12 140 378];

            % Create SourceMetersLabel
            app.SourceMetersLabel = uilabel(app.metersPanel);
            app.SourceMetersLabel.FontWeight = 'bold';
            app.SourceMetersLabel.Position = [25 342 88 22];
            app.SourceMetersLabel.Text = 'Source Meters';

            % Create machmeterLabel
            app.machmeterLabel = uilabel(app.metersPanel);
            app.machmeterLabel.HorizontalAlignment = 'center';
            app.machmeterLabel.FontSize = 10;
            app.machmeterLabel.FontColor = [0.149 0.149 0.149];
            app.machmeterLabel.Position = [15 37 110 25];
            app.machmeterLabel.Text = {'Mach Number: 0.00'; '(Wave Speed: 343 m/s)'};

            % Create machmeter
            app.machmeter = uigauge(app.metersPanel, 'circular');
            app.machmeter.Limits = [0 1.5];
            app.machmeter.ScaleColors = [0.3922 0.8314 0.0745;1 1 0.0667;1 0.4118 0.1608];
            app.machmeter.ScaleColorLimits = [0 0.7;0.7 1;1 1.5];
            app.machmeter.FontSize = 10;
            app.machmeter.FontColor = [0.149 0.149 0.149];
            app.machmeter.Position = [15 70 110 110];

            % Create speedometerLabel
            app.speedometerLabel = uilabel(app.metersPanel);
            app.speedometerLabel.HorizontalAlignment = 'center';
            app.speedometerLabel.FontSize = 10;
            app.speedometerLabel.FontColor = [0.149 0.149 0.149];
            app.speedometerLabel.Position = [15 182 110 25];
            app.speedometerLabel.Text = {'Speed: 0.00 m/s'; ' '};

            % Create speedometer
            app.speedometer = uigauge(app.metersPanel, 'circular');
            app.speedometer.Limits = [0 500];
            app.speedometer.MajorTicks = [0 100 200 300 400 500];
            app.speedometer.ScaleColors = [0.3922 0.8314 0.0745;1 1 0.0667;1 0.4118 0.1608];
            app.speedometer.ScaleColorLimits = [0 243;243 343;343 500];
            app.speedometer.FontSize = 10;
            app.speedometer.FontColor = [0.149 0.149 0.149];
            app.speedometer.Position = [15 217 110 110];

            % Show the figure after all components are created
            app.Figure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = DopplerEffectSimulator

            runningApp = getRunningApp(app);

            % Check for running singleton app
            if isempty(runningApp)

                % Create UIFigure and components
                createComponents(app)

                % Register the app with App Designer
                registerApp(app, app.Figure)

                % Execute the startup function
                runStartupFcn(app, @startupFcn)
            else

                % Focus the running singleton app
                figure(runningApp.Figure)

                app = runningApp;
            end

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.Figure)
        end
    end
end
