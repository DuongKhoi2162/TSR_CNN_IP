import sys

# Check for correct number of arguments
if len(sys.argv) != 3:
    print("Usage: python script.py <input_file.coe> <output_file.txt>")
    sys.exit(1)

# Get input and output file names from command-line arguments
input_file = sys.argv[1]
output_file = sys.argv[2]

# Read the .coe file
with open(input_file, "r") as infile:
    lines = infile.readlines()

# Find the start of memory_initialization_vector
vector_start = False
vector_values = []

for line in lines:
    line = line.strip()
    # Check for the start of the vector
    if line.startswith("memory_initialization_vector"):
        vector_start = True
        continue

    if vector_start:
        # Remove trailing semicolon and split by commas
        line = line.rstrip(";")
        values = line.split(",")
        vector_values.extend(values)

# Remove any empty strings or whitespace
vector_values = [value.strip() for value in vector_values if value.strip()]

# Write the values to the output file
with open(output_file, "w") as outfile:
    for value in vector_values:
        outfile.write(value + "\n")

print(f"Converted .coe file saved as {output_file}")
