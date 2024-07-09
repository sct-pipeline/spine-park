#!/bin/bash
# NB: This file is best displayed with 120 col.
# 
# Processing of multi-contrast BIDS dataset of patients with Parkinson's disease. This script is designed to be run 
# across multiple subjects in parallel using 'sct_run_batch', but it can also be used to run processing on a single 
# subject. The input data is assumed to be in BIDS format.
# 
# IMPORTANT: This script MUST be run from the root folder of the repository, because it relies on Python scripts located 
#  in the root folder.
#
# Usage:
#   ./process_data.sh <SUBJECT>
#
# Example:
#   ./process_data.sh sub-03
#
# Author: Julien Cohen-Adad

# Parameters
vertebral_levels="2:12"  # Vertebral levels to extract metrics from. "2:12" means from C2 to T5 (included)
# List of tracts to extract:
tracts=(
  "32,33"\
  "51"\
  "52"\
  "53"\
  "4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29"\
  "30,31"\
  "34,35"\
  "4,5"\
  "4,5,8,9,10,11,16,17,18,19,20,21,22,23,24,25,26,27"\
  "0,1,2,3,6,7,12,13,14,15"\
)
# The following global variables are retrieved from the caller sct_run_batch but could be overwritten by 
# uncommenting the lines below:
# PATH_DATA_PROCESSED="~/data_processed"
# PATH_RESULTS="~/results"
# PATH_LOG="~/log"
# PATH_QC="~/qc"

# Uncomment for full verbose
# set -v

# Immediately exit if error
set -e

# Exit if user presses CTRL+C (Linux) or CMD+C (OSX)
trap "echo Caught Keyboard Interrupt within script. Exiting now.; exit" INT

# Save script path
PATH_SCRIPT=$PWD


# CONVENIENCE FUNCTIONS
# =====================================================================================================================

label_if_does_not_exist() {
  # This function checks if a manual label file already exists, then:
  #   - If it does, copy it locally.
  #   - If it doesn't, perform automatic labeling.
  # This allows you to add manual labels on a subject-by-subject basis without disrupting the pipeline.

  local file="${1}"
  local file_seg="${2}"
  # Update global variable with segmentation file name
  FILELABEL="${file}"_label-disc
  FILELABELMANUAL="${PATH_DATA}"/derivatives/labels/"${SUBJECT}"/anat/"${FILELABEL}".nii.gz
  echo "Looking for manual label: ${FILELABELMANUAL}"
  if [[ -e "${FILELABELMANUAL}" ]]; then
    echo "Found! Copying manual labels."
    rsync -avzh "${FILELABELMANUAL}" "${FILELABEL}".nii.gz
  else
    echo "Not found. Proceeding with automatic labeling."
    # Generate labeled segmentation
    sct_label_vertebrae -i "${file}".nii.gz -s "${file_seg}".nii.gz -c t2 -qc "${PATH_QC}" -qc-subject "${SUBJECT}"
    # Rename the output labeled discs file to match the expected name
    mv "${file_seg}"_labeled_discs.nii.gz "${FILELABEL}".nii.gz
  fi
  # Generate QC report
  sct_qc -i "${file}".nii.gz -s "${FILELABEL}".nii.gz -p sct_label_utils -qc "${PATH_QC}" -qc-subject "${SUBJECT}"
}

segment_if_does_not_exist() {
  # This function checks if a manual spinal cord segmentation file already exists, then:
  #   - If it does, copy it locally.
  #   - If it doesn't, perform automatic spinal cord segmentation.
  # This allows you to add manual segmentations on a subject-by-subject basis without disrupting the pipeline.

  local file="${1}"
  local contrast="${2}"
  # Find if modality is 'anat' or 'dwi'
  if [[ $file == *"_DWI_"* ]]; then
    modality="dwi"
  else
    modality="anat"
  fi
  # Update global variable with segmentation file name
  FILESEG="${file}"_seg
  FILESEGMANUAL="${PATH_DATA}"/derivatives/labels/"${SUBJECT}"/"${modality}"/"${FILESEG}".nii.gz
  echo
  echo "Looking for manual segmentation: ${FILESEGMANUAL}"
  if [[ -e "${FILESEGMANUAL}" ]]; then
    echo "Found! Using manual segmentation."
    rsync -avzh "${FILESEGMANUAL}" "${FILESEG}".nii.gz
    sct_qc -i "${file}".nii.gz -s "${FILESEG}".nii.gz -p sct_deepseg_sc -qc "${PATH_QC}" -qc-subject "${SUBJECT}"
  else
    echo "Not found. Proceeding with automatic segmentation."
    # Segment spinal cord
    sct_deepseg -i "${file}".nii.gz -task seg_sc_contrast_agnostic -qc "${PATH_QC}" -qc-subject "${SUBJECT}"
  fi
}


