# Mediatek external kernel modules

> [!NOTE]
> Imported from `SM-A226B/Platform.tar.gz/vendor/mediatek/kernel_modules/connectivity`
>
> Supported platform: `MT6833` & `MT6853`

> [!WARNING]
> This driver is intended only for 4.14.x. Not for 4.9.x and below or 4.19.x and above.

# Mediatek required configurations
**Make sure to enable this in your kernel defconfig!**
```
CONFIG_MTK_COMBO_BT=y
CONFIG_MTK_COMBO_WIFI=y
CONFIG_MTK_COMBO_GPS=y
CONFIG_MTK_GPS_SUPPORT=y
CONFIG_MTK_FMRADIO=y
```

# How to use
```
rm -rf ${KERNEL_DIR}/drivers/misc/mediatek/connectivity && git clone https://github.com/rufnx/mtk_module_connectivity.git ${KERNEL_DIR}/drivers/misc/mediatek/connectivity
```
# Bootloop issue
Bootloops can be caused by the drivers in `/vendor/lib/modules/*.ko` conflicting with drivers inline. Removing `/vendor/lib/modules/` can solve it.
