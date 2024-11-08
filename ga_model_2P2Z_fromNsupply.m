function varargout=ga_model_2P2Z_fromNsupply(Nsupply,varargin)


%% GA_MODEL_2P2Z_FROMNSUPPLY: plankton model used to model zooplankton hotspots
% Default parameters are based on copepods (Messi� & Chavez, 2017); 
% see l. 32 for default parameters based on krill (Messi� et al., 2022)
% 
% Use:
% [output=]ga_model_2P2Z_fromNsupply(Nsupply,varargin)
%
% output is a structure containing 
%	.time, .Nsupply, .P_small, .P_big, .Z_small, .Z_big, 
%	.Nnew, .Nreg, .Chl, .PP, .Cproduction, .u_small, .u_big, .g_small, .g_big, 
%	.units, .attributs
%
% Required input:
% 	Nsupply expressed in mmolC/m3/d, all units are carbon-based. Note - Nnew and Nreg represent new and regenerated nutrients, respectively
%		(NO3 and NH4 as a simplification) but are termed "Nnew" and "Nreg" to limit confusion with the unit, since they are expressed in carbon.
% 	Nsupply can be either a number, corresponding to the rate observed during upw_duration (default 1 day following Messi� & Chavez 2017)
%					or a vector (then time needs to be given), that provides Nsupply as a function of time along a current trajectory,
%					for instance (useful to take Ekman pumping into account)
%
% Optional inputs:
% 'nbdays_advec'	number of days during which the model is run
% 'dt'				time step
% 'time'			can replace nbdays_advec and dt (required if Nsupply is a vector)
% 'upw_duration'	number of days during which Nsupply happens (default 1 day, not used if Nsupply is a vector)
% 'plot'			displays the plankton model outputs as a function of time
%
% Examples of use:
% ga_model_2P2Z_fromNsupply(1.3/16*106,'plot')				to reproduce Fig. 2 in Messi� & Chavez 2017 (Nsupply = 1.3 mmolN/m3/d)
% ga_model_2P2Z_fromNsupply(11.2,'gmax_big',0.6*0.6,'eZ',0.1*0.6,'mZ',0.05*16/106*0.6,'plot')	to reproduce part of Fig. 1 in Messi� et al. (2022)
% 
% Monique Messi�, 2021 for public version
% Reference: Messi�, M., & Chavez, F. P. (2017). Nutrient supply, surface currents, and plankton dynamics predict zooplankton hotspots 
%					in coastal upwelling systems. Geophysical Research Letters, 44(17), 8979-8986, https://doi.org/10.1002/2017GL074322
% Differences with Messi� and Chavez (2017):
%		all Zsmall excretion is now availabe as regenerated nutrients (ie no Cproduction on Zsmall excretion)
%		Zbig grazing formulation is different with the half-saturation constant applying to Z_small+P_big in both cases


%% -------------- Default parameters (see Messi� & Chavez, 2017 suppl inf)


default_parameters={...
'umax_small',2,'umax_big',3,'gmax_small',1,'gmax_big',0.6,...	% maximum growth and grazing rates (d^{-1})
'cChl_small',200,'cChl_big',50,...								% C:Chl ratios for Psmall and Pbig (only used to calculate Chl) (gC/gChl)
'kNreg_small',0.5/16*106,...									% half-saturation constant for Psmall on NH4 (mmolC m^{-3})
'kNnew_big',0.75/16*106,...										% half-saturation constant for Pbig on NO3 (mmolC m^{-3})
'kG_small',1/16*106,...											% half-saturation constant for Zsmall on Psmall (mmolC m^{-3})
'kG_big',3/16*106,...											% half-saturation constant for Zbig on Pbig and Zsmall (mmolC m^{-3})
'mP',0,...														% Pbig mortality rate (default 0 ie no Pbig sinking) (d^{-1})
'mZ',0.05*16/106,...											% Zbig quadratic mortality rate (mmolC^{-1} m^{3} d^{-1})
'eZ',0.1,...													% zoo excretion rate (Zsmall and Zbig) (d^{-1})
'epsilon',0.25,...												% fraction of Zbig excretion that is available as regenerated nutrients
'P_small_ini',2,'P_big_ini',4,'Z_small_ini',1,'Z_big_ini',2};	% initial biomass (mmolC m^{-3})

