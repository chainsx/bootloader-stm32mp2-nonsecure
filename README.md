```
bash build-fip.sh
```

```
dd if=/dev/zero of=bootloader.img bs=1M count=8
parted -s bootloader.img mktable gpt
echo "2048,2048" | sfdisk --no-reread --append bootloader.img
sgdisk -c 2:"fsbla" "$2"
echo "4096,8192" | sfdisk --no-reread --append bootloader.img
sgdisk -c 3:"fip" "$2"
echo "12288,2048" | sfdisk --no-reread --append bootloader.img
sgdisk -c 4:"u-boot-env" bootloader.img
	

dd if="tf-a-sdcard.stm32" of=bootloader.img bs=512 seek=2048 conv=notrunc
dd if="fip.bin" of=bootloader.img bs=512 seek=4096 conv=notrunc
```


