from model.QuantLaneNet import QuantLaneNet
import torch
import torch.nn as nn
import torch.nn.functional as F
import os

if os.name == 'nt':
    # Windows
    torch.backends.quantized.engine = 'fbgemm'
else:
    # Linux
    torch.backends.quantized.engine = 'qnnpack'


class QuantizedTrafficSignModel(nn.Module):
    def __init__(self):
        super(QuantizedTrafficSignModel, self).__init__()

        # Quantization stubs
        self.quant = torch.quantization.QuantStub()
        self.dequant = torch.quantization.DeQuantStub()

        # Convolutional Layer 1
        self.conv1 = nn.Conv2d(in_channels=3, out_channels=40, kernel_size=(3, 3), padding=0)
        self.pool1 = nn.MaxPool2d(kernel_size=(2, 2))
        # Convolutional Layer 2
        self.conv2 = nn.Conv2d(in_channels=40, out_channels=20, kernel_size=(1, 1))
        self.conv3 = nn.Conv2d(in_channels=20, out_channels=48, kernel_size=(3, 3), padding=0)
        self.conv4 = nn.Conv2d(in_channels=48, out_channels=24, kernel_size=(1, 1))
        self.conv5 = nn.Conv2d(in_channels=24, out_channels=48, kernel_size=(3, 3), padding=0)

        # Pooling Layer 2
        self.pool2 = nn.MaxPool2d(kernel_size=(2, 2))

        # Affine Layer
        self.conv6 = nn.Conv2d(in_channels=48, out_channels=24, kernel_size=(1, 1))
        self.conv7 = nn.Conv2d(in_channels=24, out_channels=48, kernel_size=(3, 3), padding=0)
        self.conv8 = nn.Conv2d(in_channels=48, out_channels=32, kernel_size=(1, 1))
        self.conv9 = nn.Conv2d(in_channels=32, out_channels=64, kernel_size=(3, 3), padding=0)
        self.dropout = nn.Dropout(0.15)

        # Output Layer
        self.fc = nn.Linear(64 * 1 * 1, 43)

    def forward(self, x):
        # Quantize the input
        x = self.quant(x)

        # Forward pass through the layers
        x = F.relu(self.conv1(x))
        x = self.pool1(x)

        x = self.conv2(x)
        x = self.conv3(x)
        x = self.conv4(x)
        x = F.relu(self.conv5(x))

        x = self.pool2(x)

        x = self.conv6(x)
        x = self.conv7(x)
        x = self.conv8(x)
        x = F.relu(self.conv9(x))

        x = self.dropout(x)
        x = x.view(-1, 64 * 1 * 1)  # Flatten the tensor
        x = self.fc(x)

        # Dequantize the output
        x = self.dequant(x)

        return F.log_softmax(x, dim=1)
    
class QuantizedTrafficSignModel_1(nn.Module):
    def __init__(self):
        super(QuantizedTrafficSignModel_1, self).__init__()

        # Quantization stubs
        self.quant = torch.quantization.QuantStub()
        self.dequant = torch.quantization.DeQuantStub()

        # Convolutional Layer 1
        self.conv1 = nn.Conv2d(in_channels=3, out_channels=40, kernel_size=(3, 3), padding=(0,0), stride=(1,1), dilation=(1,1))
        self.pool1 = nn.MaxPool2d(kernel_size=(2, 2), stride = (2,2), padding=(0,0), dilation = (1,1))

        # Convolutional Layer 2
        self.conv2 = nn.Conv2d(in_channels=40, out_channels=20, kernel_size=(1, 1), padding=(0,0), stride=(1,1), dilation=(1,1))
        self.conv3 = nn.Conv2d(in_channels=20, out_channels=48, kernel_size=(3, 3), padding=(0,0), stride=(1,1), dilation=(1,1))
        self.conv4 = nn.Conv2d(in_channels=48, out_channels=24, kernel_size=(1, 1), padding=(0,0), stride=(1,1), dilation=(1,1))
        self.conv5 = nn.Conv2d(in_channels=24, out_channels=48, kernel_size=(3, 3), padding=(0,0), stride=(1,1), dilation=(1,1))

        # Pooling Layer 2
        self.pool2 = nn.MaxPool2d(kernel_size=(2, 2), padding=(0,0), stride=(2,2), dilation=(1,1))

        # Affine Layer
        self.conv6 = nn.Conv2d(in_channels=48, out_channels=24, kernel_size=(1, 1), padding=(0,0), stride=(1,1), dilation=(1,1))
        self.conv7 = nn.Conv2d(in_channels=24, out_channels=48, kernel_size=(3, 3), padding=(0,0), stride=(1,1), dilation=(1,1))
        self.conv8 = nn.Conv2d(in_channels=48, out_channels=32, kernel_size=(1, 1), padding=(0,0), stride=(1,1), dilation=(1,1))
        self.conv9 = nn.Conv2d(in_channels=32, out_channels=64, kernel_size=(3, 3), padding=(0,0), stride=(1,1), dilation=(1,1))
        self.dropout = nn.Dropout(0.15)

        # Output Layer
        self.fc = nn.Linear(64 * 1 * 1, 43)

    def forward(self, x):
        outputs = {}
        outputs['input'] = x
        # Quantize the input
        x = self.quant(x)
        outputs['image'] = x
        x = F.relu(self.conv1(x))
        outputs['conv1'] = x
        x = self.pool1(x)
        outputs['pool1'] = x

        x = self.conv2(x)
        outputs['conv2'] = x
        x = self.conv3(x)
        outputs['conv3'] = x
        x = self.conv4(x)
        outputs['conv4'] = x
        x = F.relu(self.conv5(x))
        outputs['conv5'] = x

        x = self.pool2(x)
        outputs['pool2'] = x

        x = self.conv6(x)
        outputs['conv6'] = x
        x = self.conv7(x)
        outputs['conv7'] = x
        x = self.conv8(x)
        outputs['conv8'] = x
        x = F.relu(self.conv9(x))
        outputs['conv9'] = x

        x = self.dropout(x)
        x = x.view(-1, 64 * 1 * 1)  # Flatten the tensor
        outputs['flatten'] = x
        x = self.fc(x)
        outputs['fc'] = x

        # Dequantize the output
        x = self.dequant(x)
        outputs['output'] = F.log_softmax(x, dim=1)

        return outputs