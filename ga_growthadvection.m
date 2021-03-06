function zoo=ga_growthadvection(init,name_curr,time0,varargin)


%% GA_GROWTHADVECTION: runs the plankton model alongside Lagrangian trajectories for a given initialization (positions & Nsupply) and initial time
%
% Use:
% zoo=ga_growthadvection(init,name_curr,time0,varargin)
%
% Required inputs: 
%	init			structure containing .lon, .lat, .Nsupply (initialization position & Nsupply)
% 	name_curr		prefix of the current dataset to be used (netcdf files as generated by utils/ga_write_ariane_currents into dir_ariane_global/currents_data)
% 	time0			initialization time
%
% Optional inputs:
% 	dt						time step, (default 0.2 days)
%	nbdays_advec			trajectory duration (default 60 days)
%	options_plankton_model	as a cell, see ga_model_2P2Z_fromNsupply (default {})
%							for krill customisation, set options_plankton_model to {'gmax_big',0.6*0.6,'eZ',0.1*0.6,'mZ',0.05*16/106*0.6}
%
% For instance, to change nbdays_advec:
% 	zoo=ga_growthadvection(init,name_curr,time0,'nbdays_advec',100)
%
% Monique Messié, 2021 for public version
% Reference: Messié, M., D. A. Sancho-Gallegos, J. Fiechter, J. A. Santora, and F. P. Chavez (2022). 
%			Satellite-based Lagrangian model reveals how upwelling and oceanic circulation shape krill hotspots in the California Current System.
%			Frontiers in Marine Science, in press, https://doi.org/10.3389/fmars.2022.835813.

		
arg=ga_read_varargin(varargin,{'dt',0.2,'nbdays_advec',60,'options_plankton_model',{}});
if isempty(init.Nsupply), zoo=[]; return, end



%% --------------------------------------------------------------------------------- %%
%% 								PREPARE OUTPUTS										 %%
%% --------------------------------------------------------------------------------- %%


% output time vector
time=time0:arg.dt:(time0+arg.nbdays_advec);

% output zoo
plankton_model_outputs={'Chl','PP','Nnew','Nreg','P_small','P_big','Z_small','Z_big'}; 
zoo=struct();
zoo.lon_ini=init.lon;
zoo.lat_ini=init.lat;
zoo.Nsupply_ini=init.Nsupply;
zoo.time=time(:);
for varname=[{'lon2D','lat2D'},plankton_model_outputs], varname=varname{:};
	zoo.(varname)=nan(length(zoo.lat_ini),length(zoo.time));
end
zoo.units=struct();
zoo.units.Nsupply='mmolC/m3/d'; 



%% --------------------------------------------------------------------------------- %%
%% 									COMPUTE TRAJECTORIES							 %%
%% --------------------------------------------------------------------------------- %%


igood_lat=~isnan(zoo.Nsupply_ini); 
positions=ga_advection_ariane([zoo.lon_ini(igood_lat),zoo.lat_ini(igood_lat)],name_curr,'dt',arg.dt,'time0',time0,'nbdays_advec',arg.nbdays_advec); 
for varname={'lon2D','lat2D'}, varname=varname{:}; 
	zoo.(varname)(igood_lat,:)=positions.(varname); 
end



%% --------------------------------------------------------------------------------- %%
%% 										RUN PLANKTON MODEL							 %%
%% --------------------------------------------------------------------------------- %%


for ilat=1:length(zoo.lat_ini)
	if ~isnan(zoo.Nsupply_ini(ilat,1))
		output=ga_model_2P2Z_fromNsupply(zoo.Nsupply_ini(ilat,:),'time',zoo.time-zoo.time(1),arg.options_plankton_model{:}); 
		for varname=plankton_model_outputs, varname=varname{:}; 
			zoo.(varname)(ilat,:)=output.(varname); zoo.units.(varname)=output.units.(varname); 
		end
	end
end
		
				
return
		
		