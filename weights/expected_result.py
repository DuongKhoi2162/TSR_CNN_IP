import argparse
import pandas as pd

def convert_class_ids_to_mem(input_csv, output_mem, column="ClassId", start=0, end=None):
    # Read CSV file
    df = pd.read_csv(input_csv)

    # Validate column name
    if column not in df.columns:
        raise ValueError(f"Column '{column}' not found in the CSV file.")

    # Slice the DataFrame
    sliced = df.iloc[start:end]

    # Convert values to 8-bit hex strings
    hex_values = [format(int(val), '02x') for val in sliced[column] if pd.notna(val)]

    # Write each hex value to the .mem file
    with open(output_mem, 'w') as f:
        for hex_val in hex_values:
            f.write(hex_val + '\n')

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Convert Class IDs from CSV to .mem file with 8-bit hex values.")
    parser.add_argument("input_csv", help="Path to the input CSV file")
    parser.add_argument("output_mem", help="Path to the output .mem file")
    parser.add_argument("-column", default="ClassId", help="Name of the column with Class IDs (default: ClassId)")
    parser.add_argument("-start", type=int, default=0, help="Row index to start reading (default: 0)")
    parser.add_argument("-end", type=int, default=None, help="Row index to end reading (exclusive, default: till end)")

    args = parser.parse_args()

    convert_class_ids_to_mem(args.input_csv, args.output_mem, args.column, args.start, args.end)
