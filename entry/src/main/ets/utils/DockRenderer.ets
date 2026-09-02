/**
 * Dock 壁纸渲染引擎
 * 基于 OffscreenCanvas + effectKit 实现「沉浸光感」毛玻璃 Dock：
 *  - 背景（纯色 / 渐变 / 相册图）
 *  - 高斯模糊玻璃层（真实背景模糊）
 *  - 半透明玻璃基色
 *  - 顶部高光渐变（模拟玻璃边缘反光）
 *  - 底部柔光光晕
 * 同一引擎同时服务「实时预览」与「高清导出」。
 */
import { image } from '@kit.ImageKit';
import { effectKit } from '@kit.ArkGraphics2D';
import { DockConfig } from '../model/DockConfig';
import { GRADIENT_PRESETS } from '../common/Constants';

/** 背景数据 */
export interface BackgroundData {
  mode: 'color' | 'gradient' | 'album';
  color: string;
  gradientIndex: number;
  pixelMap: image.PixelMap | undefined;
  imgW: number;
  imgH: number;
}

interface DockRect {
  x: number;
  y: number;
  width: number;
  height: number;
  radius: number;
}

/** 生成一张 Dock 壁纸，返回 PixelMap */
export async function renderDockWallpaper(
  width: number,
  height: number,
  config: DockConfig,
  bg: BackgroundData
): Promise<image.PixelMap> {
  const offscreen: OffscreenCanvas = new OffscreenCanvas(width, height);
  const ctx: OffscreenCanvasRenderingContext2D = offscreen.getContext('2d');

  // 1. 绘制背景
  drawBackground(ctx, width, height, bg);

  // 2. 生成整图高斯模糊副本（用于玻璃透感）
  let blurred: image.PixelMap | undefined = undefined;
  if (config.blur > 2) {
    const bgPixel: image.PixelMap = ctx.getPixelMap(0, 0, width, height);
    const filter = effectKit.createEffect(bgPixel);
    if (filter !== null) {
      filter.blur(config.blur);
      blurred = await filter.getEffectPixelMap();
    }
  }

  // 3. 计算 Dock 区域并绘制玻璃光感
  const dock: DockRect = computeDockRect(width, height, config);
  drawDockGlass(ctx, dock, blurred, config, width, height);

  // 4. 返回结果位图
  return ctx.getPixelMap(0, 0, width, height);
}

/** 绘制背景层 */
function drawBackground(ctx: OffscreenCanvasRenderingContext2D, width: number, height: number, bg: BackgroundData): void {
  if (bg.mode === 'album' && bg.pixelMap !== undefined && bg.imgW > 0 && bg.imgH > 0) {
    drawCoverImage(ctx, bg.pixelMap, bg.imgW, bg.imgH, width, height);
    return;
  }
  if (bg.mode === 'gradient') {
    const stops: string[] = GRADIENT_PRESETS[bg.gradientIndex] !== undefined ? GRADIENT_PRESETS[bg.gradientIndex] : GRADIENT_PRESETS[0];
    const grad: CanvasGradient = ctx.createLinearGradient(0, 0, 0, height);
    grad.addColorStop(0, stops[0]);
    grad.addColorStop(1, stops[1]);
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, width, height);
    return;
  }
  ctx.fillStyle = bg.color;
  ctx.fillRect(0, 0, width, height);
}

/** 等比居中裁剪铺满背景 */
function drawCoverImage(
  ctx: OffscreenCanvasRenderingContext2D,
  pm: image.PixelMap,
  imgW: number,
  imgH: number,
  dw: number,
  dh: number
): void {
  const scale: number = Math.max(dw / imgW, dh / imgH);
  const sw: number = dw / scale;
  const sh: number = dh / scale;
  const sx: number = (imgW - sw) / 2;
  const sy: number = (imgH - sh) / 2;
  ctx.drawImage(pm, sx, sy, sw, sh, 0, 0, dw, dh);
}

/** 计算 Dock 圆角矩形区域 */
function computeDockRect(width: number, height: number, config: DockConfig): DockRect {
  const dockH: number = height * config.heightRatio;
  const side: number = width * config.sideRatio;
  const bottom: number = height * config.bottomRatio;
  return {
    x: side,
    y: height - bottom - dockH,
    width: width - side * 2,
    height: dockH,
    radius: dockH * config.cornerRatio
  };
}