[arg,flag]=ga_read_varargin(varargin,[{'nbdays_advec',60,'dt',0.2,'time',[],'upw_duration',1},default_parameters],{'plot'});
if length(Nsupply)>1 && isempty(arg.time), error('Give time if Nsupply is a vector'), end


%% -------------- Time

if isempty(arg.time), time=(0:arg.dt:arg.nbdays_advec)'; 
else, time=arg.time(:); arg.dt=time(2)-time(1); 
end
nb_time=length(time); 



%% -------------- Nsupply

if isscalar(Nsupply)
	Nsupply_max=Nsupply; 
	Nsupply=zeros(nb_time,1);
	Nsupply(time<arg.upw_duration)=Nsupply_max; 
end



%% -------------- Initial conditions


Nnew=time*NaN; 				% new nutrients (NO3 expressed in carbon) (mmolC m^{-3})
Nreg=time*NaN; 				% regenerated nutrients (NH4 expressed in carbon) (mmolC m^{-3})
P_small=time*NaN; 			% small phyto biomass (mmolC m^{-3})
P_big=time*NaN; 			% large phyto biomass (mmolC m^{-3})
Z_small=time*NaN; 			% small zoo biomass (mmolC m^{-3})
Z_big=time*NaN;				% large zoo biomass (mmolC m^{-3})
u_big=time*NaN; 			% P_big growth rate (Nnew-limited) (d^{-1})
u_small=time*NaN; 			% P_small growth rate (Nreg-limited) (d^{-1})
g_big=time*NaN; 			% Z_big grazing rate (P_big and Z_small limited) (d^{-1})
g_small=time*NaN;			% Z_small grazing rate (P_small limited) (d^{-1})
PP_big=time*NaN; 			% primary production for P_big (mmolC m^{-3} d^{-1})
PP_small=time*NaN; 			% primary production for P_small (mmolC m^{-3} d^{-1})
G_big1=time*NaN; 			% grazing from Z_big onto P_big (mmolC m^{-3} d^{-1})
G_big2=time*NaN; 			% grazing from Z_big onto Z_small (mmolC m^{-3} d^{-1})
G_small=time*NaN; 			% grazing from Z_small onto P_small (mmolC m^{-3} d^{-1})
excretion_Zbig=time*NaN; 	% Zbig excretion (mmolC m^{-3} d^{-1})
excretion_Zsmall=time*NaN; 	% Zsmall excretion (mmolC m^{-3} d^{-1})
death_Zbig=time*NaN; 		% Zbig mortality term (mmolC m^{-3} d^{-1})
death_Pbig=time*NaN; 		% Pbig mortality term (mmolC m^{-3} d^{-1})
regeneration_Nreg=time*NaN;	% nutrient regeneration (mmolC m^{-3} d^{-1})
P_small(1)=arg.P_small_ini; P_big(1)=arg.P_big_ini; Z_small(1)=arg.Z_small_ini; Z_big(1)=arg.Z_big_ini; 	
Nnew(1)=Nsupply(1)*arg.dt; Nreg(1)=0; 



%% -------------- Loop on time