# SCRIPT STARTS HERE
# =====================================================================================================================

# Retrieve input params
SUBJECT="${1}"

# get starting time:
start="$(date +%s)"

# Display useful info for the log, such as SCT version, RAM and CPU cores available
sct_check_dependencies -short

# Go to folder where data will be copied and processed
cd "${PATH_DATA_PROCESSED}"
# Copy source images
rsync -avzh "${PATH_DATA}"/"${SUBJECT}" .


# T2w
# =====================================================================================================================
cd "${SUBJECT}"/anat/
file_t2="${SUBJECT}"_T2
echo "👉 Processing: ${file_t2}"
# Segment spinal cord (only if it does not exist)
segment_if_does_not_exist "${file_t2}" "t2"
file_t2_seg="${FILESEG}"
# Create labels in the cord at mid-vertebral levels
label_if_does_not_exist "${file_t2}" "${file_t2_seg}"
file_label="${FILELABEL}"
# Register to template
sct_register_to_template -i "${file_t2}".nii.gz -s "${file_t2_seg}".nii.gz -ldisc "${file_label}".nii.gz -c t2 \
                         -param step=1,type=seg,algo=centermassrot:step=2,type=im,algo=syn,iter=5,slicewise=1,metric=CC,smooth=0 \
                         -qc "${PATH_QC}"
# Warp template
# Note: we don't need the white matter atlas at this point, therefore use flag "-a 0"
sct_warp_template -d "${file_t2}".nii.gz -w warp_template2anat.nii.gz -a 0 -ofolder label_T2w -qc "${PATH_QC}"
# Compute average CSA between C2 and T5 levels (append across subjects)
sct_process_segmentation -i "${file_t2_seg}".nii.gz -vert "${vertebral_levels}" -vertfile label_T2w/template/PAM50_levels.nii.gz \
                         -perlevel 1 -o "${PATH_RESULTS}"/CSA.csv -append 1 -qc "${PATH_QC}"
# Format CSV file
python ${PATH_SCRIPT}/format_csv.py "${PATH_RESULTS}"/CSA.csv


# MT
# =====================================================================================================================
file_mt1="${SUBJECT}"_mt-on_MTS
file_mt0="${SUBJECT}"_mt-off_MTS
echo "👉 Processing: ${file_mt0}"
# Segment spinal cord
segment_if_does_not_exist "${file_mt0}" "t1"
file_mt0_seg="${FILESEG}"
# Crop data for faster processing
sct_crop_image -i "${file_mt0}".nii.gz -m "${file_mt0_seg}".nii.gz -dilate 10x10x0 -o "${file_mt0}"_crop.nii.gz
sct_crop_image -i "${file_mt0_seg}".nii.gz -m "${file_mt0_seg}".nii.gz -dilate 10x10x0 -o "${file_mt0}"_crop_seg.nii.gz
file_mt0="${file_mt0}"_crop
# Register mt1->mt0
# Tips: here we only use rigid transformation because both images have very
# similar sequence parameters. We don't want to use SyN/BSplineSyN to avoid
# introducing spurious deformations.
sct_register_multimodal -i "${file_mt1}".nii.gz \
                        -d "${file_mt0}".nii.gz \
                        -dseg "${file_mt0}"_seg.nii.gz \
                        -param step=1,type=im,algo=rigid,slicewise=1,metric=CC \
                        -x spline \
                        -qc "${PATH_QC}"
# Register template->mt0
# Tips: First step: slicereg based on images, with large smoothing to capture potential motion between anat and mt, then 
# at second step: bpslinesyn in order to adapt the shape of the cord to the mt modality (in case there are distortions 
# between anat and mt).
sct_register_multimodal -i "${SCT_DIR}"/data/PAM50/template/PAM50_t1.nii.gz \
                        -iseg "${SCT_DIR}"/data/PAM50/template/PAM50_cord.nii.gz \
                        -d "${file_mt0}".nii.gz \
                        -dseg "${file_mt0}"_seg.nii.gz \
                        -param step=1,type=seg,algo=centermass:step=2,type=im,algo=bsplinesyn,slicewise=1,iter=3 \
                        -initwarp warp_template2anat.nii.gz \
                        -initwarpinv warp_anat2template.nii.gz \
                        -qc "${PATH_QC}"
