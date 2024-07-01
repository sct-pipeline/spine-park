#!/usr/bin/env python
# coding: utf-8
# 
# Takes CSV as input, find what the Subject name is from the column 'FileName', and add a column 'Subject'.
# 
# Author: Julien Cohen-Adad
 
import pandas as pd
import argparse
import os


def add_subject_column(input_csv, output_csv):
    # Load the CSV file
    df = pd.read_csv(input_csv, sep=',')

    # Extract subject information ("sub-XXX"), assuming the subject identifier is between "sub-" and "_"
    df['Subject'] = df['Filename'].str.extract(r'(sub-[^_/]+)')

    # Move the 'subject' column to the first position
    columns = ['Subject'] + [col for col in df.columns if col != 'Subject']
    df = df[columns]

    # Save the updated DataFrame to a new CSV file
    df.to_csv(output_csv, sep=',', index=False)

    print(f"Updated CSV with subject column saved to {output_csv}")


def main():
    parser = argparse.ArgumentParser(description='Add a subject column to the CSV file.')
    parser.add_argument('input_csv', type=str, help='Path to the input CSV file.')
    parser.add_argument('--output-csv', type=str, help='Path to the output CSV file.')

    args = parser.parse_args()
    
    input_csv = args.input_csv
    
    if args.output_csv:
        output_csv = args.output_csv
    else:
        base, ext = os.path.splitext(input_csv)
        output_csv = f"{base}_formatted{ext}"

    add_subject_column(input_csv, output_csv)

if __name__ == '__main__':
    main()
