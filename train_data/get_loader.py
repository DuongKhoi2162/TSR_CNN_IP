import pandas as pd 
import numpy as np
import cv2
import os
from torch.utils.data import DataLoader, Dataset
import torchvision.transforms as transforms

class TrafficSignDataset(Dataset):
    def __init__(self, images, labels, transform=None):
        self.images = images
        self.labels = labels
        self.transform = transform

    def __len__(self):
        return len(self.images)

    def __getitem__(self, idx):
        image = self.images[idx]
        label = self.labels[idx]
        if self.transform:
            image = self.transform(image)
        return image, label
    


def get_test_loader():
    veri_path = 'C:\\Users\\lckd2\\.cache\\kagglehub\\datasets\\meowmeowmeowmeowmeow\\gtsrb-german-traffic-sign\\versions\\1'
    train_path = os.path.join(veri_path, 'Train')
    number_of_class = len(os.listdir(train_path))
    transform = transforms.Compose([
        transforms.ToTensor(),
        transforms.Normalize((0.5, 0.5, 0.5), (0.5, 0.5, 0.5))
    ])
    test = pd.read_csv(veri_path+'\\Test.csv')
    imgs = test["Path"].values
    classIds = test["ClassId"].values
    test_images = []

    for img in imgs:
        image = cv2.imread(os.path.join(veri_path, img))
        image = cv2.resize(image, (32, 32))
        test_images.append(image)

    X_test = np.array(test_images)
    y_test = np.eye(number_of_class)[classIds]
    test_dataset = TrafficSignDataset(X_test, y_test, transform)
    test_loader = DataLoader(test_dataset, batch_size=32, shuffle=False)
    return test_loader