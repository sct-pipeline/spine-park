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
