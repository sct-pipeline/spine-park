# spine-park

Pipeline for multicontrast analysis in PD patients.

## How to use

### Install dependencies

- [Install Spinal Cord Toolbox](https://spinalcordtoolbox.com/user_section/installation.html)
- [Install manual-correction](https://github.com/spinalcordtoolbox/manual-correction?tab=readme-ov-file#2-installation)

Clone this repository
```
git clone https://github.com/sct-pipeline/spine-park.git
cd spine-park
```

### Declare variables

```bash
PATH_DATA_RAW=<PATH TO ORIGINAL NIFTI DATASET>
PATH_DATA_BIDS=<PATH TO OUTPUT BIDS DATASET>
```

### Convert data to BIDS

~~~
python convert_to_bids.py $PATH_DATA_RAW $PATH_DATA_BIDS
~~~

### Perform manual vertebral labeling

Because automatic vertebral labeling is unreliable on this dataset (see #21 #24), manual labeling should be done instead.
The procedure is as follows:
- Install `manual-correction` (see [Install dependencies](#install-dependencies))
- Go in the folder:
  ```bash
  cd manual-correction
  ```
- Create a configuration file that lists all subjects in the dataset
  ```bash
  echo "FILES_LABEL:" > config.yml && find $PATH_DATA_BIDS -type f -name "*_T2.nii.gz" -exec basename {} \; | awk '{print "- " $0}' >> config.yml
  ```
- Perform manual labeling of discs by running this commmand:
  ```bash
  python manual_correction.py -path-img $PATH_DATA_BIDS -config config.yml
  ```
- If you want to quit and resume later, click on the Terminal window and press CTRL+C (`KeyboardInterrupt`). The `manual-correction` software will quit, and the `config.yml` will be modified such that the next time you re-run manual 
correction, you won't have to re-do the labels that you already did. 

Here is a video tutorial:

[![IMAGE ALT TEXT HERE](https://img.youtube.com/vi/IgJUu5CCHxY/0.jpg)](https://www.youtube.com/watch?v=IgJUu5CCHxY)

### Run processing across all subjects

~~~
sct_run_batch -script batch_processing.sh -path-data $PATH_DATA_BIDS -path-output <PATH_RESULTS> -jobs -1
~~~

To only run the processing in one subject (for debugging purpose), use this:

~~~
sct_run_batch -script batch_processing.sh -path-data $PATH_DATA_BIDS -path-output <PATH_RESULTS> -include-list sub-BB277
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
