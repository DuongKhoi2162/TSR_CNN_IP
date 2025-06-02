import sys
import torch

# Check for correct number of arguments
if len(sys.argv) != 2:
    print("Usage: python script.py <output_file.txt>")
    sys.exit(1)

# Get input and output file names from command-line arguments
output_file = sys.argv[2]

# Load the tensor from the .pt file
tensor_in = torch.load(input_file)  # Assuming tensor is saved as a PyTorch tensor

# Check the tensor shape
if tensor_in.shape != (1, 4, 13, 13):
    print("Error: Tensor must have shape (1, 48, 13, 13)")
    sys.exit(1)

# Squeeze the batch dimension to get a (3, 32, 32) tensor
tensor_in = tensor_in.squeeze(0)

# Prepare the output data
with open(output_file, "w") as outfile:
    for row in range(13):
        for col in range(13):
            # Extract the 3-channel pixel values
            pixel_values = tensor_in[:, row, col]
            # Convert each channel value to hex and concatenate
            hex_pixel = ''.join(f"{int(value.item()):02x}" for value in pixel_values)
            outfile.write(hex_pixel + "\n")

print(f"Tensor converted and saved to {output_file}")