# Rename warping fields for clarity
mv warp_PAM50_t12"${file_mt0}".nii.gz warp_template2mt.nii.gz
mv warp_"${file_mt0}"2PAM50_t1.nii.gz warp_mt2template.nii.gz
# Warp template
sct_warp_template -d "${file_mt0}".nii.gz -w warp_template2mt.nii.gz -ofolder label_MT -qc "${PATH_QC}"
# Compute mtr
sct_compute_mtr -mt0 "${file_mt0}".nii.gz -mt1 "${file_mt1}"_reg.nii.gz
# compute MTR in various tracts
for tract in ${tracts[@]}; do
  file_out=${PATH_RESULTS}/MTR_${tract//,/-}.csv
  sct_extract_metric -i mtr.nii.gz -f label_MT/atlas -l ${tract} -combine 1 -vert "${vertebral_levels}" -vertfile label_MT/template/PAM50_levels.nii.gz -perlevel 1 -method map -o ${file_out} -append 1
  # Format CSV file
  python ${PATH_SCRIPT}/format_csv.py ${file_out}
done


# MP2RAGE
# =====================================================================================================================
file_uni="${SUBJECT}"_UNIT1
file_t1="${SUBJECT}"_T1map
echo "👉 Processing: ${file_uni}"
# Segment spinal cord
segment_if_does_not_exist "${file_uni}" "t1"
file_uni_seg="${FILESEG}"
# Crop data for faster processing
sct_crop_image -i "${file_uni}".nii.gz -m "${file_uni_seg}".nii.gz -dilate 5x5x0 -o "${file_uni}"_crop.nii.gz
file_uni="${file_uni}"_crop
sct_crop_image -i "${file_t1}".nii.gz -m "${file_uni_seg}".nii.gz -dilate 5x5x0 -o "${file_t1}"_crop.nii.gz
file_t1="${file_t1}"_crop
# Register template->UNIT1
sct_register_multimodal -i "${SCT_DIR}"/data/PAM50/template/PAM50_t1.nii.gz \
                        -iseg "${SCT_DIR}"/data/PAM50/template/PAM50_cord.nii.gz \
                        -d "${file_uni}".nii.gz \
                        -dseg "${file_uni_seg}".nii.gz \
                        -param step=1,type=seg,algo=centermass:step=2,type=im,algo=bsplinesyn,slicewise=0,iter=3 \
                        -initwarp warp_template2anat.nii.gz \
                        -initwarpinv warp_anat2template.nii.gz \
                        -qc "${PATH_QC}"
# Rename warping fields for clarity
mv warp_PAM50_t12"${file_uni}".nii.gz warp_template2t1.nii.gz
mv warp_"${file_uni}"2PAM50_t1.nii.gz warp_t12template.nii.gz
# Warp template
sct_warp_template -d "${file_uni}".nii.gz -w warp_template2t1.nii.gz -ofolder label_T1 -qc "${PATH_QC}"
# compute T1 in various tracts
for tract in ${tracts[@]}; do
  file_out=${PATH_RESULTS}/T1_${dti_metric}_${tract//,/-}.csv
  sct_extract_metric -i "${file_t1}".nii.gz -f label_T1/atlas -l ${tract} -combine 1 -vert "${vertebral_levels}" -vertfile label_T1/template/PAM50_levels.nii.gz -perlevel 1 -method map -o ${file_out} -append 1
  # Format CSV file
  python ${PATH_SCRIPT}/format_csv.py ${file_out}
done


# DWI
# =====================================================================================================================
# For each slab:
# • Average DWI scans
# • Segment spinal cord on mean DWI scan
# • Create mask
# • Motion correction
# • Average DWI scan
# • Segment spinal cord on mean DWI_moco scan
# • Register to PAM50 via T2w registration
# • Compute DTI metrics for all slices within various tracts/regions
# Then:
# DWI merging of slabs:
# • Use a script that will combine the three CSV files (one per slab, with some overlap) and that will average the DTI 
#   metrics within each vertebral level that exists across the three CSV files.
cd ../dwi/
# Get file names for every acquired chunks of DWI data
files_dwi=(`ls "${SUBJECT}"_chunk-*_DWI.nii.gz`)
for file_dwi in "${files_dwi[@]}"; do
  echo "👉 Processing: ${file_dwi}"
  file_dwi="${file_dwi%.nii.gz}"
  file_bvec=${file_dwi}.bvec
  file_bval=${file_dwi}.bval
  # Separate b=0 and DW images
  sct_dmri_separate_b0_and_dwi -i ${file_dwi}.nii.gz -bvec ${file_bvec}
  # Segment spinal cord
  segment_if_does_not_exist "${file_dwi}"_dwi_mean "dwi"
  file_dwi_seg="${FILESEG}"
  # Crop data for faster processing
  sct_crop_image -i "${file_dwi}".nii.gz -m "${file_dwi_seg}".nii.gz -dilate 15x15x0 -o "${file_dwi}"_crop.nii.gz
  file_dwi=${file_dwi}_crop
  # Motion correction
  sct_dmri_moco -i ${file_dwi}.nii.gz -bvec ${file_bvec} -x spline -param metric=CC
  file_dwi=${file_dwi}_moco
  file_dwi_mean=${file_dwi}_dwi_mean
  # Segment spinal cord (only if it does not exist)
  segment_if_does_not_exist ${file_dwi_mean} "dwi"
  file_dwi_seg=$FILESEG
  # Register template->dwi (using T2w-to-template as initial transformation)
  sct_register_multimodal -i $SCT_DIR/data/PAM50/template/PAM50_t1.nii.gz \
                          -iseg $SCT_DIR/data/PAM50/template/PAM50_cord.nii.gz \
                          -d ${file_dwi_mean}.nii.gz -dseg ${file_dwi_seg}.nii.gz \
                          -param step=1,type=seg,algo=centermass:step=2,type=im,algo=bsplinesyn,metric=CC,slicewise=1,iter=3,gradStep=0.5 \
                          -initwarp ../anat/warp_template2anat.nii.gz -initwarpinv ../anat/warp_anat2template.nii.gz \
                          -qc "${PATH_QC}"
  # Warp template
  sct_warp_template -d ${file_dwi_mean}.nii.gz -w warp_PAM50_t12${file_dwi_mean}.nii.gz -ofolder label_${file_dwi} -qc ${PATH_QC} -qc-subject ${SUBJECT}
  # Compute DTI
  sct_dmri_compute_dti -i ${file_dwi}.nii.gz -bvec ${file_bvec} -bval ${file_bval} -method standard -o ${file_dwi}_
  # Compute DTI metrics in various tracts
  dti_metrics=(FA MD RD AD)
  for dti_metric in ${dti_metrics[@]}; do
    for tract in ${tracts[@]}; do
      file_out=${PATH_RESULTS}/DWI_${dti_metric}_${tract//,/-}.csv
      sct_extract_metric -i ${file_dwi}_${dti_metric}.nii.gz -f label_${file_dwi}/atlas -l ${tract} -combine 1 -vert "${vertebral_levels}" -vertfile label_${file_dwi}/template/PAM50_levels.nii.gz -perlevel 1 -method map -o ${file_out} -append 1
      # Aggregate metrics across vertebral levels pertaining to adjacent chunks
      python ${PATH_SCRIPT}/aggregate_chunks.py ${file_out} --output-csv ${PATH_RESULTS}/DWI_${dti_metric}_${tract//,/-}_aggregated.csv
    done
  done
  # Output file levels.csv to check the correspondance between vertebral levels and slices for each chunk
  sct_extract_metric -i ${file_dwi}_FA.nii.gz -l 51 -f label_${file_dwi}/atlas/ -vert "${vertebral_levels}" -perlevel 1 -vertfile label_${file_dwi}/template/PAM50_levels.nii.gz -o levels.csv -append 1
done

# TODO
# Average metrics within vertebral levels from output CSV files

# Go back to parent folder
cd ..


# Verify presence of output files and write log file if error
# ======================================================================================================================
FILES_TO_CHECK=(
  "anat/${file_t2_seg}".nii.gz
  "anat/mtr.nii.gz"
  "dwi/${file_dwi}_FA.nii.gz"
)
for file in "${FILES_TO_CHECK[@]}"; do
  if [ ! -e "${file}" ]; then
    echo "${SUBJECT}/${file} does not exist" >> "${PATH_LOG}/error.log"
  fi
done

# Display useful info for the log
end="$(date +%s)"
runtime="$((end-start))"
echo
echo "~~~"
echo "SCT version: $(sct_version)"
echo "Ran on:      $(uname -nsr)"
echo "Duration:    $((runtime / 3600))hrs $(( (runtime / 60) % 60))min $((runtime % 60))sec"
echo "~~~"
