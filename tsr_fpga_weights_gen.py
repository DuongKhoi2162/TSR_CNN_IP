from fixedpoint import FixedPoint
import argparse
import torch
import os
import numpy as np
from model_quantized.TSRNetQuantized import QuantizedTrafficSignModel_1
from model_quantized.quantize_utils import quantize_model
from train_data.get_loader import get_test_loader

def write_weights(model, weights_bin_path):
    kernel_list = []
    bias_list = []
    macc_coeff_list = []
    layer_scale_list = []
    last_layer = model.quant
    extend_coeff = []

    layers = [model.conv1,model.pool1,model.conv2,model.conv3,model.conv4,model.conv5,model.pool2,model.conv6,model.conv7,model.conv8,model.conv9,model.fc]
    #FIXME: MAY BE THE LAYER SHOULD NOT BE CALLED LIKE THIS
    for layer in layers:
        print(layer._get_name())
        if layer._get_name() == 'QuantizedConv2d':
            conv = layer

            # Kernel and bias
            kernel = conv.weight().detach()
            bias = conv.bias().detach()
            y_scale = conv.scale
            x_scale = last_layer.scale
            w_scale = kernel.q_scale()
            s_comb = w_scale*x_scale/y_scale
            for fil in range(conv.out_channels):
                single_kernel_list = []
                for row in range(conv.kernel_size[0]):
                    for col in range(conv.kernel_size[1]):
                        for cha in range(conv.in_channels):
                            kernel_list.append(kernel[fil, cha, row, col].int_repr())
                            single_kernel_list.append(kernel[fil, cha, row, col].int_repr())
                weight_sum = np.sum(single_kernel_list)
                bias_list.append(bias[fil] / y_scale  + (128 - 128*s_comb*weight_sum))
                weight_sum = 0 
            # MACC co-efficient

            macc_coeff_list.append(s_comb)
            # Layer scale
            if layer._get_name() == 'QuantizedConv2d':
                layer_scale_list.append(y_scale)

            last_layer = conv

        if layer._get_name() == 'QuantizedLinear':
            conv = layer

            # Kernel and bias
            kernel = conv.weight().detach()
            bias = conv.bias().detach()
            y_scale = conv.scale
            x_scale = last_layer.scale
            w_scale = kernel.q_scale()
            s_comb = x_scale * w_scale / y_scale
            for fil in range(conv.out_features):
                single_kernel_list = []
                for row in range(conv.in_features):
                    kernel_list.append(kernel[fil,row].int_repr())
                    single_kernel_list.append(kernel[fil,row].int_repr())
                weight_sum = np.sum(single_kernel_list)
                bias_list.append(bias[fil] / y_scale  + (128 - 128*s_comb*weight_sum))
                weight_sum = 0 

            # MACC co-efficient

            macc_coeff_list.append(s_comb)

            # Layer scale
            if layer._get_name() == 'Linear':
                layer_scale_list.append(y_scale)

            last_layer = conv
    print(
        f'Num kernel      : {len(kernel_list)}\n'
        f'Num bias        : {len(bias_list)}\n'
        f'Num macc_coeff  : {len(macc_coeff_list)}\n'
        f'Num layer_scale : {len(layer_scale_list)}\n'
        f'Total weights   : {len(kernel_list) + len(bias_list) + len(macc_coeff_list) + len(layer_scale_list)}'
    )

    # Write to file
    byte_array = bytearray()
    bias_qformat = {'m': 11, 'n': 5, 'signed': 1}
    scale_qformat = {'m': 1, 'n': 15, 'signed': 0}

    for val in kernel_list:
        byte_array.extend((val.item() & 0xffff).to_bytes(length=2, byteorder='little'))

    for val in bias_list:
        print(val)
        byte_array.extend((int(f'{FixedPoint(val, **bias_qformat):04x}', 16) & 0xffff).to_bytes(length=2, byteorder='little'))

    for val in macc_coeff_list + layer_scale_list:
    # Convert value to fixed-point using Q2.16 format
        fixed_val = int(f'{FixedPoint(val, **scale_qformat):04x}', 16)
    # Clamp the value to avoid overflow
        if fixed_val > 65535:
            fixed_val = 65535
        #print(fixed_val)
    # Convert to 2-byte little-endian format and extend the byte array
        byte_array.extend(fixed_val.to_bytes(length=2, byteorder='little'))

    # if (len(byte_array) / 2) % 2:
    #     print('byte_array is odd')
    #     byte_array.extend((0).to_bytes(length=2, byteorder='little'))

    with open(weights_bin_path, 'wb') as f:
        f.write(byte_array)

def get_arguments():
    parser = argparse.ArgumentParser()

    parser.add_argument('--weights_bin_path', type=str, default='./weights/tsr_fpga_weights_28_5.bin')
    parser.add_argument('--quantized_weights_path', type=str, default='./weights/quant_traffic_sign_model.pth')


    args = parser.parse_args()

    args.weights_bin_path = os.path.abspath(args.weights_bin_path)
    args.quantized_weights_path = os.path.abspath(args.quantized_weights_path)

    return args

def main():
    args = get_arguments()

    # Load quantized model
    print(f'[INFO] Loading quantized model from {args.quantized_weights_path}')
    #model = QuantizedTrafficSignModel()
    #model = quantize_model(model,get_test_loader())
    #model.load_state_dict(torch.load(args.quantized_weights_path), strict=False)
    #model = quantize_model(model, get_test_loader())
    #model.load_state_dict(torch.load(args.quantized_weights_path), strict = False)
    #print(model)
    # Write weights
    model = QuantizedTrafficSignModel_1()
    model = quantize_model(model, get_test_loader())
    model.load_state_dict(torch.load(args.quantized_weights_path), strict=False)
    print('[INFO] Writing weights...')
    write_weights(model, args.weights_bin_path)

    with open(args.quantized_weights_path, 'rb') as f:
        data = f.read()  # Read all binary data
        print(f"Read {len(data)} bytes from the binary file.")

if __name__ == '__main__':
    main()