# use pre-processed netcdf files (based on Moucha et al. 2011 Fig.2 -> see moucha3dem.py) to generate a proper DEM for model input
#---------------------------------------------------------------------------------------------------------------------------------
# Steps:
#-------
# 1. Step
#    -shift data into a 0-360 longitude format from -180-180 using NCO
# 2. Step
#    -resample the data to model resolution using CDO
# 3. Step
#    -subtract 5, 10, 15, 20 and 25 Ma from present day (0Ma) to get the difference from today
# 4. Step
#    -subtract the difference from the model DEM (z_divc9.8.nc) to get past topography for ROI

#-----------------------
mkdir model_input_dems

ncap2 -O -s 'where(lon<0) lon=360+lon' african_topo_moucha_00ma_georef_processed.nc african_topo_moucha_0ma_remapped.nc
cdo remapcon,z_divc9.8.nc african_topo_moucha_0ma_remapped.nc african_topo_moucha_0ma_regridded.nc

#remap the shapefile
cdo remapcon,z_divc9.8.nc ASS_outline.nc africa_outline_remap.nc

#create masks
cdo -setmisstoc,1 -setrtoc,-2,2,0 africa_outline_remap.nc AT0.nc
cdo -mul z_divc9.8.nc AT0.nc AT3.nc

cdo -setmisstoc,0 -setrtoc,-2,2,1 africa_outline_remap.nc AT1.nc
cdo -mul z_divc9.8.nc AT1.nc AT2.nc

for filename in african*_processed.nc; do
	#[ -e "$filename" ] || continue
	ncap2 -O -s 'where(lon<0) lon=360+lon' $filename tmp.nc
	cdo remapcon,z_divc9.8.nc tmp.nc tmp_remap.nc
	cdo sub african_topo_moucha_0ma_regridded.nc tmp_remap.nc tmp_remap_diff0.nc
	#ncap2 -s 'where(dyntopo_ref30Ma<0.) dyntopo_ref30Ma=0;' tmp_remap_diff0.nc tmp_remap_diff1.nc
	cdo sub z_divc9.8.nc tmp_remap_diff0.nc tmp_remap_diff1.nc
	cdo -expr,'z=((z>50))?1.0:z/0.0' tmp_remap_diff1.nc tmp_masked.nc
	cdo -mul tmp_masked.nc tmp_remap_diff1.nc tmp_remap_diff1_masked.nc	
	cdo setmiss tmp_remap_diff1_masked.nc z_divc9.8.nc tmp_remap_diff1_filled.nc
	cdo -mul tmp_remap_diff1_filled.nc AT1.nc tmp_remap_diff1_roi.nc
	#cdo smooth9 tmp_remap_diff1_roi.nc tmp_remap_diff1_smooth.nc
	cdo setmiss tmp_remap_diff1_roi.nc z_divc9.8.nc out_test.nc
        cdo smooth,weightR=0.07,weight0=0.25  out_test.nc tmp_remap_diff1_smooth.nc	
	cdo add tmp_remap_diff1_smooth.nc AT3.nc ./model_input_dems/"${filename%%.nc}"_modIn.nc 
        rm *tmp*.nc
done	

cd ./model_input_dems
rm *30*
