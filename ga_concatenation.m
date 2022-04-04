function varargout=ga_concatenation(GArun_name,output_grid,variable_list)


%% GA_CONCATENATION(GArun_name): takes the daily Lagrangian outputs saved into dir_output_global (as calculated by ga_growthadvection)
% and use them to generate daily, then monthly maps (daily maps are just an intermediary product with no prediction value)
% Requires the histcn.m function available on Matlab Exchange (https://www.mathworks.com/matlabcentral/fileexchange/23897-n-dimensional-histogram)
%
% [zoo2D=]ga_concatenation(GArun_name,output_grid,variable_list);
%
% Inputs:
% GArun_name		name used to save the daily runs (as [dir_output_global,'zoo_Lagrangian_',GArun_name,'_',num2str(year),'.mat'])
% output_grid		structure containing .lon and .lat (grid on which Lagrangian runs will be mapped)
% variable_list		variables to incorporate into maps, by default only Z_big is kept
%
% Monique Messié, 2021 for public version


global dir_output_global
if nargin<3, variable_list={'Z_big'}; end
if nargin<2, output_grid=struct('lon',-135:0.125:-110,'lat',28:0.125:48); end		% California grid at 1/8° resolution
load('inputs/mask_California.mat','mask')										% needed to move over points over continent
dlat=mean(output_grid.lat(2:end)-output_grid.lat(1:end-1));							% grid resolution
dlon=mean(output_grid.lon(2:end)-output_grid.lon(1:end-1));

% adjust mask to output_grid (if using a different resolution)
[mask.lon2D,mask.lat2D]=meshgrid(mask.lon,mask.lat);
[output_grid.lon2D,output_grid.lat2D]=meshgrid(output_grid.lon,output_grid.lat);
output_grid.mask=interp2(mask.lon2D,mask.lat2D,double(mask.mask),output_grid.lon2D,output_grid.lat2D);
output_grid.mask=output_grid.mask==1;

% get years
list_filenames=ga_dir2filenames(dir_output_global,['zoo_Lagrangian_',GArun_name,'*.mat']);
is_correctGA=cellfun(@(x) ~isnan(str2double(x(length(['zoo_Lagrangian_',GArun_name,'_'])+1))), list_filenames);	% check if GArun_name is followed by _ then a number
list_filenames=list_filenames(is_correctGA);		% excluding files from potential other names starting with GArun_name
list_years=cellfun(@(x) str2double(x(length(GArun_name)+17:length(GArun_name)+20)), list_filenames);
list_years=list_years(~isnan(list_years));
if length(unique(list_years))~=length(list_years), error('years should be unique, to check'), end
if isempty(list_years), error('check GA name, no files found!'), end



%% Loop on years to concatene files and first regrid daily

disp('Concatene all individual runs and first regrid daily...')
for year=list_years, disp(' '), disp(['Year ',num2str(year),'.....'])

	% load current year and set up zoo2D_daily
	filename=ga_dir2filenames(dir_output_global,['zoo_Lagrangian_',GArun_name,'_',num2str(year),'*.mat']);
	load([dir_output_global,filename{:}],'zoo_all','time_all'); disp(['Runs year ',num2str(year),' loaded!'])
	if year==list_years(1)
		runlength=zoo_all{1}.time(end)-zoo_all{1}.time(1);
		time_daily=(floor(zoo_all{1}.time(1))+runlength:datenum(list_years(end),12,31))';		% only calculate maps when full runs are available
		zoo2D_daily=struct(); zoo2D_daily.units=struct();
		zoo2D_daily.lon=output_grid.lon; zoo2D_daily.lat=output_grid.lat; zoo2D_daily.time=time_daily; 
		[zoo2D_daily.year,~,~]=datevec(zoo2D_daily.time);
		for varname=variable_list, varname=varname{:};
			zoo2D_daily.(varname)=nan(length(zoo2D_daily.lat),length(zoo2D_daily.lon),length(zoo2D_daily.time));
			zoo2D_daily.units.(varname)=zoo_all{1}.units.(varname);
		end
	end

	% keep needed runs from previous year (starting up to runlength before)
	if year==list_years(1)
		zoo_Lagrangian=struct(); % zoo_Lagrangian is a structure that contains all relevant zoo_all outputs, reshaped as vectors
		for varname=[{'lon','lat','time'},variable_list], varname=varname{:}; zoo_Lagrangian.(varname)=[]; end
	else, ikeep=zoo_Lagrangian.time>=datenum(year,1,1)-runlength-1;
		for varname=fieldnames(zoo_Lagrangian)', varname=varname{:};
			zoo_Lagrangian.(varname)=zoo_Lagrangian.(varname)(ikeep);
		end
	end

	% concatene all individual runs needed for current year
	for itime=1:length(time_all)
		time2D=repmat(zoo_all{itime}.time',length(zoo_all{itime}.lat_ini),1);
		zoo_1run=struct();		% zoo_1run is a structure that takes the zoo_all{itime} 2D (time-lat) outputs and reshapes them as a vector
		zoo_1run.lon=zoo_all{itime}.lon2D(:); 
		zoo_1run.lat=zoo_all{itime}.lat2D(:); 
		zoo_1run.time=time2D(:);
		for varname=variable_list, varname=varname{:}; zoo_1run.(varname)=zoo_all{itime}.(varname)(:); end
		ikeep=~isnan(zoo_1run.lon) & zoo_1run.lon~=0;
		for varname=fieldnames(zoo_Lagrangian)', varname=varname{:};
			zoo_Lagrangian.(varname)=[zoo_Lagrangian.(varname);zoo_1run.(varname)(ikeep)];
		end
	end

	% adjust all points over continents to the coast (needed for coarser currents)
	for ilat=1:length(zoo2D_daily.lat)
		lat=zoo2D_daily.lat(ilat);
		ilat_zoo = zoo_Lagrangian.lat>=lat-dlat/2 & zoo_Lagrangian.lat<=lat+dlat/2;
		loncoast=max(output_grid.lon(output_grid.mask(ilat,:)));		% lon of last pixel before the coast
		zoo_Lagrangian.lon(ilat_zoo & zoo_Lagrangian.lon>loncoast)=loncoast;	
	end

	% regrid daily
	for itime_zoo2D_daily=find(zoo2D_daily.year==year)'		% loop on all days
		itime_day=floor(zoo_Lagrangian.time)==zoo2D_daily.time(itime_zoo2D_daily);	% get the zoo points that correspond to the current day
		if sum(itime_day)>0
			for varname=variable_list, varname=varname{:}; 
				iok = itime_day & ~isnan(zoo_Lagrangian.(varname));		% remove points at NaN that would set cause the corresponding mat2D pixel to be at NaN
				mat2D=histcn([zoo_Lagrangian.lat(iok),zoo_Lagrangian.lon(iok)],...
					zoo2D_daily.lat(1)-dlat/2:dlat:zoo2D_daily.lat(end)+dlat/2,zoo2D_daily.lon(1)-dlon/2:dlon:zoo2D_daily.lon(end)+dlon/2,...
					'AccumData',zoo_Lagrangian.(varname)(iok),'Fun',@mean); 
				hasdata=histcn([zoo_Lagrangian.lat(iok),zoo_Lagrangian.lon(iok)],...
					zoo2D_daily.lat(1)-dlat/2:dlat:zoo2D_daily.lat(end)+dlat/2,zoo2D_daily.lon(1)-dlon/2:dlon:zoo2D_daily.lon(end)+dlon/2)>0;
				mat2D(~hasdata)=NaN;
				zoo2D_daily.(varname)(:,:,itime_zoo2D_daily)=mat2D;
			end
		end
	end

end
disp('All years loaded!')



%% Finalize daily data and regrid monthly
disp('Finalize daily data and regrid monthly...')

% Set 0s wherever current trajectories didn't go, except over continents that stay at NaN
mask=min(isnan(zoo2D_daily.(variable_list{1})),[],3); 			% will be identical for all variables (same trajectories)
for varname=variable_list, varname=varname{:};
	zoo2D_daily.(varname)(isnan(zoo2D_daily.(varname)))=0;
	zoo2D_daily.(varname)(repmat(mask,1,1,length(zoo2D_daily.time)))=NaN;
end

% only retain region with data, and remove empty dates at the end (if the runs didn't exist for the full last year)
mask=max(~isnan(zoo2D_daily.Z_big),[],3);
ilat=max(mask,[],2); zoo2D_daily.lat=zoo2D_daily.lat(ilat);
ilon=max(mask,[],1); zoo2D_daily.lon=zoo2D_daily.lon(ilon);
itime=zoo2D_daily.time<max(time_all); zoo2D_daily.time=zoo2D_daily.time(itime);
for varname=variable_list, varname=varname{:};
	zoo2D_daily.(varname)=zoo2D_daily.(varname)(ilat,ilon,itime);
end

% ensure only complete months are kept
[~,~,d]=datevec(zoo2D_daily.time);
itime_keep=true(size(zoo2D_daily.time));
itime_keep(1:find(d==1,1,'first')-1)=false;						% remove first month if not full
if d(end)<28, itime_keep(find(d==1,1,'last'):end)=false; end	% remove last month if not full
zoo2D_daily.time=zoo2D_daily.time(itime_keep);
for varname=variable_list, varname=varname{:};
	zoo2D_daily.(varname)=zoo2D_daily.(varname)(:,:,itime_keep);
end
	
% compute monthly data
[y,m,~]=datevec(zoo2D_daily.time);
zoo2D=struct();
zoo2D.time=unique(datenum(y,m,15));
[ymonth,mmonth,~]=datevec(zoo2D.time);
for varname={'units','lon','lat'}, varname=varname{:}; zoo2D.(varname)=zoo2D_daily.(varname); end
for imonth=1:length(zoo2D.time)
	imonth_daily = y==ymonth(imonth) & m==mmonth(imonth);		% find the daily time steps belonging to the current month
	for varname=variable_list, varname=varname{:};
		zoo2D.(varname)(:,:,imonth)=mean(zoo2D_daily.(varname)(:,:,imonth_daily),3);
	end
end

% save the output
save([dir_output_global,'zoo2D_',GArun_name,'.mat'],'zoo2D','-v7.3')
varargout={zoo2D}; varargout=varargout(1:nargout);
disp('Done!')


return



