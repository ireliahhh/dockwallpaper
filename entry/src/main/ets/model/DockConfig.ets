/**
 * Dock 壁纸配置模型
 * 所有尺寸均使用相对比例，方便在不同分辨率下复用
 */

/** 光感风格：harmony=鸿蒙光感，liquid=液态玻璃 */
export type DockStyle = 'harmony' | 'liquid';

export interface DockConfig {
  /** 光感风格 */
  style: DockStyle;
  /** Dock 高度（相对壁纸高度比例，0.10 - 0.22） */
  heightRatio: number;
  /** 左右留白（相对壁纸宽度比例，0.04 - 0.12） */
  sideRatio: number;
  /** 距底部距离（相对壁纸高度比例，0.02 - 0.08） */
  bottomRatio: number;
  /** 圆角（相对 Dock 高度的比例，0.2 - 0.5） */
  cornerRatio: number;
  /** 玻璃不透明度 0 - 1 */
  opacity: number;
  /** 毛玻璃模糊强度（像素） */
  blur: number;
  /** 顶部高光强度 0 - 1 */
  highlight: number;
  /** 底部光晕强度 0 - 1 */
  glow: number;
  /** 玻璃基色（#RRGGBB） */
  glassColor: string;
  /** 亮/暗主题，影响光晕与高光质感 */
  theme: 'light' | 'dark';
}

/** 默认配置：鸿蒙光感（更窄更靠底更通透，避免压住桌面图标） */
export function defaultConfig(): DockConfig {
  return {
    style: 'harmony',
    heightRatio: 0.12,
    sideRatio: 0.06,
    bottomRatio: 0.02,
    cornerRatio: 0.42,
    opacity: 0.28,
    blur: 55,
    highlight: 0.95,
    glow: 0.5,
    glassColor: '#FFFFFF',
    theme: 'light'
  };
}

/** 深拷贝配置 */
export function cloneConfig(source: DockConfig): DockConfig {
  return {
    style: source.style,
    heightRatio: source.heightRatio,
    sideRatio: source.sideRatio,
    bottomRatio: source.bottomRatio,
    cornerRatio: source.cornerRatio,
    opacity: source.opacity,
    blur: source.blur,
    highlight: source.highlight,
    glow: source.glow,
    glassColor: source.glassColor,
    theme: source.theme
  };
}
