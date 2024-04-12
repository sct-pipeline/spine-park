# spine-park

Pipeline for multicontrast analysis in PD patients.

## How to use

### Install dependencies

[Install Spinal Cord Toolbox](https://spinalcordtoolbox.com/user_section/installation.html)

Clone this repository
```
git clone https://github.com/sct-pipeline/spine-park.git
cd spine-park
```

### Convert data to BIDS

~~~
python convert_to_bids.py <PATH_TO_INPUT_MRI_DATA> <PATH_TO_OUTPUT_BIDS_DATA>
~~~

### Run processing across all subjects

~~~
sct_run_batch -script batch_processing.sh -path-data <PATH_TO_OUTPUT_BIDS_DATA> -path-output <PATH_TO_RESULTS> -jobs -1
~~~

To only run the processing in one subject (for debugging purpose), use this:

~~~
sct_run_batch -script batch_processing.sh -path-data <PATH_TO_OUTPUT_BIDS_DATA> -path-output <PATH_TO_RESULTS> -include-list sub-BB277
~~~

### Run QC and manually correct the segmentations

Launch the QC report and flag with a ❌ the segmentations that need to be manually corrected. Then, download the YML file that list the problematic segmentations (bottom left button on the QC web browser) and run the script [manual-correction](https://github.com/spinalcordtoolbox/manual-correction) to go through all the segmentations to be corrected.

The corrected segmentations need to be created under the `derivatives/labels/` folder, at the root of the input dataset. This is done automatically by the manual-correction script, but the correct path need to be specified when running manual-correction.

The data with the derivatives folder should look like this:
```bash
├── derivatives
│   └── labels
│       └── sub-BB277
│           └── anat
│               └── sub-BB277_T2_seg.nii.gz
├── sub-BB277
│   ├── anat
│   │   ├── sub-BB277_T1map.json
│   │   ├── sub-BB277_T1map.nii.gz
│   │   ├── sub-BB277_T2.json
│   │   ├── sub-BB277_T2.nii.gz
│   │   ├── sub-BB277_UNIT1.json
│   │   ├── sub-BB277_UNIT1.nii.gz
│   │   ├── sub-BB277_mt-off_MTS.json
│   │   ├── sub-BB277_mt-off_MTS.nii.gz
│   │   ├── sub-BB277_mt-on_MTS.json
│   │   └── sub-BB277_mt-on_MTS.nii.gz
│   └── dwi
│       ├── sub-BB277_chunk-1_DWI.bval
│       ├── sub-BB277_chunk-1_DWI.bvec
│       ├── sub-BB277_chunk-1_DWI.json
│       ├── sub-BB277_chunk-1_DWI.nii.gz
│       ├── sub-BB277_chunk-2_DWI.bval
│       ├── sub-BB277_chunk-2_DWI.bvec
│       ├── sub-BB277_chunk-2_DWI.json
│       ├── sub-BB277_chunk-2_DWI.nii.gz
│       ├── sub-BB277_chunk-3_DWI.bval
│       ├── sub-BB277_chunk-3_DWI.bvec
│       ├── sub-BB277_chunk-3_DWI.json
│       └── sub-BB277_chunk-3_DWI.nii.gz
└── sub-DEV206Sujet10
```

Once segmentation masks are corrected, you can re-run the script, and the corrected segmentation will be used (if they exist).
