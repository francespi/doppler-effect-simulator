%   Copyright (C) 2023 Francesco Pizzo
%
%   This program is free software; you can redistribute it and/or modify
%   it under the terms of the GNU General Public License as published by
%   the Free Software Foundation; either version 3 of the License, or
%   (at your option) any later version.

%   This program is distributed in the hope that it will be useful,
%   but WITHOUT ANY WARRANTY; without even the implied warranty of
%   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%   GNU General Public License for more details.

classdef DopplerEffectSimulator < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        Figure                          matlab.ui.Figure
        Display                         matlab.ui.control.TextArea
        StatusLED                       matlab.ui.control.Lamp
        DopplerEffectSimulatorv10Label  matlab.ui.control.Label
        ColorModeSwitch                 matlab.ui.control.Switch
        SimulationControlsPanel         matlab.ui.container.Panel
        FrequencyKnob                   matlab.ui.control.Knob
        FrequencyKnobLabel              matlab.ui.control.Label
        SpeedKnob                       matlab.ui.control.Knob
        SpeedKnobLabel                  matlab.ui.control.Label
        SimulationLabel                 matlab.ui.control.Label
        DisplayControlsPanel            matlab.ui.container.Panel
        DisplayLabel                    matlab.ui.control.Label
        BacklightKnob                   matlab.ui.control.Knob
        BacklightKnobLabel              matlab.ui.control.Label
        TextSizeKnob                    matlab.ui.control.Knob
        TextSizeKnobLabel               matlab.ui.control.Label
    end

    
    properties (Access = private)
        
        %% Simulation primary parameters

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
        sim_space_lim = 0.1;    % Source-Simulation Space distance boundary        
       
        %% Simulation secondary parameters

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

        % This function is responsible for Visualization Windows
        % initialization
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

        % This function is responsible for switching between light and dark
        % color modes
        function switchColorMode(app)
            
            % If the switch 'ColorModeSwitch' is set to 'on' switch to light color
            % scheme, otherwise switch to dark color scheme
            if(isequal('on', app.ColorModeSwitch.Value))
                primaryColor = 'black';
                secondaryColor = 'white';
                wavefrontsColor = 'red';
                obsColor = 'blue';
            else
                primaryColor = 'white';
                secondaryColor = [0.38 0.38 0.38];
                wavefrontsColor = 'cyan';
                obsColor = 'magenta';
            end
            
            % Set figure 'fig' and axes 'ax' colors
            app.fig.Color = secondaryColor;
            app.ax.XColor = primaryColor;
            app.ax.YColor = primaryColor;
            app.ax.Color = secondaryColor;
            app.ax.Title.Color = primaryColor;
            app.ax.Legend.Color = secondaryColor;
            app.ax.Legend.EdgeColor = primaryColor;            
            app.ax.Legend.TextColor = primaryColor;
                      
            % Set 'src_ax' axes colors
            app.src_ax.XColor = primaryColor;
            app.src_ax.YColor = primaryColor;
            app.src_ax.Color = secondaryColor;
            app.src_ax.Title.Color=primaryColor;
         
            % Set 'obs_ax' axes colors
            app.obs_ax.XColor = primaryColor;
            app.obs_ax.YColor = primaryColor;
            app.obs_ax.Color = secondaryColor;
            app.obs_ax.Title.Color=primaryColor;

            % Set source and observer colors
            app.obs_plot.Color = obsColor;
            app.obs.MarkerFaceColor=obsColor;         
            app.obs.MarkerEdgeColor=primaryColor;  
            app.src.MarkerEdgeColor=primaryColor;

            % Set wavefronts color
            for i = 1: app.wavefronts_num
                app.wavefronts(i).w.Color=wavefrontsColor;
            end

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

        % This function is responsible for updating the display with
        % current simulation data
        function updateDisplay(app)

                d = app.src.XData - app.obs.XData ;
                app.Display.Value = ...
                sprintf(['Src Speed: %.02f m/s \nSrc Wave Speed: %d m/s\n' ...
                         'Src Mach Number: %.02f\nSrc Distance: %.02f\n' ...
                         'Src Frequency: %.02f Hz\nObs Frequency: %.02f Hz' ...
                        ], abs(app.vs), app.c, app.mach_num,d,  app.f0,app.f);

        end

        % This function is responsible for checking if the execution time
        % is within the time resolution
        function canKeepUp(app)

            % If time resolution (dt) - execution time (toc) is negative
            if(app.dt - toc < 0)

                % Warn the user that the simulation can't be run correctly
                % at the current time resolution by blinking the indicator
                % red
                if(app.blink == 0)
                    app.StatusLED.Color = [0.5 0.5 0.5];
                    app.blink = 1;
                else
                    app.StatusLED.Color = 'red';
                    app.blink = 0;
                end

            % If time resolution (dt) - execution time (toc) is positive
            else

                % Inform the user that the simulation is running correctly
                % by blinking the indicator green
                if(app.blink == 0)
                    app.StatusLED.Color = [0.5 0.5 0.5];
                    app.blink = 1;
                else
                    app.StatusLED.Color = 'green';
                    app.blink = 0;
                end

            end

        end
        
    end

    methods (Static, Access = private)

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

            % Set default Visualization Window color mode
            app.switchColorMode();

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
                app.updateDisplay();        

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

        % Value changed function: SpeedKnob
        function SpeedKnobValueChanged(app, event)
            
            % Get rounded speed value
            app.vs = app.roundToResolution(round(event.Value, 2));

            % Update mach number
            app.mach_num = abs(app.vs)/app.c;   

        end

        % Value changed function: FrequencyKnob
        function FrequencyKnobValueChanged(app, event)
            
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

        % Value changed function: BacklightKnob
        function BacklightKnobValueChanged(app, event)
            
            % Assign 1/10 of knob value to variable 'value'
            value = app.BacklightKnob.Value/25;
            value = value/10;

            % Set background color wrt 'value'
            app.Display.BackgroundColor = [0.8-value 0.8+value 0.75-4*value];

        end

        % Value changed function: TextSizeKnob
        function TextSizeKnobValueChanged(app, event)
            
            % Assign knob value to variable 'value'
            value = app.TextSizeKnob.Value*0.8;

            % Set font size to 10 + 'value'
            app.Display.FontSize = 10 + value;

        end

        % Value changed function: ColorModeSwitch
        function ColorModeSwitchValueChanged(app, event)
           
            % Switch color mode when the switch 'ColorModeSwitch' commutes
            app.switchColorMode();

        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create Figure and hide until all components are created
            app.Figure = uifigure('Visible', 'off');
            app.Figure.Color = [0.3804 0.3804 0.3804];
            app.Figure.Position = [1180 300 230 400];
            app.Figure.Name = 'Doppler Effect Simulator';
            app.Figure.WindowStyle = 'alwaysontop';

            % Create DisplayControlsPanel
            app.DisplayControlsPanel = uipanel(app.Figure);
            app.DisplayControlsPanel.BorderColor = [0.502 0.502 0.502];
            app.DisplayControlsPanel.ForegroundColor = [0.502 0.502 0.502];
            app.DisplayControlsPanel.BorderWidth = 2;
            app.DisplayControlsPanel.BackgroundColor = [0.3804 0.3804 0.3804];
            app.DisplayControlsPanel.Position = [131 13 90 230];

            % Create TextSizeKnobLabel
            app.TextSizeKnobLabel = uilabel(app.DisplayControlsPanel);
            app.TextSizeKnobLabel.HorizontalAlignment = 'center';
            app.TextSizeKnobLabel.FontSize = 10;
            app.TextSizeKnobLabel.FontColor = [1 1 1];
            app.TextSizeKnobLabel.Position = [22 10 46 22];
            app.TextSizeKnobLabel.Text = 'Text Size';

            % Create TextSizeKnob
            app.TextSizeKnob = uiknob(app.DisplayControlsPanel, 'continuous');
            app.TextSizeKnob.Limits = [0 5];
            app.TextSizeKnob.ValueChangedFcn = createCallbackFcn(app, @TextSizeKnobValueChanged, true);
            app.TextSizeKnob.FontSize = 10;
            app.TextSizeKnob.FontColor = [1 1 1];
            app.TextSizeKnob.Position = [25 45 40 40];

            % Create BacklightKnobLabel
            app.BacklightKnobLabel = uilabel(app.DisplayControlsPanel);
            app.BacklightKnobLabel.HorizontalAlignment = 'center';
            app.BacklightKnobLabel.FontSize = 10;
            app.BacklightKnobLabel.FontColor = [1 1 1];
            app.BacklightKnobLabel.Position = [22 107 46 22];
            app.BacklightKnobLabel.Text = 'Backlight';

            % Create BacklightKnob
            app.BacklightKnob = uiknob(app.DisplayControlsPanel, 'continuous');
            app.BacklightKnob.Limits = [0 5];
            app.BacklightKnob.MajorTicks = [0 1 2 3 4 5];
            app.BacklightKnob.ValueChangedFcn = createCallbackFcn(app, @BacklightKnobValueChanged, true);
            app.BacklightKnob.FontSize = 10;
            app.BacklightKnob.FontColor = [1 1 1];
            app.BacklightKnob.Position = [25 142 40 40];

            % Create DisplayLabel
            app.DisplayLabel = uilabel(app.DisplayControlsPanel);
            app.DisplayLabel.HorizontalAlignment = 'center';
            app.DisplayLabel.FontSize = 10;
            app.DisplayLabel.FontWeight = 'bold';
            app.DisplayLabel.FontColor = [1 1 1];
            app.DisplayLabel.Position = [23 206 41 22];
            app.DisplayLabel.Text = 'Display';

            % Create SimulationControlsPanel
            app.SimulationControlsPanel = uipanel(app.Figure);
            app.SimulationControlsPanel.BorderColor = [0.502 0.502 0.502];
            app.SimulationControlsPanel.ForegroundColor = [0.149 0.149 0.149];
            app.SimulationControlsPanel.BorderWidth = 3;
            app.SimulationControlsPanel.TitlePosition = 'centertop';
            app.SimulationControlsPanel.BackgroundColor = [0.8 0.8 0.8];
            app.SimulationControlsPanel.Position = [11 13 110 230];

            % Create SimulationLabel
            app.SimulationLabel = uilabel(app.SimulationControlsPanel);
            app.SimulationLabel.HorizontalAlignment = 'center';
            app.SimulationLabel.FontSize = 10;
            app.SimulationLabel.FontWeight = 'bold';
            app.SimulationLabel.FontColor = [0.149 0.149 0.149];
            app.SimulationLabel.Position = [24 205 56 22];
            app.SimulationLabel.Text = 'Simulation';

            % Create SpeedKnobLabel
            app.SpeedKnobLabel = uilabel(app.SimulationControlsPanel);
            app.SpeedKnobLabel.HorizontalAlignment = 'center';
            app.SpeedKnobLabel.FontSize = 10;
            app.SpeedKnobLabel.FontColor = [0.149 0.149 0.149];
            app.SpeedKnobLabel.Position = [14 10 77 22];
            app.SpeedKnobLabel.Text = 'Src Speed (m/s)';

            % Create SpeedKnob
            app.SpeedKnob = uiknob(app.SimulationControlsPanel, 'continuous');
            app.SpeedKnob.Limits = [0 500];
            app.SpeedKnob.MajorTicks = [0 100 200 300 400 500];
            app.SpeedKnob.ValueChangedFcn = createCallbackFcn(app, @SpeedKnobValueChanged, true);
            app.SpeedKnob.FontSize = 10;
            app.SpeedKnob.FontColor = [0.149 0.149 0.149];
            app.SpeedKnob.Position = [33 45 40 40];

            % Create FrequencyKnobLabel
            app.FrequencyKnobLabel = uilabel(app.SimulationControlsPanel);
            app.FrequencyKnobLabel.HorizontalAlignment = 'center';
            app.FrequencyKnobLabel.FontSize = 10;
            app.FrequencyKnobLabel.FontColor = [0.149 0.149 0.149];
            app.FrequencyKnobLabel.Position = [9 107 92 22];
            app.FrequencyKnobLabel.Text = 'Src Frequency (Hz)';

            % Create FrequencyKnob
            app.FrequencyKnob = uiknob(app.SimulationControlsPanel, 'continuous');
            app.FrequencyKnob.Limits = [0 5];
            app.FrequencyKnob.MajorTicks = [0 1 2 3 4 5];
            app.FrequencyKnob.ValueChangedFcn = createCallbackFcn(app, @FrequencyKnobValueChanged, true);
            app.FrequencyKnob.FontSize = 10;
            app.FrequencyKnob.FontColor = [0.149 0.149 0.149];
            app.FrequencyKnob.Position = [34 142 40 40];

            % Create ColorModeSwitch
            app.ColorModeSwitch = uiswitch(app.Figure, 'slider');
            app.ColorModeSwitch.Items = {' ', ' '};
            app.ColorModeSwitch.ItemsData = {'off', 'on'};
            app.ColorModeSwitch.ValueChangedFcn = createCallbackFcn(app, @ColorModeSwitchValueChanged, true);
            app.ColorModeSwitch.FontColor = [1 1 1];
            app.ColorModeSwitch.Position = [176 374 23 10];
            app.ColorModeSwitch.Value = 'off';

            % Create DopplerEffectSimulatorv10Label
            app.DopplerEffectSimulatorv10Label = uilabel(app.Figure);
            app.DopplerEffectSimulatorv10Label.FontSize = 10;
            app.DopplerEffectSimulatorv10Label.FontWeight = 'bold';
            app.DopplerEffectSimulatorv10Label.FontColor = [0.8 0.8 0.8];
            app.DopplerEffectSimulatorv10Label.Position = [11 368 144 22];
            app.DopplerEffectSimulatorv10Label.Text = 'Doppler Effect Simulator v1.0';

            % Create StatusLED
            app.StatusLED = uilamp(app.Figure);
            app.StatusLED.Position = [209 374 10 10];

            % Create Display
            app.Display = uitextarea(app.Figure);
            app.Display.FontName = 'Consolas';
            app.Display.FontSize = 10;
            app.Display.FontColor = [0.149 0.149 0.149];
            app.Display.BackgroundColor = [0.8 0.8 0.749];
            app.Display.Position = [11 252 210 111];
            app.Display.Value = {'Text Area'};

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
