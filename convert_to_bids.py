"""Converts the CENIR ICEBERG spine MRI data to BIDS format.

This script is specific to the CENIR ICEBERG spine data and should not be used for other data.
The script assumes that the input data is organized as follows:
- A root directory containing one directory per patient
- Each patient directory contains one or more directories containing the MRI data
- The MRI data directories contain the NIfTI files and associated JSON files
- NIfTI files are assumed to be in the .nii format
The script will create a new directory containing the BIDS-converted data.
The script will also zip the NIfTI files to save space.
The script will also handle the DWI data, which is split into multiple chunks.
The script will also handle the additional files associated with the DWI data (bval, bvec).
The script will also handle the T1 mapping data, which is split into two files (mt-on and mt-off).

Author: Julien Cohen-Adad
"""


import argparse
import os
import gzip
import shutil


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


def convert_mri_to_bids(path_in, path_out):
    """Converts the MRI data to BIDS format.

    Args:
        path_in (_type_): _description_
        path_out (_type_): _description_
    """
    for patient_dir in os.listdir(path_in):
        patient_path = os.path.join(path_in, patient_dir)
        if os.path.isdir(patient_path):
            bids_patient_id = extract_patient_id(patient_dir)
            print(f"\n{patient_dir} -> {bids_patient_id}")
            print(f"============================================================================")
            if not bids_patient_id:
                print(f"Could not determine BIDS patient ID for directory: {patient_dir}")
                continue  # Skip directory if patient ID cannot be determined
            
            bids_path = os.path.join(path_out, bids_patient_id)

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
                            print(f"❌ {filename}")


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
        return f"{patient_id}_T2.nii.gz", "anat"
    elif "DTI_64DIR" in filename:
        return f"{patient_id}_chunk-{dwi_chunk_counter}_DWI.nii.gz", "dwi"
    elif "T1_SAG_MT_FL3D" in filename:
        return f"{patient_id}_mt-on_MTS.nii.gz", "anat"
    elif "T1_SAG_FL3D" in filename:
        return f"{patient_id}_mt-off_MTS.nii.gz", "anat"
    elif "mp2rage_sag_p3_1mm_iso_T1" in filename:
        return f"{patient_id}_T1map.nii.gz", "anat"
    elif "mp2rage_sag_p3_1mm_iso_UNI" in filename:
        return f"{patient_id}_UNIT1.nii.gz", "anat"
    return None, None


def zip_and_move_nifti(src_path, dest_path):
    """Zips and moves a NIfTI file.

    Args:
        src_path (_type_): _description_
        dest_path (_type_): _description_
    """
    # Create output directory if it does not exist
    dest_dir = os.path.dirname(dest_path)
    os.makedirs(dest_dir, exist_ok=True)
    # Zip and move the NIfTI file
    with open(src_path, 'rb') as f_in, gzip.open(dest_path, 'wb') as f_out:
        print(f"✅ {src_path} -> {dest_path}")
        shutil.copyfileobj(f_in, f_out)


def main(path_in, path_out):
    # This is where you would add the code to process the MRI files according to BIDS
    # For demonstration, let's just print the paths to show it's working
    print(f"Convert data to BIDS format.\n\n"
          f"Input: {path_in}\n"
          f"Output: {path_out}") 
    convert_mri_to_bids(path_in, path_out)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Convert MRI files to BIDS format and zip NIfTI files.",
        epilog="Example usage:\n"
           "python convert_to_bids.py /path/to/mri/files /path/to/bids/output",
           formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("path_in", help="Root directory of the MRI files")
    parser.add_argument("path_out", help="Output directory for BIDS-structured files")

    args = parser.parse_args()

    main(args.path_in, args.path_out)
