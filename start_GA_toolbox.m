%% START_GA_TOOLBOX: examples to run the model
% Reference: Messié, M., D. A. Sancho-Gallegos, J. Fiechter, J. A. Santora, and F. P. Chavez (submitted). 
% 	Satellite-based Lagrangian model reveals how upwelling and oceanic circulation shape krill hotspots in the California Current System.
%	Frontiers in Marine Science




%% --------------------------------------------- Set up ----------------------------------------------- %%

% Set directory where Ariane is installed (used in most functions)
% There must be a directory "currents_data" inside dir_ariane_global where currents netcdf files are saved (see ga_write_ariane_currents)
global dir_ariane_global
dir_ariane_global='Ariane_workplace/';

% Set directory where outputs will be saved (used in ga_full_GArun)
global dir_output_global
dir_output_global='outputs/';

% Add needed utility functions. Remember to add the path where histcn is installed.
addpath('utils')

% Note - m_map can be used to visualize output maps (https://www.eoas.ubc.ca/~rich/map.html).



%% ------------------------------------- Run the plankton model --------------------------------------- %%

% Reproduce Fig. 2 in Messié & Chavez (2017), model parameterized based on copepods.
ga_model_2P2Z_fromNsupply(1.3/16*106,'plot')

% Display the model output behind Fig. 1a in Messié et al. (in prep), 
% changing gmax_big, eZ and mZ relative to the default values parameterizes the model for krill.
output=ga_model_2P2Z_fromNsupply(11.2,'gmax_big',0.6*0.6,'eZ',0.1*0.6,'mZ',0.05*16/106*0.6,'plot');
print('-djpeg','-r300','outputs/plankton_model.jpg')



%% ---------------------------------- Save currents into Ariane format ---------------------------------- %%

% See function ga_write_ariane_currents.m
% The directory Ariane_workplace/currents_data/ already contains daily California currents from GlobCurrents for March 1st to August 31st, 2008




%% ---- Compute positions over time using Ariane (example on 3 positions, starting on May 1st, 2008) ---- %%

% If ga_advection_ariane does not work, try first to run "ariane" from a terminal inside Ariane_workplace.
mat_positions_ini=[[-122 36];[-122 36.5];[-123 38]];
positions=ga_advection_ariane(mat_positions_ini,'toolbox','dt',0.1,'time0',datenum(2008,5,1),'nbdays_advec',60); 
time2D=repmat(positions.time',size(mat_positions_ini,1),1);
load('inputs/coastline_California.mat','coast_x','coast_y')	
figure, hold on
	scatter(positions.lon2D(:),positions.lat2D(:),30,time2D(:),'filled')
	plot(coast_x,coast_y,'k')
	xlim([-128 -120]), ylim([30 40])
	hbar=colorbar; datetick(hbar,'y','keeplimits')
	set(get(hbar,'title'),'string','time');
	xlabel('Longitude'), ylabel('Latitude')
	title('Current trajectories initialized on May 1st, 2008')
print('-djpeg','-r300','outputs/positions_start_20080501.jpg')



%% --------------------------- Compute one daily run starting on May 1st, 2008 --------------------------- %%
% Reproduces Fig. 1b

% Load inputs and set run date
load('inputs/Nsupply_2008.mat','Nsupply')						% load the Nsupply forcing for the 2008 season
load('inputs/coastline_California.mat','coast_x','coast_y')		% load the California coastline to compute original positions
options_plankton_model={'gmax_big',0.6*0.6,'eZ',0.1*0.6,'mZ',0.05*16/106*0.6};	% krill parameterization
name_curr='toolbox';											% using currents toolbox_* into Ariane_workplace/currents_data
time0=datenum(2008,5,1);	

% Construct init structure
init=struct();
init.Nsupply=nan(length(Nsupply.lat),1);
for ilat=1:length(Nsupply.lat), init.Nsupply(ilat)=interp1(Nsupply.time,Nsupply.Nsupply(ilat,:),time0); end
init.lat=Nsupply.lat; 
init.lon=nan(size(init.lat));
for ilat=1:length(init.lat)
	icoast=ga_find_index(coast_y,Nsupply.lat(ilat)); 
	init.lon(ilat)=min(interp1(1:length(coast_x),coast_x,icoast)); 
end

% Run the growth-advection program
zoo=ga_growthadvection(init,name_curr,time0,'options_plankton_model',options_plankton_model);

% Figure
% Note: pixels over land are due to current interpolation to the coast (so pixels overlay land). 
% The functions that concatenes daily runs to generate maps moves them over to the coastline again (see ga_concatene_runs)
figure, hold on
	scatter(flipud(zoo.lon2D(:)),flipud(zoo.lat2D(:)),5,flipud(zoo.Z_big(:)),'filled')
	plot(coast_x,coast_y,'k')
	xlim([-125.5 -120]), ylim([34 38])
	hbar=colorbar; caxis([0 20])
	set(get(hbar,'title'),'string',zoo.units.Z_big);
	xlabel('Longitude'), ylabel('Latitude')
	title('Z\_big from GA run initialized on May 1st, 2008')
print('-djpeg','-r300','outputs/GArun_start_20080501.jpg')



%% -------------- Run the full GA model for the 2008 upwelling season (krill parameterization) -------------- %%

% Load inputs and set run options
load('inputs/Nsupply_2008.mat','Nsupply')				% load the Nsupply forcing for the 2008 season (Nsupply.name = CCMP3km)
options_plankton_model={'gmax_big',0.6*0.6,'eZ',0.1*0.6,'mZ',0.05*16/106*0.6};	% krill parameterization
name_curr='toolbox';									% using currents toolbox_* into Ariane_workplace/currents_data

% Run the full GA model
ga_full_GArun(Nsupply,name_curr,'options_plankton_model',options_plankton_model)

% Look at outputs: example May 2008 (by default days are all at 15) - Reproduces Fig. 1c
% Note - positions are shifted for pcolor so that pixels are centered on the position (pcolor considers positions to be the bottom left corner)
load('outputs/zoo2D_CCMP3km_toolbox.mat')
load('inputs/coastline_California.mat','coast_x','coast_y')
itime=zoo2D.time==datenum(2008,5,15);
figure, hold on
pcolor(zoo2D.lon-0.125/2,zoo2D.lat-0.125/2,zoo2D.Z_big(:,:,itime)), shading flat
plot(coast_x,coast_y,'k')
xlim([-125.5 -120]), ylim([34 38])
hbar=colorbar; caxis([0 18])
set(get(hbar,'title'),'string',zoo2D.units.Z_big);
xlabel('Longitude'), ylabel('Latitude'), title('Z\_big mapped output, May 2008')
print('-djpeg','-r300','outputs/GAmap_monthly_200805.jpg')