# Summary
When the Home Menu is starting up, it can load theme-data from the home-menu theme SD extdata. The flaw can be triggered from here. The ROP starts running at roughly the same time the LCD backlight gets turned on.

Although this triggers during Home Menu boot, this can't cause any true bricks: just remove the *SD card if any booting issues ever occur(or delete/rename the theme-cache extdata directory: http://3dbrew.org/wiki/Extdata). Note that this also applies when the ROP causes a crash, like when the ROP is for a different version of Home Menu(this can also happen if you boot into a nandimage which has a different Home Menu version, but still uses the exact same SD data). In some(?) cases Home Menu crashes with this just result in Home Menu displaying the usual error dialog for system-applet crashes.

# Vuln
This was discovered on December 22, 2014.

Home Menu allocates a 0x2a0000-byte heap buffer using the ctrsdk heap code: offset 0x0 size 0x150000 is for the output decompressed data, offset 0x150000 size 0x150000 is for the input compressed data. Immediately after this buffer is a CTRSDK heap freemem memchunkhdr, successfully overwriting it results a crash(when the data written there is junk) in the CTRSDK heap memchunk handling code with the linked-lists.

The decompression code only has an input-size parameter, no output size parameter. Hence, the output size is not restricted/checked at all. Since the decompressed data is located before the compressed data, the buf overflow results in the input compressed data being overwritten first. Eventually this overflow will result in the input data actually being used by the decompression function being overwritten, which can later result in an error before the function ever writes to the CTRSDK memchunk-hdr(if the input compressed data doesn't workaround that).

## 10.2.0-X sysupdate
This update fixed the vuln with theme decompression.

The Home Menu code changes *just* added a "if(decompressed_size_from_lzheader > 0x150000){exit};" check after loading a theme, prior to decompression.

# Supported System Versions
* v9.0
* v9.1j
* v9.2
* v9.3
* v9.4
* v9.5
* v9.6
* v9.7
* All homemenu versions with this vuln where the ropgadget-finder successfully finds the required addresses, unless structs involved with the initial ROP-chain change etc.

Due to an issue with APT, the <=v1.2 installer will fail to find the .lz for the following system-versions, due to using the wrong Home Menu title-version. This is fixed in latest git, there should be an updated release-archive for this later.
* v9.3
* v9.6
* v9.7

This flaw was introduced with the Home Menu version which added support for themes: 9.0.0-X on Old3DS, v8.1 on New3DS. Old3DS JPN theme support was "added" 9.1.0-XJ. The lowest system-version supported by exploit is v9.0.

Every version starting with v9.0 is supported unless mentioned otherwise, system-versions starting with 10.2.0-X are not supported(see above).

The initial release archive only supported USA, EUR, and JPN. The latest git also supports KOR, which should be included in the next release. TWN can't be supported currently. CHN isn't supported since the last Home Menu update(v7.0) was before themes even existed in Home Menu.

# Building
Just run "make defaultbuild", or even "make clean && make defaultbuild". For building ROP binaries  which can be used for general homemenu ROP, this can be used: "{make clean &&} make ropbins {options}". "make bins {options}" is the same as "make", except building the .lz is skipped. "defaultbuild" Builds with the default options, see the Makefile for the default options. "{...} make {options}" Can be used to build with your own options if you prefer.

If you don't want to use the prebuilt menurop(using the menurop_prebuilt is recommended), the menurop directories+files must be generated. "./generate_menurop_addrs.sh {path}". See the source of that script for details(this requires the Home Menu code-binaries).

The built files for BodyCache.bin/Body_LZ.bin are located under "themepayload/".

Note that the compression done in .py is rather slow: this is why building all versions and such takes a while.

Build options:
* "ENABLE_RET2MENU=1" Just return from the haxx to the Home Menu code after writing to the framebufs.
* "CODEBINPAYLOAD=path" Code binary payload to load into the launched process(default is the system web-browser). This will be included in the theme-data itself.
* "LOADSDPAYLOAD=1" Enable loading a code binary from SD for loading into the launched process("/menuhax_payload.bin"). The total size of the code(including additional code prior to the binary from SD) loaded into the process is 0x4000-bytes. Therefore, the max size of the code binary from SD is a bit less than 0x3000-bytes.
* "BOOTGAMECARD=1" Reboot the system via NSS:RebootSystem to launch the gamecard(region-free). This is handled right after the ROP for LOADROPBIN, if that's even enabled. If GAMECARD_PADCHECK isn't used, the ROP will always execute this without executing the title-launch + takeover ROP.
* "USE_PADCHECK=val" When set, at the very start of the menu ROP it will check if the current HID PAD state is set to the specified value. When they match, it continues the ROP, otherwise it returns to the homemenu code. This is done before writing to the framebuffers.
* "LOADSDCFG_PADCHECK=1" When USE_PADCHECK was used, load a config file which overrides the value used for USE_PADCHECK, and can invert PADCHECK too if specified(see source code for details).
* "GAMECARD_PADCHECK=val" Similar to USE_PADCHECK except for BOOTGAMECARD: the BOOTGAMECARD ROP only gets executed when the specified HID PAD state matches the current one. After writing to framebufs the ROP will delay 3 seconds, then run this PADCHECK ROP.
* "EXITMENU=1" Terminate homemenu X seconds(see source) after getting code exec under the launched process.
* "ENABLE_LOADROPBIN=1" Load a homemenu ropbin then stack-pivot to it, see the Makefile HEAPBUF_ROPBIN_* values for the load-address. When LOADSDPAYLOAD isn't used, the binary is the one specified by CODEBINPAYLOAD, otherwise it's loaded from "sd:/menuhax_ropbinpayload.bin". The binary size should be <=0x10000-bytes.
* "ENABLE_HBLAUNCHER=1" When used with ENABLE_LOADROPBIN, setup the additional data needed by the hblauncher payload.
* "MENUROP_PATH={path}" Use the specified path for the "menurop" directory, instead of the default one which requires running generate_menurop_addrs.sh. To use the prebuilt menurop headers included with this repo, the following can be used: "MENUROP_PATH=menurop_prebuilt".
* "THEMEDATA_PATH={*decompressed* regular theme body_LZ filepath}" Build hax with the specified theme, instead of using the "default theme" one. Also note that compression during building takes a *lot* longer with this. This option is *not* recommended, use the LOADOTHER_THEMEDATA option instead.
* "LOADOTHER_THEMEDATA=1" When doing RET2MENU, re-run the theme-loading Home Menu code with different extdata file-paths(BGM file-paths are not changed). This allows loading actual themes while menuhax is installed.
* "ENABLE_IMAGEDISPLAY=1" Instead of doing a DMA-copy to the top-screen framebuffers from other data in VRAM resulting in junk being displayed, DMA from data in this payload. Framebuffer format is the same as usual: 240x400 byte-swapped RGB8(http://3dbrew.org/wiki/GPU/External_Registers#Framebuffer_color_formats). If 3D stereoscopy isn't used by the image, the 3D-right image should be the same as the 3D-left. The original "data in this payload" is just the end of the payload, with the data copied from VRAM+0(which is where the framebuf data comes from when ENABLE_IMAGEDISPLAY isn't used).
* "ENABLE_IMAGEDISPLAY_SD=1" Only used if ENABLE_IMAGEDISPLAY was specified. Overwrite the raw image-display data in the payload, with the data from SD "/menuhax_imagedisplay.bin", if the data from SD is loaded successfully. The format is the same described above. The first 0x46500-bytes are for the 3D-left, the 0x46500-bytes after that are for the 3D-right. The size of this file on SD should be 0x8ca00-bytes(0x46500*2), but if it's smaller only part of the image-data in this payload will be overwritten. Note that the manager app includes functionality for handling this file.

Building the menuhax_manager app requires zlib, handled the same way as hbmenu. Lodepng(https://github.com/lvandeve/lodepng) is also required: you must manually create a "menuhax_manager/lodepng/" directory, which contains the following(these can be symlinks for example): "lodepng.c" and "lodepng.h".

# Usage
Just boot the system, the haxx will automatically trigger when Home Menu loads the theme-data from the cache in SD extdata. The ROP right after the ROP for USE_PADCHECK, if that's even enabled, will overwrite the main-screen framebuffers with data from elsewhere.

When the ROP returns from the haxx to running the actual Home Menu code, such as when USE_PADCHECK is used where the current PAD state doesn't match the specified state, Home Menu will use the "theme" data from this hax: the end result is that it appears to use the same theme as the default one(when the THEMEDATA_PATH build option wasn't used).

When built with ENABLE_LOADROPBIN=1, this can boot into the homebrew-launcher if the ropbin listed above is one for the homebrew-launcher and was pre-patched.

With the release archive, you have to hold down the L button while Home Menu is booting(at the time the ROP checks for it), in order to boot into the hblauncher payload. Otherwise, Home Menu will boot like normal. This is the default PAD-trigger configuration.

With the latest-git, the user can override the default PAD-trigger with multiple configuration options in the installer. The data for this is stored in SD file "/menuhax_padcfg.bin".

The latest-git ROP does the following:
* 1) Mount SD archive.
* 2) Check PAD, if it's enabled with USE_PADCHECK(which it is with the release archive).
* 3) Overwrite framebuffer data.
* 4) Run the actual main ROP.