for t=2:nb_time

	% growth and grazing rates
	u_big(t-1)=Nnew(t-1)/(arg.kNnew_big+Nnew(t-1))*arg.umax_big;
	u_small(t-1)=Nreg(t-1)/(arg.kNreg_small+Nreg(t-1))*arg.umax_small;
	g_big1=P_big(t-1)/(arg.kG_big+Z_small(t-1)+P_big(t-1))*arg.gmax_big; 	
	g_big2=Z_small(t-1)/(arg.kG_big+Z_small(t-1)+P_big(t-1))*arg.gmax_big;
	g_big(t-1)=g_big1+g_big2;
	g_small(t-1)=P_small(t-1)/(arg.kG_small+P_small(t-1))*arg.gmax_small;

	% fluxes
	PP_big(t)=u_big(t-1)*P_big(t-1); 
	PP_small(t)=u_small(t-1)*P_small(t-1); 
	G_big1(t)=g_big1*Z_big(t-1); 
	G_big2(t)=g_big2*Z_big(t-1); 
	G_small(t)=g_small(t-1)*Z_small(t-1);
	death_Zbig(t)=arg.mZ*Z_big(t-1)^2;
	death_Pbig(t)=arg.mP*P_big(t-1);
	excretion_Zbig(t)=arg.eZ*Z_big(t-1);
	excretion_Zsmall(t)=arg.eZ*Z_small(t-1);
	regeneration_Nreg(t)=arg.epsilon*excretion_Zbig(t)+excretion_Zsmall(t);	
	maxPP_big=(Nnew(t-1)+Nsupply(t)*arg.dt)/arg.dt; 
	maxPP_small=(Nreg(t-1)+regeneration_Nreg(t)*arg.dt)/arg.dt; 
	if PP_big(t)>maxPP_big, PP_big(t)=maxPP_big; end
	if PP_small(t)>maxPP_small, PP_small(t)=maxPP_small; end

	% carbon-based nutrients and biomass
	Nnew(t)=Nnew(t-1)+Nsupply(t)*arg.dt-PP_big(t)*arg.dt; 
	Nreg(t)=Nreg(t-1)+regeneration_Nreg(t)*arg.dt-PP_small(t)*arg.dt; 
	P_big(t)=P_big(t-1)+PP_big(t)*arg.dt-G_big1(t)*arg.dt-death_Pbig(t)*arg.dt; P_big(P_big<=0)=0;
	P_small(t)=P_small(t-1)+PP_small(t)*arg.dt-G_small(t)*arg.dt; P_small(P_small<=0)=0;
	Z_small(t)=Z_small(t-1)+G_small(t)*arg.dt-G_big2(t)*arg.dt-excretion_Zsmall(t)*arg.dt; Z_small(Z_small<=0)=0;
	Z_big(t)=Z_big(t-1)+G_big1(t)*arg.dt+G_big2(t)*arg.dt-excretion_Zbig(t)*arg.dt-death_Zbig(t)*arg.dt; Z_big(Z_big<=0)=0;

end
Cproduction=death_Pbig+(1-arg.epsilon)*excretion_Zbig;
% Note: in steady-state, Nsupply=death_Zbig+Cproduction


%% -------------- Ouputs

units=struct('time','days','Nsupply','mmolC m^{-3} d^{-1}',...
	'P_small','mmolC m^{-3}','P_big','mmolC m^{-3}','Z_small','mmolC m^{-3}','Z_big','mmolC m^{-3}',...
	'Nnew','mmolC m^{-3}','Nreg','mmolC m^{-3}','Chl','mg m^{-3}','PP','mgC m^{-3} d^{-1}',...
	'Cproduction','mgC m^{-3} d^{-1}',...
	'u_small','d^{-1}','u_big','d^{-1}','g_small','d^{-1}','g_big','d^{-1}');
output=struct('units',units,'time',time,'Nsupply',Nsupply,...
	'P_small',P_small,'P_big',P_big,'Z_small',Z_small,'Z_big',Z_big,'Nnew',Nnew,'Nreg',Nreg,...
	'Chl',P_small*12/arg.cChl_small+P_big*12./arg.cChl_big,'PP',(PP_big+PP_small)*12,...
	'Cproduction',Cproduction*12,...
	'u_small',u_small,'u_big',u_big,'g_small',g_small,'g_big',g_big,'attributs',struct('arg',arg));
varargout={output}; varargout=varargout(1:nargout);



%% -------------- Figures

if flag.plot

	figure, hold on
	plot(output.time,output.P_small,'LineWidth',2)
	plot(output.time,output.P_big,'LineWidth',2)
	plot(output.time,output.Z_small,'LineWidth',2)
	plot(output.time,output.Z_big,'LineWidth',2)
	ylabel(output.units.P_small)
	if min(output.time)>datenum(1900,1,1), datetick('x','keeplimits'), xlabel('Time')
	else, xlabel('Time (days)')
	end
	legend({'P\_small','P\_big','Z\_small','Z\_big'})
	title('Model output (plankon concentration over time)')

end



return




