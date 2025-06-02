from torch.quantization.observer import MovingAverageMinMaxObserver
import torch
import re

def convert_quantized_model(model):
    model.eval()

    # Get modules to fuse
    r = re.compile('(encoder_stage_[1-3].conv_[^.]+)|(.+_out\.[0-2])')
    conv_bn_relu_layers = set([m.group(0) for m in map(r.match, [name for name, _ in model.named_modules()]) if m])
    fuse_modules = [[f'{block}.{layer}' for layer in ('conv', 'bn', 'relu')] for block in conv_bn_relu_layers]

    # Prepare model for quantization
    model.qconfig = torch.quantization.QConfig(
        activation=MovingAverageMinMaxObserver.with_args(qscheme=torch.per_tensor_symmetric, dtype=torch.quint8),
        weight=MovingAverageMinMaxObserver.with_args(qscheme=torch.per_tensor_symmetric, dtype=torch.qint8)
    )
    model_fused = torch.quantization.fuse_modules(model, fuse_modules)
    model_prepared = torch.quantization.prepare(model_fused)
    model_prepared(torch.rand(size=(1, 3, 256, 512), device=('cuda' if next(model.parameters()).is_cuda else 'cpu')))

    return torch.quantization.convert(model_prepared)

def tsr_quantize_model(model):
    model.eval()
    model.qconfig = torch.quantization.QConfig(
        activation=MovingAverageMinMaxObserver.with_args(qscheme=torch.per_tensor_symmetric, dtype=torch.quint8),
        weight=MovingAverageMinMaxObserver.with_args(qscheme=torch.per_tensor_symmetric, dtype=torch.qint8)
    )
    model_prepared = torch.quantization.prepare(model)
    dummy_inp      = torch.randn(1,3,32,32)
    model_prepared(dummy_inp)
    model_quantized = torch.quantization.convert(model_prepared)
    return model_quantized

def quantize_model(model, data_loader):
    model.eval()
    model.qconfig = torch.quantization.QConfig(
        activation=MovingAverageMinMaxObserver.with_args(qscheme=torch.per_tensor_symmetric, dtype=torch.quint8),
        weight=MovingAverageMinMaxObserver.with_args(qscheme=torch.per_tensor_symmetric, dtype=torch.qint8)
    )
    print(model.qconfig)
    model_prepared = torch.quantization.prepare(model)
    with torch.no_grad():
        for images, _ in data_loader:
            model_prepared(images.float())
    
    model_quantized = torch.quantization.convert(model_prepared)
    return model_quantized

#model = QuantizedTrafficSignModel()
#model.load_state_dict(torch.load(checkpoint_path, map_location='cpu'))
#model.eval()

#quantized_model_final = quantize_model(model, test_loader)
#torch.save(quantized_model_final.state_dict(), 'traffic_sign_model_quantized_final.pth')
#print(quantized_model_final)
