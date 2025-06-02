import sys

def convert_to_64bit(input_file, output_file, split_size=16):
    with open(input_file, "r") as f:
        hex_values = [line.strip() for line in f if line.strip()]  # Read and clean lines

    hex_values.reverse()  # Reverse order
    hex_data = "".join(hex_values)  # Concatenate into a single string

    # Split into fixed-size chunks (e.g., 16 characters per line)
    chunks = [hex_data[i:i+split_size] for i in range(0, len(hex_data), split_size)]

    chunks.reverse()
    
    with open(output_file, "w") as f:
        f.write("\n".join(chunks) + "\n")  # Write output with new lines

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python convert_24bit_to_64bit.py <input_file> <output_file> [split_size]")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2] if sys.argv[2].endswith(".mem") else sys.argv[2] + ".mem"
    split_size = int(sys.argv[3]) if len(sys.argv) > 3 else 16  # Default split size is 16

    convert_to_64bit(input_file, output_file, split_size)
    print(f"Conversion completed. Output saved to {output_file}")
