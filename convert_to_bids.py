import os
import gzip
import shutil
import re


def extract_patient_id(dirname):
    """Converts the directory name to a BIDS-compatible patient ID.

    Examples of directory names and conversions:
    2023_10_02_DEV2_206_01_ICEBERG_ME_Sujet10 -> sub-DEV206Sujet10
    2020_09_16_ICEBERG_LM_166_V3_M -> sub-LM166
    2020_10_28_ICEBERG_LC_164_V3_M -> sub-LC164
    2020_11_18_ICEBERG_BJ_170_V3_M -> sub-BJ170
    2020_10_29_ICEBERG_BB_277_V1_M -> sub-BB277
    2023_10_20_DEV2_214_01_ICEBERG_ME_Sujet12 -> sub-DEV214Sujet12

    Args:
        dirname (_type_): _description_

    Returns:
        _type_: _description_
    """
    # Check if subject is healthy control or patient
    if "DEV2" in dirname:
        # Healthy control
        patient_number = dirname.rsplit("DEV2_")[1].rsplit("_")[0]
        patient_sujet_number = dirname.rsplit("Sujet")[1]
        patient_id = f"sub-DEV{patient_number}Sujet{patient_sujet_number}"
    else:
        # Patient
        patient_initials = dirname.split("ICEBERG_")[1].split("_")[0]
        patient_number = dirname.split("ICEBERG_")[1].split("_")[1]
        patient_id = f"sub-{patient_initials}{patient_number}"
    return patient_id


def convert_mri_to_bids(root_dir):
    for patient_dir in os.listdir(root_dir):
        patient_path = os.path.join(root_dir, patient_dir)
        if os.path.isdir(patient_path):
            bids_patient_id = extract_patient_id(patient_dir)
            print(f"{patient_dir} -> {bids_patient_id}")
            if not bids_patient_id:
                print(f"Could not determine BIDS patient ID for directory: {patient_dir}")
                continue  # Skip directory if patient ID cannot be determined
            
            bids_path = os.path.join(path_out, bids_patient_id)
            os.makedirs(bids_path, exist_ok=True)

            # Counters for DWI chunks
            dwi_chunk_counter = 1

            for dirpath, _, filenames in os.walk(patient_path):
                for filename in filenames:
                    if filename.endswith(".nii"):
                        # Determine the type of scan and set the BIDS path
                        new_filename, bids_subfolder = determine_scan_type_and_bids_path(filename, bids_patient_id, dwi_chunk_counter)
                        if new_filename:
                            # Handle NIfTI files
                            zip_and_move_nifti(os.path.join(dirpath, filename), os.path.join(bids_path, bids_subfolder, new_filename))
                            
                            # Handle associated JSON files
                            json_filename = filename.replace('.nii', '.json')
                            if json_filename in filenames:
                                shutil.copy(os.path.join(dirpath, json_filename), os.path.join(bids_path, bids_subfolder, new_filename.replace('.nii.gz', '.json')))
                            
                            # Handle DWI additional files
                            if 'DWI' in new_filename:
                                for ext in ['.bval', '.bvec']:
                                    dwi_file = filename.replace('.nii', ext)
                                    if dwi_file in filenames:
                                        shutil.copy(os.path.join(dirpath, dwi_file), os.path.join(bids_path, bids_subfolder, new_filename.replace('.nii.gz', ext)))
                                dwi_chunk_counter += 1
                        else:
                            print(f"Ignoring file: {filename}")


def determine_scan_type_and_bids_path(filename, patient_id, dwi_chunk_counter):
    """Determines the type of scan and sets the BIDS path.

    Args:
        filename (_type_): _description_
        patient_id (_type_): _description_
        dwi_chunk_counter (_type_): _description_

    Returns:
        _type_: _description_
    """
    if "T2_SAG" in filename:
        return f"{patient_id}_T2.nii", "anat"
    elif "DTI_64DIR" in filename:
        return f"{patient_id}_chunk-{dwi_chunk_counter}_DWI.nii", "dwi"
    elif "T1_SAG_MT_FL3D" in filename:
        return f"{patient_id}_mt-on_MTS.nii", "anat"
    elif "T1_SAG_FL3D" in filename:
        return f"{patient_id}_mt-off_MTS.nii", "anat"
    elif "mp2rage_sag_p3_1mm_iso_T1" in filename:
        return f"{patient_id}_T1map.nii", "anat"
    elif "mp2rage_sag_p3_1mm_iso_UNI" in filename:
        return f"{patient_id}_UNIT1.nii", "anat"
    return None, None


def zip_and_move_nifti(src_path, dest_path):
    """Zips and moves a NIfTI file.

    Args:
        src_path (_type_): _description_
        dest_path (_type_): _description_
    """
    with open(src_path, 'rb') as f_in, gzip.open(dest_path, 'wb') as f_out:
        shutil.copyfileobj(f_in, f_out)


root_directory = "/Users/julien/temp/20240122_Lydia/CENIR_ICEBERG_spine"
path_out = "/Users/julien/temp/20240122_Lydia/CENIR_ICEBERG_spine_BIDS"
convert_mri_to_bids(root_directory)