/** 绘制毛玻璃 Dock 沉浸光感 */
function drawDockGlass(
  ctx: OffscreenCanvasRenderingContext2D,
  dock: DockRect,
  blurred: image.PixelMap | undefined,
  config: DockConfig,
  fullW: number,
  fullH: number
): void {
  // ---- 玻璃主体（裁剪在圆角内） ----
  ctx.save();
  ctx.beginPath();
  roundRect(ctx, dock.x, dock.y, dock.width, dock.height, dock.radius);
  ctx.clip();

  // 毛玻璃：将模糊后的背景绘制在 Dock 区域内
  if (blurred !== undefined) {
    ctx.drawImage(blurred, 0, 0, fullW, fullH);
  }

  // 玻璃基色
  ctx.fillStyle = withAlpha(config.glassColor, config.opacity);
  ctx.fillRect(dock.x, dock.y, dock.width, dock.height);

  // 顶部高光：模拟玻璃上缘反光（白色渐变）
  const hlH: number = dock.height * 0.38;
  const hlGrad: CanvasGradient = ctx.createLinearGradient(0, dock.y, 0, dock.y + hlH);
  hlGrad.addColorStop(0, withAlpha('#FFFFFF', 0.6 * config.highlight));
  hlGrad.addColorStop(1, withAlpha('#FFFFFF', 0));
  ctx.fillStyle = hlGrad;
  ctx.fillRect(dock.x, dock.y, dock.width, hlH);

  // 底部内侧暗角：增强通透景深
  const shadeH: number = dock.height * 0.45;
  const shadeGrad: CanvasGradient = ctx.createLinearGradient(0, dock.y + dock.height - shadeH, 0, dock.y + dock.height);
  shadeGrad.addColorStop(0, withAlpha('#000000', 0));
  shadeGrad.addColorStop(1, withAlpha('#000000', 0.16));
  ctx.fillStyle = shadeGrad;
  ctx.fillRect(dock.x, dock.y + dock.height - shadeH, dock.width, shadeH);

  ctx.restore();

  // ---- 圆角描边：精致边缘光感 ----
  if (config.glow > 0.01) {
    ctx.save();
    ctx.beginPath();
    roundRect(ctx, dock.x, dock.y, dock.width, dock.height, dock.radius);
    ctx.strokeStyle = withAlpha('#FFFFFF', 0.2 * config.glow);
    ctx.lineWidth = Math.max(1, dock.height * 0.012);
    ctx.stroke();
    ctx.restore();
  }

  // ---- 底部柔光光晕（沉浸光感核心） ----
  if (config.glow > 0.01) {
    const glowH: number = dock.height * 0.9;
    const glowColor: string = config.theme === 'dark' ? config.glassColor : '#FFFFFF';
    const glowGrad: CanvasGradient = ctx.createLinearGradient(0, dock.y + dock.height, 0, dock.y + dock.height + glowH);
    glowGrad.addColorStop(0, withAlpha(glowColor, 0.4 * config.glow));
    glowGrad.addColorStop(1, withAlpha(glowColor, 0));
    ctx.fillStyle = glowGrad;
    ctx.fillRect(dock.x, dock.y + dock.height, dock.width, glowH);
  }
}

/** 构建圆角矩形路径 */
function roundRect(ctx: OffscreenCanvasRenderingContext2D, x: number, y: number, w: number, h: number, r: number): void {
  const radius: number = Math.min(r, w / 2, h / 2);
  ctx.moveTo(x + radius, y);
  ctx.arcTo(x + w, y, x + w, y + h, radius);
  ctx.arcTo(x + w, y + h, x, y + h, radius);
  ctx.arcTo(x, y + h, x, y, radius);
  ctx.arcTo(x, y, x + w, y, radius);
  ctx.closePath();
}

/** 将 #RRGGBB 转为带透明度的 rgba 字符串 */
function withAlpha(hex: string, alpha: number): string {
  const a: number = Math.max(0, Math.min(1, alpha));
  const clean: string = hex.replace('#', '');
  let r: number = 255;
  let g: number = 255;
  let b: number = 255;
  if (clean.length >= 6) {
    r = parseInt(clean.substring(0, 2), 16);
    g = parseInt(clean.substring(2, 4), 16);
    b = parseInt(clean.substring(4, 6), 16);
  }
  return `rgba(${r}, ${g}, ${b}, ${a.toFixed(3)})`;
}
