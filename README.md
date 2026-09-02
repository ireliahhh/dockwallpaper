# 光感 Dock 壁纸（HarmonyOS 原生应用）

一款为 HarmonyOS 手机生成「iOS 风格毛玻璃 Dock」壁纸的原生应用。
基于 ArkTS + ArkUI + Canvas + effectKit 实现 **鸿蒙沉浸光感**：真实背景模糊的玻璃 Dock、顶部高光、底部柔光光晕，App 界面本身也是沉浸式光感风格 + 悬浮毛玻璃控制底栏。

---

## 功能特性

| 模块 | 说明 |
|------|------|
| 背景 | 纯色 / 渐变 / 从相册选图 三种来源 |
| Dock 定制 | 高度、左右留白、圆角、透明度、模糊强度、高光、光晕共 7 项参数 |
| Dock 预设 | iOS 玻璃白 / 深色玻璃 / 霓虹蓝 / 通透微光 四套模板 |
| 沉浸光感 | 真实背景高斯模糊（effectKit）+ 半透明玻璃 + 顶部高光渐变 + 底部柔光光晕 |
| 实时预览 | 调节参数即时重绘预览 |
| 高清导出 | 按设备真实分辨率生成壁纸，保存到相册 |
| 一键设壁纸 | 直接调用系统接口设为桌面壁纸 |
| App 界面 | 沉浸式全屏（隐藏系统栏）、深色渐变 + 光晕氛围、悬浮毛玻璃控制底栏 |

---

## 工程结构

```
DockWallpaper/
├── AppScope/                          # 应用级配置
│   ├── app.json5
│   └── resources/base/
│       ├── element/string.json        # 应用名
│       └── media/app_icon.png         # 应用图标
├── entry/                             # 主模块
│   ├── build-profile.json5
│   ├── oh-package.json5
│   ├── hvigorfile.ts
│   └── src/main/
│       ├── module.json5               # 模块配置 + 权限声明
│       ├── ets/
│       │   ├── entryability/EntryAbility.ets   # 入口（沉浸式全屏）
│       │   ├── pages/Index.ets                 # 主界面
│       │   ├── model/DockConfig.ets            # 配置模型
│       │   ├── common/Constants.ets            # 预设模板
│       │   └── utils/
│       │       ├── DockRenderer.ets            # Canvas 渲染引擎（毛玻璃光感）
│       │       └── WallpaperService.ets        # 保存/设置壁纸
│       └── resources/base/
│           ├── element/               # 字符串/颜色/浮点资源
│           ├── media/                 # 图标
│           └── profile/main_pages.json
├── build-profile.json5
├── hvigorfile.ts
├── oh-package.json5
└── hvigor/hvigor-config.json5
```

---

## 运行环境

- DevEco Studio **5.0 及以上**（含 HarmonyOS NEXT SDK，API 12+）
- 目标设备：HarmonyOS 手机（真机调试需在 DevEco Studio 中配置签名）

## 权限说明

| 权限 | 类型 | 用途 |
|------|------|------|
| `ohos.permission.WRITE_IMAGEVIDEO` | user_grant（运行时申请） | 保存壁纸到相册 |
| `ohos.permission.SET_WALLPAPER` | system_grant（声明即可） | 设为系统壁纸 |

---

## 使用步骤

1. **安装 DevEco Studio**：从华为开发者官网下载安装（选择 HarmonyOS NEXT 5.0 工具链），首次启动按向导配置 SDK。
2. **导入工程**：打开 DevEco Studio → `File > Open` → 选择本 `DockWallpaper` 目录（含 `build-profile.json5` 的根目录）。
3. **等待同步**：首次导入会自动加载 `hvigor` 依赖，等待右下角完成。
4. **配置签名**：`File > Project Structure > Signing Configs`，勾选自动签名（需登录华为开发者账号），或用模拟器直接运行。
5. **运行**：点击 ▶ 运行到模拟器 / 真机。

> 若提示 SDK 版本不匹配，在 `Project Structure > Project` 中把 `compatibleSdkVersion` 调整为你本机已安装的版本（如 `5.0.0(12)` 或 `6.0.0(20)`）。

---

## 二次开发提示

- **毛玻璃效果**在 `utils/DockRenderer.ets` 的 `drawDockGlass()`：`effectKit` 对背景整图做高斯模糊，再裁剪进圆角 Dock 区域，叠加玻璃基色、顶部高光渐变、底部柔光光晕。
- **预设模板**在 `common/Constants.ets` 的 `DOCK_PRESETS` / `COLOR_PRESETS` / `GRADIENT_PRESETS`，想加新风格直接追加即可。
- **导出分辨率**取自设备 `display`，如需固定比例可在 `renderFullWallpaper()` 中调整。

## 已知说明

- 工程默认不包含签名配置，需在 DevEco Studio 中按上述步骤配置后才能在真机运行。
- 真机「保存到相册」首次使用会弹出权限申请，请允许；「设为壁纸」为系统级权限自动授予。
