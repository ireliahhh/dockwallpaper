/**
 * Dock 壁纸渲染引擎
 * 支持两种光感风格：
 *  - harmony「鸿蒙光感」：类鸿蒙 7.0 沉浸光感 —— 冷调通透玻璃、柔和环境光晕、细腻边缘光线勾勒
 *  - liquid「液态玻璃」：iOS 液态玻璃 —— 高亮边缘、玻璃内景深、彩色透光、顶部镜面反光
 * 同一引擎服务「实时桌面预览」（壁纸+图标+Dock）与「高清导出」（壁纸+Dock）。
 *
 * 说明：鸿蒙 7.0 (API 26) 官方沉浸光感接口 systemMaterial 仅用于运行时 UI 材质；
 * 壁纸图片上的光感由本引擎在 Canvas 中渲染。工程已按 API 26 预留升级空间。
 */
import { image } from '@kit.ImageKit';
import { effectKit } from '@kit.ArkGraphics2D';
import { DockConfig } from '../model/DockConfig';

/** 背景数据 */
export interface BackgroundData {
  pixelMap: image.PixelMap | undefined;
  imgW: number;
  imgH: number;
  /** 是否为桌面截图预览模式：true 时不画模拟状态栏/图标，直接叠加光感 Dock */
  isScreenshot: boolean;
}

interface DockRect {
  x: number;
  y: number;
  width: number;
  height: number;
  radius: number;
}

/** 默认壁纸渐变背景（未选图时的占位） */
const DEFAULT_BG_TOP: string = '#141B3C';
const DEFAULT_BG_BOTTOM: string = '#221545';

/** 生成一张桌面预览图（壁纸 + 状态栏 + 图标网格 + 光感 Dock），返回 PixelMap */
export async function renderDesktopPreview(
  width: number,
  height: number,
  config: DockConfig,
  bg: BackgroundData
): Promise<image.PixelMap> {
  const offscreen: OffscreenCanvas = new OffscreenCanvas(width, height);
  const ctx: OffscreenCanvasRenderingContext2D = offscreen.getContext('2d');

  // 1. 绘制背景壁纸 / 桌面截图
  drawBackground(ctx, width, height, bg);

  // 2. 生成整图高斯模糊副本（玻璃透感用）
  let blurred: image.PixelMap | undefined = undefined;
  if (config.blur > 2) {
    const bgPixel: image.PixelMap = ctx.getPixelMap(0, 0, width, height);
    const filter = effectKit.createEffect(bgPixel);
    if (filter !== null) {
      filter.blur(config.blur);
      blurred = await filter.getEffectPixelMap();
    }
  }

  const dock: DockRect = computeDockRect(width, height, config);

  if (bg.isScreenshot) {
    // 桌面截图预览模式：保留截图中真实图标/壁纸，只叠加光感 Dock 玻璃
    drawDockGlass(ctx, dock, blurred, config, width, height);
  } else {
    // 普通模式：状态栏 + 模拟桌面图标网格 + 光感 Dock
    drawStatusBar(ctx, width);
    drawIconGrid(ctx, width, height);
    drawDockGlass(ctx, dock, blurred, config, width, height);
    drawDockIcons(ctx, dock, width);
  }

  return ctx.getPixelMap(0, 0, width, height);
}

/** 生成一张高清壁纸（仅背景 + 光感 Dock，不含图标），返回 PixelMap */
export async function renderWallpaper(
  width: number,
  height: number,
  config: DockConfig,
  bg: BackgroundData
): Promise<image.PixelMap> {
  const offscreen: OffscreenCanvas = new OffscreenCanvas(width, height);
  const ctx: OffscreenCanvasRenderingContext2D = offscreen.getContext('2d');

  drawBackground(ctx, width, height, bg);

  let blurred: image.PixelMap | undefined = undefined;
  if (config.blur > 2) {
    const bgPixel: image.PixelMap = ctx.getPixelMap(0, 0, width, height);
    const filter = effectKit.createEffect(bgPixel);
    if (filter !== null) {
      filter.blur(config.blur);
      blurred = await filter.getEffectPixelMap();
    }
  }

  const dock: DockRect = computeDockRect(width, height, config);
  drawDockGlass(ctx, dock, blurred, config, width, height);

  return ctx.getPixelMap(0, 0, width, height);
}

