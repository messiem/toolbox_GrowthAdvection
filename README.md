# Toolbox GrowthAdvection

### Description

This toolbox contains the Matlab programs necessary to run the growth-advection method to predict zooplankton hotspots from nitrate supply in upwelling systems (https://www.mbari.org/science/upper-ocean-systems/biological-oceanography/krill-hotspots-in-the-california-current/).  
This work was primarily funded by NASA (80NSSC17K0574) with additional support from Horizon 2020 (Marie Skłodowska-Curie grant agreement SAPPHIRE No. 746530) and the David and Lucile Packard Foundation.  
Trajectories are computed using a custom 2D version of the Lagrangian computational tool Ariane (http://stockage.univ-brest.fr/~grima/Ariane/).  
The programs are written for Matlab running on Linux (because of Ariane).  
  
*Note - The same programs can be used to reproduce the growth-advection application to non-diazotroph / diazotroph succession and the delayed island mass effect described in Messié et al. (2020).*   
*If this application is of interest, please contact me and I will add the corresponding functions.*


### Pre-requisite

#### 1. Install Ariane

The toolbox uses a custom version of Ariane specifically designed for surface (2D) trajectories, used in previous studies (see references below).  
This version is available upon request to Nicolas Grima or Bruno Blanke (see section "Contact us" on the Ariane website http://stockage.univ-brest.fr/~grima/Ariane/).

Install packages `gfortran`, `libnetcdf-dev` and `libnetcdff-dev`.  
Check that `nc-config --has-fortran` returns yes.

In the Ariane directory obtained by unpacking the 2D Ariane installation file, run:  
(the directory location can be updated)  

	./configure --prefix=/home/$USER/Ariane/ARIANE
	make
	make check
	make install

Create a symbolic link to run Ariane anywhere:  

	sudo ln -s /home/$USER/Ariane/ARIANE/bin/ariane2D /usr/bin/ariane

#### 2. Download the histcn function from Matlab Exchange

https://www.mathworks.com/matlabcentral/fileexchange/23897-n-dimensional-histogram  
Add to the Matlab path (e.g., in `utils/`)


### Get started

For examples on how to run the toolbox, see script:  

	start_GA_toolbox

Description of main functions:  
`ga_full_GArun`: runs the entire GA method, by computing daily Lagrangian trajectories, running the plankton model alongside them, and concatenating the result into maps.  
`ga_concatenation` (called by ga_full_GArun): concatenates the Lagrangian runs computed by ga_growthadvection.  
`ga_growthadvection` (called by ga_full_GArun): runs a set of Lagrangian trajectories + plankton model for one day.  
`ga_advection_ariane` (called by ga_growthadvection): computes current trajectories.  
`ga_model_2P2Z_fromNsupply` (called by ga_growthadvection): runs the plankton model.  
Functions in `utils/` are called by the main functions; there shouldn't be a need to call them independently.  


Note - 2D outputs are available in the outputs/ folder; Lagrangian outputs are not uploaded (1.7GB) but available upon request.


### Description of data inputs available here for demonstration purposes
Near-surface currents for the California Current during March 1st - August 31st, 2008 (in `Ariane_workplace/currents_data/`):  
GlobCurrent total 15m currents downloaded from Copernicus, dataset ID MULTIOBS_GLO_PHY_REP_015_004  
https://resources.marine.copernicus.eu/?option=com_csw&view=details&product_id=MULTIOBS_GLO_PHY_REP_015_004  

Nitrate supply for the California Current at monthly 3km resolution in 2008 (in `inputs/`):  
Computed following Messié and Chavez (2015, see also https://www.mbari.org/science/upper-ocean-systems/biological-oceanography/nitrate-supply-estimates-in-upwelling-systems/),  
then converted into a volumetric flux following Messié and Chavez (2017), and regridded on a 3km latitude grid.  
Instead of QuikSCAT, winds were obtained from CCMP (http://data.remss.com/ccmp/v02.0/).

* * *

### References

#### Toolbox
Please refer this paper when using the toolbox (available upon request):  

Messié, M., D. A. Sancho-Gallegos, J. Fiechter, J. A. Santora, and F. P. Chavez (submitted). **Satellite-based Lagrangian model reveals how upwelling and oceanic circulation shape krill hotspots in the California Current System.**  
&nbsp; &nbsp; &nbsp; &nbsp; *Frontiers in Marine Science*.
  
#### Ariane
Please also refer to Ariane if using it to compute current trajectories:   

Blanke, B., and Raynaud, S. (1997). **Kinematics of the Pacific Equatorial Undercurrent: An Eulerian and Lagrangian approach from GCM results.**   
&nbsp; &nbsp; &nbsp; &nbsp; *Journal of Physical Oceanography*, 27(6), 1038-1053.
  
#### Growth-advection applications
Messié, M., and F. P. Chavez (2017). **Nutrient supply, surface currents, and plankton dynamics predict zooplankton hotspots in coastal upwelling systems.**  
&nbsp; &nbsp; &nbsp; &nbsp; *Geophysical Research Letters*, 44(17), 8979-8986, https://doi.org/10.1002/2017GL074322  
Messié, M., Petrenko, A., Doglioli, A. M., Aldebert, C., Martinez, E., Koenig, G., Bonnet, S., and Moutin, T. (2020). **The delayed island mass effect: How islands can remotely trigger blooms in the oligotrophic ocean.**  
&nbsp; &nbsp; &nbsp; &nbsp; *Geophysical Research Letters*, 47(2), e2019GL085282, https://doi.org/10.1029/2019GL085282 
  
#### Nitrate supply
Messié, M., and F. P. Chavez (2015). **Seasonal regulation of primary production in eastern boundary upwelling systems.**  
&nbsp; &nbsp; &nbsp; &nbsp; *Progress in Oceanography*, 134, 1-18, https://doi.org/10.1016/j.pocean.2014.10.011  
See https://www.mbari.org/science/upper-ocean-systems/biological-oceanography/nitrate-supply-estimates-in-upwelling-systems/  

#### 2D custom version of Ariane 

Dobler, D., Huck, T., Maes, C., Grima, N., Blanke, B., Martinez, E., and Ardhuin, F. (2019). **Large impact of Stokes drift on the fate of surface floating debris in the South Indian Basin.**   
&nbsp; &nbsp; &nbsp; &nbsp; *Marine pollution bulletin*, 148, 202-209, https://doi.org/10.1016/j.marpolbul.2019.07.057  
Maes, C., Grima, N., Blanke, B., Martinez, E., Paviet‐Salomon, T., and Huck, T. (2018). **A surface “superconvergence” pathway connecting the South Indian Ocean to the subtropical South Pacific gyre.**  
&nbsp; &nbsp; &nbsp; &nbsp; *Geophysical Research Letters*, 45(4), 1915-1922, https://doi.org/10.1002/2017GL076366  
Messié, M., Petrenko, A., Doglioli, A. M., Aldebert, C., Martinez, E., Koenig, G., Bonnet, S., and Moutin, T. (2020). **The delayed island mass effect: How islands can remotely trigger blooms in the oligotrophic ocean.**  
&nbsp; &nbsp; &nbsp; &nbsp; *Geophysical Research Letters*, 47(2), e2019GL085282, https://doi.org/10.1029/2019GL085282 

* * *

### Contact

monique@mbari.org

Do not hesitate to contact me if you cannot run the code in `start_GA_toolbox` or if you notice bugs!  

