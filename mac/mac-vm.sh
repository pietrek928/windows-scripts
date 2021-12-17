#!/bin/bash
VBoxManage modifyvm "$1" --cpuidset 00000001 000106e5 00100800 0098e3fd bfebfbff
VBoxManage modifyvm "$1" --cpu-profile "Intel Core i7-6700K"
VBoxManage setextradata "$1" "VBoxInternal/Devices/efi/0/Config/DmiSystemProduct" "iMac19,1"
VBoxManage setextradata "$1" "VBoxInternal/Devices/efi/0/Config/DmiSystemVersion" "1.0"
VBoxManage setextradata "$1" "VBoxInternal/Devices/efi/0/Config/DmiBoardProduct" "Mac-AA95B1DDAB278B95"
VBoxManage setextradata "$1" "VBoxInternal/Devices/smc/0/Config/DeviceKey" "makbooczek(c)AppleComputerInc"
VBoxManage setextradata "$1" "VBoxInternal/Devices/smc/0/Config/GetKeyFromRealSMC" 1
