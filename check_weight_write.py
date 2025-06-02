from fixedpoint import FixedPoint
import argparse
import torch
import os
from model_quantized.TSRNetQuantized import QuantizedTrafficSignModel
from model_quantized.quantize_utils import tsr_quantize_model
import torchvision.transforms as transforms
import matplotlib.pyplot as plt
from PIL import Image
def get_arguments():
    parser = argparse.ArgumentParser()

    parser.add_argument('--weights_bin_path', type=str, default='./weights/tsr_fpga_weights.bin')
    parser.add_argument('--quantized_weights_path', type=str, default='./weights/traffic_sign_model_quantized_final.pth')

    args = parser.parse_args()

    args.weights_bin_path = os.path.abspath(args.weights_bin_path)
    args.quantized_weights_path = os.path.abspath(args.quantized_weights_path)

    return args

args = get_arguments()
model = QuantizedTrafficSignModel()
quantized_model = tsr_quantize_model(model)
quantized_model.load_state_dict(torch.load(args.quantized_weights_path), strict = False)

#print(quantized_model.conv1.weight().int_repr())
weight_matrix = []
weight_arr = []
bias_matrix = []
bias_arr    = []
for fil in range(quantized_model.conv1.out_channels):
    weight_matrix = []

    for row in range(quantized_model.conv1.kernel_size[0]):
        for col in range(quantized_model.conv1.kernel_size[1]):
            for cha in range(quantized_model.conv1.in_channels):
                weight_value = quantized_model.conv1.weight().int_repr()[fil,cha,row,col].item()
                hex_value = f'{weight_value & 0xFF:02x}' 
                weight_matrix.append(hex_value)
                
    # Concatenate all hex values into a single string for this filter
    weight_matrix.reverse()
    concatenated_hex = ''.join(weight_matrix)
    weight_arr.append(concatenated_hex)

#print(weight_arr)

# Write the output to a text file
#with open("./weights/conv1_weight_sw.txt", "w") as file:
#    for hex_string in weight_arr:
#        file.write(hex_string + '\n')  # Write each concatenated hex string on a new line
quantized_model.eval()
veri_path = 'C:\\Users\\Admin\\.cache\\kagglehub\\datasets\\meowmeowmeowmeowmeow\\gtsrb-german-traffic-sign\\versions\\1'
image_path = veri_path+'\\Test\\00000.png'
input_image = Image.open(image_path)

transform = transforms.Compose([
    transforms.Resize((32, 32)), 
    transforms.ToTensor(),
])

input_tensor = transform(input_image)
input_tensor = input_tensor.unsqueeze(0)


with torch.no_grad(): 
    outputs = model(input_tensor)

print(outputs['image'].shape)
img_matrix = []
img_arr = []
for row in range(outputs['image'].shape[2]):
    for col in range(outputs['image'].shape[3]):
        for cha in range(outputs['image'].shape[1]):
            img_value = outputs['image'].int_repr()[1,cha,row,col].item()
            img_value = f'{img_value & 0xFF:02x}' 
            img_arr.append(img_value)
        img_arr.reverse()
        concatenated_hex = ''.join(img_arr)
        img_matrix.append(concatenated_hex)
print(img_matrix)
        