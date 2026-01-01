TARGET := iphone:clang:16.5:15.0
INSTALL_TARGET_PROCESSES = blackios

ARCHS = arm64

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = blackios
blackios_FILES = main.m blackAppDelegate.m blackRootViewController.m FileBrowserViewController.m TextEditorViewController.m AppListViewController.m AppIcon.m ImageViewerViewController.m FontViewerViewController.m SQLiteViewerViewController.m FilePropertiesViewController.m CreditsViewController.m PlistEditorViewController.m PlistItemCell.m Typography.m UserGroupSelectionViewController.m RootHelper.m TSUtil.m SettingsManager.m SettingsViewController.m LanguageSelectionViewController.m TrashViewController.m NSBundle+Language.m SSZipArchive/SSZipArchive.m SSZipArchive/minizip/mz_compat.c SSZipArchive/minizip/mz_crypt.c SSZipArchive/minizip/mz_crypt_apple.c SSZipArchive/minizip/mz_os.c SSZipArchive/minizip/mz_os_posix.c SSZipArchive/minizip/mz_strm.c SSZipArchive/minizip/mz_strm_buf.c SSZipArchive/minizip/mz_strm_mem.c SSZipArchive/minizip/mz_strm_os_posix.c SSZipArchive/minizip/mz_strm_pkcrypt.c SSZipArchive/minizip/mz_strm_split.c SSZipArchive/minizip/mz_strm_wzaes.c SSZipArchive/minizip/mz_strm_zlib.c SSZipArchive/minizip/mz_zip.c SSZipArchive/minizip/mz_zip_rw.c
blackios_FRAMEWORKS = UIKit Foundation CoreGraphics MobileCoreServices SpringBoardServices Security QuickLook
blackios_LIBRARIES = z iconv sqlite3
blackios_OBJCFLAGS = -fobjc-arc
blackios_CFLAGS = -DHAVE_INTTYPES_H -DHAVE_PKCRYPT -DHAVE_STDINT_H -DHAVE_WZAES -DHAVE_ZLIB -DZLIB_COMPAT -Wno-error=unused-but-set-variable
blackios__ENTITLEMENTS = blackios.entitlements
include $(THEOS_MAKE_PATH)/application.mk