/** 绘制背景层 */
function drawBackground(ctx: OffscreenCanvasRenderingContext2D, width: number, height: number, bg: BackgroundData): void {
  if (bg.pixelMap !== undefined && bg.imgW > 0 && bg.imgH > 0) {
    drawCoverImage(ctx, bg.pixelMap, bg.imgW, bg.imgH, width, height);
    return;
  }
  const grad: CanvasGradient = ctx.createLinearGradient(0, 0, 0, height);
  grad.addColorStop(0, DEFAULT_BG_TOP);
  grad.addColorStop(1, DEFAULT_BG_BOTTOM);
  ctx.fillStyle = grad;
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

/** 状态栏：时间 + 信号 + 电量（仅预览用） */
function drawStatusBar(ctx: OffscreenCanvasRenderingContext2D, width: number): void {
  ctx.fillStyle = 'rgba(255,255,255,0.92)';
  ctx.font = '500 ' + Math.max(10, Math.round(width * 0.026)) + 'px sans-serif';
  ctx.textBaseline = 'middle';
  ctx.textAlign = 'left';
  ctx.fillText('9:41', width * 0.05, width * 0.075);
  ctx.textAlign = 'right';
  ctx.fillText('100%', width * 0.9, width * 0.075);
  // 信号条
  const cx: number = width * 0.84;
  const cy: number = width * 0.075;
  for (let i = 0; i < 4; i++) {
    ctx.fillStyle = 'rgba(255,255,255,0.9)';
    ctx.fillRect(cx + i * width * 0.018, cy + (3 - i) * width * 0.008, width * 0.012, (i + 1) * width * 0.008);
  }
}

/** 桌面图标网格（贴近鸿蒙默认桌面布局，仅预览用） */
function drawIconGrid(ctx: OffscreenCanvasRenderingContext2D, width: number, height: number): void {
  const cols: number = 4;
  const rows: number = 5;
  const gap: number = width * 0.05;
  const iconSize: number = width * 0.15;
  const startX: number = (width - (cols * iconSize + (cols - 1) * gap)) / 2;
  const topY: number = height * 0.15;
  const rowGap: number = width * 0.20;
  const glyphs: number[] = [0, 1, 2, 3];
  const names: string[][] = [
    ['相机', '图库', '联系人', '信息'],
    ['电话', '音乐', '日历', '时钟'],
    ['天气', '计算器', '设置', '邮件'],
    ['浏览器', '应用市场', '备忘录', '健康'],
    ['文件管理', '录音机', '主题', '钱包']
  ];
  const colors: string[][] = [
    ['#3E8EF7', '#7FB5FF'],
    ['#FF6B81', '#FFA3B3'],
    ['#2FC5A0', '#7BDFC2'],
    ['#FFB63F', '#FFD98F'],
    ['#9B6BFF', '#C2A1FF']
  ];
  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < cols; c++) {
      const x: number = startX + c * (iconSize + gap);
      const y: number = topY + r * rowGap;
      const g: number = glyphs[(r + c) % 4];
      const col: string[] = colors[(r + c) % 5];
      drawAppIcon(ctx, x, y, iconSize, g, col, width, names[r][c]);
    }
  }
}

