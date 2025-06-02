import sys

def convert_16bit_to_64bit(input_file, output_file):
    with open(input_file, "r") as f:
        hex_values = [line.strip() for line in f if line.strip()]  # Read and clean lines
    
    hex_values.reverse()  # Reverse order
    
    # Ensure the number of 16-bit values is a multiple of 4
    while len(hex_values) % 4 != 0:
        hex_values.insert(0, "0000")  # Padding with zeros if necessary
    
    # Group every four 16-bit values into a 64-bit value
    chunks = ["".join(hex_values[i:i+4]) for i in range(0, len(hex_values), 4)]
    
    chunks.reverse()  # Reverse back to original order
    
    with open(output_file, "w") as f:
        f.write("\n".join(chunks) + "\n")  # Write output with new lines

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python 16to64.py <input_file> <output_file>")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2] if sys.argv[2].endswith(".mem") else sys.argv[2] + ".mem"
    
    convert_16bit_to_64bit(input_file, output_file)
    print(f"Conversion completed. Output saved to {output_file}")