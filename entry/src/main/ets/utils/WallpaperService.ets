/**
 * 壁纸输出服务：打包、保存到相册、设为系统壁纸
 */
import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { wallpaper } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = 'DockWallpaper';

/** 将 PixelMap 打包为图片文件，返回文件路径 */
export async function packToFile(
  context: common.UIAbilityContext,
  pixelMap: image.PixelMap,
  dir: string,
  name: string,
  format: string
): Promise<string> {
  const filePath: string = `${dir}/${name}`;
  const packer: image.ImagePacker = image.createImagePacker();
  const packingOption: image.PackingOption = { format: format, quality: 100 };
  const data: ArrayBuffer = packer.packingSync(pixelMap, packingOption);
  const file = fs.openSync(filePath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
  fs.writeSync(file.fd, data);
  fs.closeSync(file);
  return filePath;
}

/** 保存壁纸到相册（需 WRITE_IMAGEVIDEO 权限） */
export async function saveWallpaperToAlbum(
  context: common.UIAbilityContext,
  pixelMap: image.PixelMap
): Promise<string> {
  // 1. 打包到缓存文件
  const cachePath: string = `${context.cacheDir}/wallpaper_export_${Date.now()}.jpg`;
  const packer: image.ImagePacker = image.createImagePacker();
  const packingOption: image.PackingOption = { format: 'image/jpeg', quality: 96 };
  const data: ArrayBuffer = packer.packingSync(pixelMap, packingOption);
  const tmpFile = fs.openSync(cachePath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
  fs.writeSync(tmpFile.fd, data);
  fs.closeSync(tmpFile);

  // 2. 创建相册资源并写入
  const phAccessHelper: photoAccessHelper.PhotoAccessHelper = photoAccessHelper.getPhotoAccessHelper(context);
  const uri: string = await phAccessHelper.createAsset(photoAccessHelper.PhotoType.IMAGE, 'jpg');
  const srcFile = fs.openSync(cachePath, fs.OpenMode.READ_ONLY);
  const destFile = fs.openSync(uri, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
  fs.copyFileSync(srcFile.fd, destFile.fd);
  fs.closeSync(srcFile);
  fs.closeSync(destFile);
  hilog.info(0x0000, TAG, 'saved to album: %{public}s', uri);
  return uri;
}

/** 设为系统桌面壁纸（SET_WALLPAPER 为系统级权限） */
export async function setAsWallpaper(
  context: common.UIAbilityContext,
  pixelMap: image.PixelMap
): Promise<void> {
  const pngPath: string = await packToFile(context, pixelMap, context.filesDir, 'wallpaper_set.png', 'image/png');
  await wallpaper.setWallpaper(pngPath, wallpaper.WallpaperType.WALLPAPER_SYSTEM);
  hilog.info(0x0000, TAG, 'wallpaper set done');
}