/** 单个应用图标（圆角渐变方块 + 简单图形 + 真实名称） */
function drawAppIcon(
  ctx: OffscreenCanvasRenderingContext2D,
  x: number,
  y: number,
  size: number,
  glyph: number,
  col: string[],
  width: number,
  name: string
): void {
  const radius: number = size * 0.22;
  const grad: CanvasGradient = ctx.createLinearGradient(x, y, x + size, y + size);
  grad.addColorStop(0, col[0]);
  grad.addColorStop(1, col[1]);
  ctx.save();
  ctx.beginPath();
  roundRectPath(ctx, x, y, size, size, radius);
  ctx.fillStyle = grad;
  ctx.fill();
  // 顶部微光
  ctx.beginPath();
  roundRectPath(ctx, x, y, size, size, radius);
  const gloss: CanvasGradient = ctx.createLinearGradient(0, y, 0, y + size * 0.55);
  gloss.addColorStop(0, 'rgba(255,255,255,0.35)');
  gloss.addColorStop(1, 'rgba(255,255,255,0)');
  ctx.fillStyle = gloss;
  ctx.fill();
  // 简单图形
  ctx.fillStyle = 'rgba(255,255,255,0.9)';
  const gx: number = x + size / 2;
  const gy: number = y + size * 0.46;
  if (glyph === 0) {
    ctx.beginPath();
    ctx.arc(gx, gy, size * 0.16, 0, Math.PI * 2);
    ctx.fill();
  } else if (glyph === 1) {
    ctx.beginPath();
    ctx.arc(gx, gy, size * 0.16, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillRect(gx - size * 0.05, gy - size * 0.26, size * 0.1, size * 0.52);
  } else if (glyph === 2) {
    ctx.beginPath();
    ctx.arc(gx, gy, size * 0.18, 0, Math.PI * 2);
    ctx.fill();
  } else {
    ctx.beginPath();
    ctx.moveTo(gx, gy - size * 0.18);
    ctx.lineTo(gx + size * 0.18, gy + size * 0.16);
    ctx.lineTo(gx - size * 0.18, gy + size * 0.16);
    ctx.closePath();
    ctx.fill();
  }
  ctx.restore();
  // 名称
  ctx.fillStyle = 'rgba(255,255,255,0.92)';
  ctx.font = '400 ' + Math.max(8, Math.round(width * 0.021)) + 'px sans-serif';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'top';
  ctx.fillText(name, x + size / 2, y + size + width * 0.018);
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

/** 绘制光感 Dock 玻璃（按风格分支） */
function drawDockGlass(
  ctx: OffscreenCanvasRenderingContext2D,
  dock: DockRect,
  blurred: image.PixelMap | undefined,
  config: DockConfig,
  fullW: number,
  fullH: number
): void {
  if (config.style === 'liquid') {
    drawLiquidDock(ctx, dock, blurred, config, fullW, fullH);
  } else {
    drawHarmonyDock(ctx, dock, blurred, config, fullW, fullH);
  }
}

/** Dock 悬浮投影（dock 下方柔和深色阴影，增强悬浮感） */
function drawDockShadow(ctx: OffscreenCanvasRenderingContext2D, dock: DockRect, color: string, strength: number): void {
  const shH: number = dock.height * 0.85;
  const grad: CanvasGradient = ctx.createLinearGradient(0, dock.y + dock.height, 0, dock.y + dock.height + shH);
  grad.addColorStop(0, withAlpha(color, 0.34 * strength));
  grad.addColorStop(0.5, withAlpha(color, 0.12 * strength));
  grad.addColorStop(1, withAlpha(color, 0));
  ctx.fillStyle = grad;
  ctx.fillRect(dock.x - 5, dock.y + dock.height, dock.width + 10, shH);
}

/** 鸿蒙光感 Dock：通透冷调玻璃 + 悬浮投影 + 环境光晕 + 细腻双层光边 */
function drawHarmonyDock(
  ctx: OffscreenCanvasRenderingContext2D,
  dock: DockRect,
  blurred: image.PixelMap | undefined,
  config: DockConfig,
  fullW: number,
  fullH: number
): void {
  // 0. 悬浮投影
  drawDockShadow(ctx, dock, '#0A1026', 0.9);

  // 1. 背后环境光晕（柔和冷蓝扩散）
  const auraR: number = dock.width * 0.66;
  const aura: CanvasGradient = ctx.createRadialGradient(
    dock.x + dock.width / 2, dock.y + dock.height / 2, dock.width * 0.1,
    dock.x + dock.width / 2, dock.y + dock.height / 2, auraR
  );
  aura.addColorStop(0, withAlpha('#BFD4FF', 0.34 * config.glow));
  aura.addColorStop(0.6, withAlpha('#BFD4FF', 0.13 * config.glow));
  aura.addColorStop(1, withAlpha('#BFD4FF', 0));
  ctx.fillStyle = aura;
  ctx.fillRect(dock.x - auraR, dock.y - auraR, dock.width + auraR * 2, dock.height + auraR * 2);

  // 2. 玻璃主体
  ctx.save();
  ctx.beginPath();
  roundRectPath(ctx, dock.x, dock.y, dock.width, dock.height, dock.radius);
  ctx.clip();

  if (blurred !== undefined) {
    ctx.drawImage(blurred, 0, 0, fullW, fullH);
  }

  // 冷调玻璃基色（上浅下深，通透）
  const base: CanvasGradient = ctx.createLinearGradient(0, dock.y, 0, dock.y + dock.height);
  base.addColorStop(0, withAlpha('#EEF3FF', Math.min(0.9, config.opacity + 0.22)));
  base.addColorStop(1, withAlpha('#D3DDF7', config.opacity + 0.05));
  ctx.fillStyle = base;
  ctx.fillRect(dock.x, dock.y, dock.width, dock.height);

  // 顶部宽高光（顶部发光，向下渐隐）
  const hlH: number = dock.height * 0.55;
  const hlGrad: CanvasGradient = ctx.createLinearGradient(0, dock.y, 0, dock.y + hlH);
  hlGrad.addColorStop(0, withAlpha('#FFFFFF', 0.5 * config.highlight));
  hlGrad.addColorStop(0.4, withAlpha('#FFFFFF', 0.14 * config.highlight));
  hlGrad.addColorStop(1, withAlpha('#FFFFFF', 0));
  ctx.fillStyle = hlGrad;
  ctx.fillRect(dock.x, dock.y, dock.width, hlH);

  // 底部内暗角（景深）
  const shadeH: number = dock.height * 0.5;
  const shadeGrad: CanvasGradient = ctx.createLinearGradient(0, dock.y + dock.height - shadeH, 0, dock.y + dock.height);
  shadeGrad.addColorStop(0, withAlpha('#0A1026', 0));
  shadeGrad.addColorStop(1, withAlpha('#0A1026', 0.16));
  ctx.fillStyle = shadeGrad;
  ctx.fillRect(dock.x, dock.y + dock.height - shadeH, dock.width, shadeH);

  ctx.restore();

  // 3. 玻璃边缘：外层柔和白描边 + 内层细亮描边（厚度感）
  ctx.save();
  ctx.beginPath();
  roundRectPath(ctx, dock.x, dock.y, dock.width, dock.height, dock.radius);
  ctx.strokeStyle = withAlpha('#FFFFFF', 0.30 * config.glow);
  ctx.lineWidth = Math.max(1, dock.height * 0.010);
  ctx.stroke();
  ctx.restore();

  ctx.save();
  ctx.beginPath();
  roundRectPath(ctx, dock.x + 0.5, dock.y + 0.5, dock.width - 1, dock.height - 1, Math.max(0, dock.radius - 1));
  ctx.strokeStyle = withAlpha('#FFFFFF', 0.12);
  ctx.lineWidth = 1;
  ctx.stroke();
  ctx.restore();
}

/** 液态玻璃 Dock：高亮镜面反光 + 通透透光 + 立体边缘 + 标志性顶光 */
function drawLiquidDock(
  ctx: OffscreenCanvasRenderingContext2D,
  dock: DockRect,
  blurred: image.PixelMap | undefined,
  config: DockConfig,
  fullW: number,
  fullH: number
): void {
  // 0. 悬浮投影
  drawDockShadow(ctx, dock, '#05070F', 0.95);

  // 1. 玻璃主体
  ctx.save();
  ctx.beginPath();
  roundRectPath(ctx, dock.x, dock.y, dock.width, dock.height, dock.radius);
  ctx.clip();

  if (blurred !== undefined) {
    ctx.drawImage(blurred, 0, 0, fullW, fullH);
  }

  // 透光基色（微带冷白，保留背景透出）
  ctx.fillStyle = withAlpha('#F8FAFF', Math.max(0.10, config.opacity - 0.06));
  ctx.fillRect(dock.x, dock.y, dock.width, dock.height);

  // 镜面斜向反光（左上→右下高光带，液态玻璃标志）
  const sheen: CanvasGradient = ctx.createLinearGradient(dock.x, dock.y, dock.x + dock.width, dock.y + dock.height);
  sheen.addColorStop(0, withAlpha('#FFFFFF', 0.62 * config.highlight));
  sheen.addColorStop(0.16, withAlpha('#FFFFFF', 0.28 * config.highlight));
  sheen.addColorStop(0.45, withAlpha('#FFFFFF', 0.02 * config.highlight));
  sheen.addColorStop(0.78, withAlpha('#FFFFFF', 0.10 * config.highlight));
  sheen.addColorStop(1, withAlpha('#FFFFFF', 0.02 * config.highlight));
  ctx.fillStyle = sheen;
  ctx.fillRect(dock.x, dock.y, dock.width, dock.height);

  // 顶部高光渐变
  const hlH: number = dock.height * 0.5;
  const hlGrad: CanvasGradient = ctx.createLinearGradient(0, dock.y, 0, dock.y + hlH);
  hlGrad.addColorStop(0, withAlpha('#FFFFFF', 0.45 * config.highlight));
  hlGrad.addColorStop(1, withAlpha('#FFFFFF', 0));
  ctx.fillStyle = hlGrad;
  ctx.fillRect(dock.x, dock.y, dock.width, hlH);

  // 底部内景深（深色收口）
  const shadeH: number = dock.height * 0.55;
  const shadeGrad: CanvasGradient = ctx.createLinearGradient(0, dock.y + dock.height - shadeH, 0, dock.y + dock.height);
  shadeGrad.addColorStop(0, withAlpha('#10142A', 0));
  shadeGrad.addColorStop(1, withAlpha('#10142A', 0.32));
  ctx.fillStyle = shadeGrad;
  ctx.fillRect(dock.x, dock.y + dock.height - shadeH, dock.width, shadeH);

  ctx.restore();

  // 2. 边缘：外层高亮白描边 + 内层暗描边（立体玻璃厚度）
  ctx.save();
  ctx.beginPath();
  roundRectPath(ctx, dock.x, dock.y, dock.width, dock.height, dock.radius);
  ctx.strokeStyle = withAlpha('#FFFFFF', 0.42);
  ctx.lineWidth = Math.max(1, dock.height * 0.010);
  ctx.stroke();
  ctx.restore();

  ctx.save();
  ctx.beginPath();
  roundRectPath(ctx, dock.x + 0.5, dock.y + 0.5, dock.width - 1, dock.height - 1, Math.max(0, dock.radius - 1));
  ctx.strokeStyle = withAlpha('#10142A', 0.20);
  ctx.lineWidth = 1;
  ctx.stroke();
  ctx.restore();

  // 3. 顶部标志性光边（细而亮，下方柔和渐隐）
  ctx.save();
  ctx.beginPath();
  ctx.moveTo(dock.x + dock.radius, dock.y);
  ctx.lineTo(dock.x + dock.width - dock.radius, dock.y);
  ctx.strokeStyle = withAlpha('#FFFFFF', 0.60 * config.highlight);
  ctx.lineWidth = 1;
  ctx.stroke();
  ctx.restore();

  // 4. 底部外柔光（光晕）
  if (config.glow > 0.01) {
    const glowH: number = dock.height * 0.8;
    const glowGrad: CanvasGradient = ctx.createLinearGradient(0, dock.y + dock.height, 0, dock.y + dock.height + glowH);
    glowGrad.addColorStop(0, withAlpha('#FFFFFF', 0.32 * config.glow));
    glowGrad.addColorStop(1, withAlpha('#FFFFFF', 0));
    ctx.fillStyle = glowGrad;
    ctx.fillRect(dock.x, dock.y + dock.height, dock.width, glowH);
  }
}

/** 在 Dock 上绘制一排应用图标（图标大小固定，不随 Dock 高度变化） */
function drawDockIcons(ctx: OffscreenCanvasRenderingContext2D, dock: DockRect, width: number): void {
  const count: number = 5;
  // 图标固定大小（约占屏宽 7.5%），Dock 变高只增加留白，图标不变
  const iconSize: number = Math.min(width * 0.075, dock.height * 0.60);
  const gap: number = width * 0.03;
  const total: number = count * iconSize + (count - 1) * gap;
  const startX: number = dock.x + (dock.width - total) / 2;
  const y: number = dock.y + (dock.height - iconSize) / 2;
  const names: string[] = ['电话', '信息', '相机', '浏览器', '设置'];
  const colors: string[][] = [
    ['#3E8EF7', '#7FB5FF'],
    ['#2FC5A0', '#7BDFC2'],
    ['#FF6B81', '#FFA3B3'],
    ['#FFB63F', '#FFD98F'],
    ['#9B6BFF', '#C2A1FF']
  ];
  for (let i = 0; i < count; i++) {
    const x: number = startX + i * (iconSize + gap);
    const col: string[] = colors[i % 5];
    drawAppIcon(ctx, x, y, iconSize, i % 4, col, width, names[i]);
  }
}

/** 构建圆角矩形路径 */
function roundRectPath(ctx: OffscreenCanvasRenderingContext2D, x: number, y: number, w: number, h: number, r: number): void {
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