# Installation
To install the exploit for booting hblauncher, you *must* use the menuhax_manager app. You must already have a way to boot into the hblauncher payload for running this app(which can include menuhax if it's already setup): http://3dbrew.org/wiki/Homebrew_Exploits    
Before using HTTP, the app will first try to load the payload(https://smealum.github.io/3ds/) from SD "/menuhaxmanager_input_payload.bin", then continue to use HTTP if loading from SD isn't successful. Actually using this SD payload is *not* recommended for end-users when HTTP download works fine.  

The latest-git uses a seperate menuropbin path for each menuhax build. <=v1.2 used the same filepath for all builds, rendering menuhax unusable for multiple system-versions/etc with the same SD card without changing that file(like with booting into SD-nandimages, for example).

This app uses code based on code from the following repos: https://github.com/yellows8/3ds_homemenu_extdatatool https://github.com/yellows8/3ds_browserhax_common  
This app includes the theme BGM copying code from 3ds_homemenu_extdatatool, but that BGM won't actually get used by Home Menu unless you build the exploit with the param related to that yourself.
Whenever the Home Menu version installed on your system changes where the installed exploit is for a different version, or when you want to update the hblauncher payload, you must run the installer again. For this you can do the following: you can remove the SD card before booting the system, then once booted insert the SD card then boot into the hblauncher payload via a different method(http://3dbrew.org/wiki/Homebrew_Exploits).

Besides the defaults, this app can setup a custom image for displaying on the main-screen when the menuhax triggers, if you use the app option for that. The input PNG for this is located at SD "/3ds/menuhax_manager/imagedisplay.png". The PNG dimensions must be either 800x240 or 240x800. The first half of the image(in terms of pixels) is for 3D-left, the rest is for the 3D-right. The 3D-right should be same as 3D-left if no stereoscopy is used by the image.

To "remove" the exploit, you can just select any theme in the Home Menu theme settings(such as one of the built-in color themes). If you want the default theme, you can then select that option again. See the "Summary" section if you have issues with Home Menu failing to boot.

If you *really* want to build a NCCH version of the installer, use the same permissions as 3ds_homemenu_extdatatool, with the same data on SD card as from the release archive. Access to the HTTPC service, and access to an AM service for AM_ListTitles, is required. Due to AM access being required with >v1.2, this app is not usable with ninjhax v1.x.

If you haven't already done so before, you may have to enter the Home Menu theme-settings so that Home Menu can create the theme extdata.

# Credits
* This vuln was, as said on this page(https://smealum.github.io/3ds/), "exploited jointly by yellows8 and smea". The payload.py script was written by smea, this is where the actual generation for the compressed data which triggers the buf-overflow is done.

