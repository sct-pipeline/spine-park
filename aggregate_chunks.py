#!/usr/bin/env python
# coding: utf-8
# 
# Takes CSV as input, and, for each subject (defined by the folder "sub-*/"), aggregates the lines that share 
# the same vertebral level. The aggregation would be done using weighted average, the weighting being driven 
# by the column "Size [vox]". 
# 
# Author: Julien Cohen-Adad

import argparse
import os
import pandas as pd

def aggregate_data(input_csv, output_csv):
    # Load the CSV file
    df = pd.read_csv(input_csv, sep=',')

    # Extract subject information ("sub-XXX"), assuming the subject identifier is between "sub-" and "_"
    df['subject'] = df['Filename'].str.extract(r'(sub-[^_/]+)')

    # Ensure VertLevel is treated as string
    df['VertLevel'] = df['VertLevel'].astype(str)

    # Split vertebral level ranges into separate rows
    df = df.drop('VertLevel', axis=1).join(
        df['VertLevel'].str.split(':', expand=True).stack().reset_index(level=1, drop=True).rename('VertLevel')
    )
    df['VertLevel'] = df['VertLevel'].astype(int)

    # Group by subject and vertebral level, then calculate weighted averages
    aggregated_df = df.groupby(['subject', 'VertLevel']).apply(
        lambda x: pd.Series({
            'Size [vox]': x['Size [vox]'].sum(),
            'MAP()': (x['Size [vox]'] * x['MAP()']).sum() / x['Size [vox]'].sum(),
            'STD()': (x['Size [vox]'] * x['STD()']).sum() / x['Size [vox]'].sum()
        })
    ).reset_index()

    # Save the aggregated data to a new CSV file
    aggregated_df.to_csv(output_csv, sep=',', index=False)

def main():
    parser = argparse.ArgumentParser(description='Aggregate MRI data.')
    parser.add_argument('input_csv', type=str, help='Path to the input CSV file.')
    parser.add_argument('--output_csv', type=str, help='Path to the output CSV file.')

    args = parser.parse_args()
    
    input_csv = args.input_csv
    
    if args.output_csv:
        output_csv = args.output_csv
    else:
        base, ext = os.path.splitext(input_csv)
        output_csv = f"{base}_aggregated{ext}"

    aggregate_data(input_csv, output_csv)
    print(f"Aggregated data saved to {output_csv}")

if __name__ == '__main__':
    main()