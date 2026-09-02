import { DockConfig } from '../model/DockConfig';

/** 纯色背景预设 */
export const COLOR_PRESETS: string[] = [
  '#0B1026', // 深夜蓝
  '#1B2A4A', // 雾蓝
  '#3E2A55', // 深紫
  '#6B2D5C', // 酒红紫
  '#0F3D3E', // 墨绿
  '#2A2E3A', // 炭灰
  '#000000'  // 纯黑
];

/** 渐变背景预设（起止色） */
export const GRADIENT_PRESETS: string[][] = [
  ['#1E1B4B', '#7C3AED'], // 暮光紫
  ['#0F2027', '#2C5364'], // 深海蓝绿
  ['#FF7E5F', '#FEB47B'], // 日出橙
  ['#667EEA', '#764BA2'], // 霓虹紫
  ['#141E30', '#243B55'], // 静谧午夜蓝
  ['#DA22FF', '#9733EE']  // 霓虹粉紫
];

/** Dock 主题预设 */
export interface DockPreset {
  name: string;
  config: DockConfig;
}

export const DOCK_PRESETS: DockPreset[] = [
  {
    name: 'iOS玻璃白',
    config: {
      heightRatio: 0.16, sideRatio: 0.07, bottomRatio: 0.03, cornerRatio: 0.4,
      opacity: 0.35, blur: 45, highlight: 0.85, glow: 0.3,
      glassColor: '#FFFFFF', theme: 'light'
    }
  },
  {
    name: '深色玻璃',
    config: {
      heightRatio: 0.16, sideRatio: 0.07, bottomRatio: 0.03, cornerRatio: 0.45,
      opacity: 0.5, blur: 40, highlight: 0.4, glow: 0.35,
      glassColor: '#101014', theme: 'dark'
    }
  },
  {
    name: '霓虹蓝',
    config: {
      heightRatio: 0.17, sideRatio: 0.06, bottomRatio: 0.03, cornerRatio: 0.5,
      opacity: 0.42, blur: 50, highlight: 0.9, glow: 0.5,
      glassColor: '#4C6FFF', theme: 'dark'
    }
  },
  {
    name: '通透微光',
    config: {
      heightRatio: 0.14, sideRatio: 0.09, bottomRatio: 0.03, cornerRatio: 0.3,
      opacity: 0.22, blur: 30, highlight: 0.7, glow: 0.2,
      glassColor: '#FFFFFF', theme: 'light'
    }
  }
];

/** 壁纸宽高比（手机竖屏） */
export const WALLPAPER_RATIO: number = 9 / 16;
