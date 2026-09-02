/**
 * 主界面：沉浸光感风格 + 悬浮底栏控制面板
 *  - 全屏沉浸式光感背景
 *  - 实时壁纸预览（毛玻璃 Dock 沉浸光感）
 *  - 悬浮毛玻璃控制面板（背景 / Dock 光感）
 *  - 一键保存到相册 / 设为壁纸
 */
import { common, abilityAccessCtrl, Permissions } from '@kit.AbilityKit';
import { display, promptAction } from '@kit.ArkUI';
import { image } from '@kit.ImageKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DockConfig, defaultConfig, cloneConfig } from '../model/DockConfig';
import { COLOR_PRESETS, GRADIENT_PRESETS, DOCK_PRESETS, DockPreset, WALLPAPER_RATIO } from '../common/Constants';
import { BackgroundData, renderDockWallpaper } from '../utils/DockRenderer';
import { saveWallpaperToAlbum, setAsWallpaper } from '../utils/WallpaperService';

const TAG: string = 'DockWallpaper';

@Entry
@Component
struct Index {
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private previewCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  @State config: DockConfig = defaultConfig();
  @State bg: BackgroundData = {
    mode: 'color',
    color: COLOR_PRESETS[0],
    gradientIndex: 0,
    pixelMap: undefined,
    imgW: 0,
    imgH: 0
  };
  @State bgMode: number = 0;
  @State activeTab: number = 0;
  @State dockPresetIndex: number = 0;
  @State saveBusy: boolean = false;
  @State previewW: number = 0;
  @State previewH: number = 0;

  private ready: boolean = false;
  private renderTimer: number = -1;
  private renderToken: number = 0;

  build() {
    Stack() {
      // 沉浸光感背景
      this.buildBackdrop()

      Column() {
        this.buildHeader()

        // 实时预览卡片
        Stack() {
          Canvas(this.previewCtx)
            .width('100%')
            .height('100%')
            .onReady(() => this.onPreviewReady())
        }
        .layoutWeight(1)
        .width('100%')
        .margin({ top: 14, bottom: 14 })
        .borderRadius(34)
        .clip(true)
        .border({ width: 1, color: 'rgba(255,255,255,0.14)' })
        .shadow({ radius: 36, color: 'rgba(0,0,0,0.5)', offsetY: 10 })
        .onAreaChange((oldValue: Area, newValue: Area) => {
          const w = Number(newValue.width);
          const h = Number(newValue.height);
          if (w > 0 && h > 0 && (w !== this.previewW || h !== this.previewH)) {
            this.previewW = w;
            this.previewH = h;
            this.scheduleRender();
          }
        })

        // 悬浮光感控制底栏
        this.buildPanel()
      }
      .width('100%')
      .height('100%')
      .padding({ top: 48, bottom: 22, left: 14, right: 14 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#070A16')
  }

  // ===================== 界面构建 =====================

  @Builder
  buildBackdrop() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({ angle: 180, colors: [['#0A0D1C', 0], ['#141B3C', 0.55], ['#221545', 1]] })

      // 顶部光晕
      Column()
        .width(340)
        .height(340)
        .borderRadius(170)
        .backgroundColor('rgba(110,150,255,0.22)')
        .blur(90)
        .position({ x: -100, y: -80 })

      // 右侧光晕
      Column()
        .width(320)
        .height(320)
        .borderRadius(160)
        .backgroundColor('rgba(190,110,255,0.16)')
        .blur(100)
        .position({ x: 220, y: 400 })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  buildHeader() {
    Row() {
      Column() {
        Text('光感 Dock 壁纸')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
        Text('iOS 风格毛玻璃 Dock · 一键生成')
          .fontSize(12)
          .fontColor('rgba(255,255,255,0.5)')
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)

      Blank()

      Text('鸿蒙沉浸光感')
        .fontSize(10)
        .fontColor('#FFFFFF')
        .padding({ left: 10, right: 10, top: 5, bottom: 5 })
        .backgroundColor('rgba(255,255,255,0.12)')
        .borderRadius(12)
        .border({ width: 1, color: 'rgba(255,255,255,0.2)' })
    }
    .width('100%')
  }

  @Builder
  buildPanel() {
    Column() {
      // Tab 行
      Row({ space: 8 }) {
        this.tabChip(0, '背景')
        this.tabChip(1, 'Dock 光感')
        Blank()
        Text('实时预览')
          .fontSize(10)
          .fontColor('rgba(255,255,255,0.5)')
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .backgroundColor('rgba(255,255,255,0.08)')
          .borderRadius(12)
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 14 })

      // 内容区
      if (this.activeTab === 0) {
        this.buildBgContent()
      } else {
        this.buildDockContent()
      }

      // 操作按钮
      Row({ space: 10 }) {
        this.actionButton('保存到相册', false, () => this.onSaveToAlbum())
        this.actionButton('设为壁纸', true, () => this.onSetWallpaper())
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 12, bottom: 16 })
    }
    .width('100%')
    .borderRadius(30)
    .backgroundColor('rgba(255,255,255,0.07)')
    .backdropBlur(40)
    .border({ width: 1, color: 'rgba(255,255,255,0.12)' })
    .shadow({ radius: 34, color: 'rgba(0,0,0,0.55)', offsetY: 12 })
  }

  @Builder
  tabChip(index: number, label: string) {
    Text(label)
      .fontSize(13)
      .fontColor(this.activeTab === index ? '#10121E' : 'rgba(255,255,255,0.85)')
      .fontWeight(this.activeTab === index ? FontWeight.Medium : FontWeight.Normal)
      .padding({ left: 16, right: 16, top: 7, bottom: 7 })
      .backgroundColor(this.activeTab === index ? '#FFFFFF' : 'rgba(255,255,255,0.08)')
      .borderRadius(18)
      .onClick(() => {
        this.activeTab = index;
      })
  }

  @Builder
  buildBgContent() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        this.modeChip(0, '纯色')
        this.modeChip(1, '渐变')
        this.modeChip(2, '相册')
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 12 })

      if (this.bgMode === 0) {
        this.buildColorSwatches()
      } else if (this.bgMode === 1) {
        this.buildGradientSwatches()
      } else {
        Row() {
          Button('从相册选择图片', { type: ButtonType.Capsule })
            .height(40)
            .fontSize(13)
            .fontColor('#FFFFFF')
            .backgroundColor('rgba(255,255,255,0.14)')
            .border({ width: 1, color: 'rgba(255,255,255,0.25)' })
            .onClick(() => this.pickFromAlbum())
        }
        .width('100%')
        .padding({ left: 18, right: 18, top: 4, bottom: 12 })
      }
    }
    .width('100%')
  }

  @Builder
  modeChip(index: number, label: string) {
    Text(label)
      .fontSize(12)
      .fontColor(this.bgMode === index ? '#FFFFFF' : 'rgba(255,255,255,0.6)')
      .padding({ left: 14, right: 14, top: 6, bottom: 6 })
      .backgroundColor(this.bgMode === index ? 'rgba(255,255,255,0.18)' : 'rgba(255,255,255,0.06)')
      .borderRadius(16)
      .border({ width: 1, color: this.bgMode === index ? 'rgba(255,255,255,0.35)' : 'rgba(255,255,255,0.1)' })
      .onClick(() => {
        this.bgMode = index;
      })
  }

  @Builder
  buildColorSwatches() {
    Row({ space: 10 }) {
      ForEach(COLOR_PRESETS, (color: string, index: number) => {
        Column()
          .width(32)
          .height(32)
          .borderRadius(16)
          .backgroundColor(color)
          .border({
            width: this.bg.mode === 'color' && this.bg.color === color ? 2 : 1,
            color: this.bg.mode === 'color' && this.bg.color === color ? '#FFFFFF' : 'rgba(255,255,255,0.25)'
          })
          .onClick(() => {
            this.bgMode = 0;
            this.bg = { mode: 'color', color: color, gradientIndex: this.bg.gradientIndex, pixelMap: undefined, imgW: 0, imgH: 0 };
            this.scheduleRender();
          })
      }, (color: string, index: number) => index.toString())
    }
    .width('100%')
    .padding({ left: 18, right: 18, bottom: 12 })
  }

  @Builder
  buildGradientSwatches() {
    Row({ space: 10 }) {
      ForEach(GRADIENT_PRESETS, (grad: string[], index: number) => {
        Column()
          .width(32)
          .height(32)
          .borderRadius(12)
          .linearGradient({ angle: 135, colors: [[grad[0], 0], [grad[1], 1]] })
          .border({
            width: this.bg.mode === 'gradient' && this.bg.gradientIndex === index ? 2 : 1,
            color: this.bg.mode === 'gradient' && this.bg.gradientIndex === index ? '#FFFFFF' : 'rgba(255,255,255,0.25)'
          })
          .onClick(() => {
            this.bgMode = 1;
            this.bg = { mode: 'gradient', color: this.bg.color, gradientIndex: index, pixelMap: undefined, imgW: 0, imgH: 0 };
            this.scheduleRender();
          })
      }, (grad: string[], index: number) => index.toString())
    }
    .width('100%')
    .padding({ left: 18, right: 18, bottom: 12 })
  }

  @Builder
  buildDockContent() {
    Column() {
      // 预设模板
      Scroll() {
        Row({ space: 8 }) {
          ForEach(DOCK_PRESETS, (preset: DockPreset, index: number) => {
            Text(preset.name)
              .fontSize(12)
              .fontColor(this.dockPresetIndex === index ? '#10121E' : 'rgba(255,255,255,0.85)')
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .backgroundColor(this.dockPresetIndex === index ? '#FFFFFF' : 'rgba(255,255,255,0.10)')
              .borderRadius(16)
              .onClick(() => this.applyPreset(index))
          }, (preset: DockPreset, index: number) => index.toString())
        }
        .width('100%')
      }
      .width('100%')
      .height(40)
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .padding({ left: 18, right: 18, top: 12 })

      // 参数滑杆
      Scroll() {
        Column({ space: 6 }) {
          this.sliderRow('高度', this.config.heightRatio, 0.10, 0.22, 0.01,
            (v: number) => `${Math.round(v * 100)}%`,
            (v: number) => this.updateDock(Object.assign({}, this.config, { heightRatio: v })))
          this.sliderRow('留白', this.config.sideRatio, 0.04, 0.12, 0.005,
            (v: number) => `${Math.round(v * 100)}%`,
            (v: number) => this.updateDock(Object.assign({}, this.config, { sideRatio: v })))
          this.sliderRow('圆角', this.config.cornerRatio, 0.15, 0.55, 0.01,
            (v: number) => `${Math.round(v * 100)}%`,
            (v: number) => this.updateDock(Object.assign({}, this.config, { cornerRatio: v })))
          this.sliderRow('透明度', this.config.opacity, 0.1, 0.8, 0.01,
            (v: number) => `${Math.round(v * 100)}%`,
            (v: number) => this.updateDock(Object.assign({}, this.config, { opacity: v })))
          this.sliderRow('模糊', this.config.blur, 5, 80, 1,
            (v: number) => `${Math.round(v)}`,
            (v: number) => this.updateDock(Object.assign({}, this.config, { blur: v })))
          this.sliderRow('高光', this.config.highlight, 0, 1, 0.02,
            (v: number) => `${Math.round(v * 100)}%`,
            (v: number) => this.updateDock(Object.assign({}, this.config, { highlight: v })))
          this.sliderRow('光晕', this.config.glow, 0, 1, 0.02,
            (v: number) => `${Math.round(v * 100)}%`,
            (v: number) => this.updateDock(Object.assign({}, this.config, { glow: v })))
        }
        .width('100%')
        .padding({ left: 18, right: 18, top: 4, bottom: 10 })
      }
      .width('100%')
      .height(150)
      .scrollBar(BarState.Auto)
    }
    .width('100%')
  }

  @Builder
  sliderRow(
    title: string,
    current: number,
    min: number,
    max: number,
    step: number,
    display: (v: number) => string,
    onApply: (v: number) => void
  ) {
    Row() {
      Text(title)
        .fontSize(12)
        .fontColor('rgba(255,255,255,0.75)')
        .width(48)
        .textAlign(TextAlign.Start)
      Slider({ value: current, min: min, max: max, step: step, style: SliderStyle.OutSet })
        .layoutWeight(1)
        .selectedColor('#FFFFFF')
        .trackColor('rgba(255,255,255,0.16)')
        .blockColor('#FFFFFF')
        .onChange((value: number, mode: SliderChangeMode) => {
          onApply(value);
        })
      Text(display(current))
        .fontSize(11)
        .fontColor('rgba(255,255,255,0.6)')
        .width(46)
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .height(34)
  }

  @Builder
  actionButton(label: string, filled: boolean, onClick: () => void) {
    Button(label, { type: ButtonType.Capsule })
      .layoutWeight(1)
      .height(44)
      .fontSize(14)
      .fontWeight(FontWeight.Medium)
      .fontColor(filled ? '#10121E' : '#FFFFFF')
      .backgroundColor(filled ? '#FFFFFF' : 'rgba(255,255,255,0.12)')
      .border({ width: filled ? 0 : 1, color: 'rgba(255,255,255,0.25)' })
      .opacity(this.saveBusy ? 0.55 : 1)
      .onClick(() => onClick())
  }

  // ===================== 逻辑 =====================

  private onPreviewReady(): void {
    this.ready = true;
    this.scheduleRender();
  }

  private scheduleRender(): void {
    if (this.renderTimer !== -1) {
      clearTimeout(this.renderTimer);
    }
    this.renderTimer = setTimeout(() => {
      this.doRender();
    }, 80);
  }

  private async doRender(): Promise<void> {
    if (!this.ready || this.previewW <= 0 || this.previewH <= 0) {
      return;
    }
    const token: number = ++this.renderToken;
    const pw = this.previewW;
    const ph = this.previewH;
    try {
      // 按壁纸比例在预览区内等比适配（居中）
      let rw = pw;
      let rh = pw / WALLPAPER_RATIO;
      if (rh > ph) {
        rh = ph;
        rw = ph * WALLPAPER_RATIO;
      }
      const pm: image.PixelMap = await renderDockWallpaper(
        Math.max(1, Math.round(rw)),
        Math.max(1, Math.round(rh)),
        this.config,
        this.bg
      );
      if (token !== this.renderToken) {
        return;
      }
      const ctx = this.previewCtx;
      ctx.clearRect(0, 0, pw, ph);
      const dx = (pw - rw) / 2;
      const dy = (ph - rh) / 2;
      ctx.drawImage(pm, dx, dy, rw, rh);
    } catch (err) {
      hilog.error(0x0000, TAG, 'render failed %{public}s', JSON.stringify(err));
    }
  }

  private updateDock(patch: DockConfig): void {
    this.dockPresetIndex = -1;
    this.config = patch;
    this.scheduleRender();
  }

  private applyPreset(index: number): void {
    this.dockPresetIndex = index;
    this.config = cloneConfig(DOCK_PRESETS[index].config);
    this.scheduleRender();
  }

  private async pickFromAlbum(): Promise<void> {
    try {
      const picker = new photoAccessHelper.PhotoViewPicker();
      const options = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;
      const result = await picker.select(options);
      if (result.photoUris.length === 0) {
        return;
      }
      const uri: string = result.photoUris[0];
      const source = image.createImageSource(uri);
      const decodingOptions: image.DecodingOptions = { desiredSize: { width: 2048, height: 2048 } };
      const pm: image.PixelMap = await source.createPixelMap(decodingOptions);
      const info = await pm.getImageInfo();
      this.bg = {
        mode: 'album',
        color: this.bg.color,
        gradientIndex: this.bg.gradientIndex,
        pixelMap: pm,
        imgW: info.size.width,
        imgH: info.size.height
      };
      this.bgMode = 2;
      this.scheduleRender();
    } catch (err) {
      hilog.error(0x0000, TAG, 'pick failed %{public}s', JSON.stringify(err));
      promptAction.showToast({ message: '选择图片失败' });
    }
  }

  private async requestPermission(perm: Permissions): Promise<boolean> {
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const ctx = getContext(this) as common.UIAbilityContext;
      const data = await atManager.requestPermissionsFromUser(ctx, [perm]);
      return data.authResults.length > 0 && data.authResults[0] === 0;
    } catch (err) {
      return false;
    }
  }

  private async renderFullWallpaper(): Promise<image.PixelMap> {
    const d = display.getDefaultDisplaySync();
    const w: number = d.width;
    const h: number = d.height;
    return renderDockWallpaper(w, h, this.config, this.bg);
  }

  private async onSaveToAlbum(): Promise<void> {
    if (this.saveBusy) {
      return;
    }
    this.saveBusy = true;
    try {
      const granted = await this.requestPermission('ohos.permission.WRITE_IMAGEVIDEO' as Permissions);
      if (!granted) {
        promptAction.showToast({ message: '未获得相册写入权限' });
        return;
      }
      const ctx = getContext(this) as common.UIAbilityContext;
      const pm: image.PixelMap = await this.renderFullWallpaper();
      await saveWallpaperToAlbum(ctx, pm);
      promptAction.showToast({ message: '已保存到相册' });
    } catch (err) {
      hilog.error(0x0000, TAG, 'save failed %{public}s', JSON.stringify(err));
      promptAction.showToast({ message: '保存失败' });
    } finally {
      this.saveBusy = false;
    }
  }

  private async onSetWallpaper(): Promise<void> {
    if (this.saveBusy) {
      return;
    }
    this.saveBusy = true;
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      const pm: image.PixelMap = await this.renderFullWallpaper();
      await setAsWallpaper(ctx, pm);
      promptAction.showToast({ message: '壁纸已设置' });
    } catch (err) {
      hilog.error(0x0000, TAG, 'set wallpaper failed %{public}s', JSON.stringify(err));
      promptAction.showToast({ message: '设置壁纸失败' });
    } finally {
      this.saveBusy = false;
    }
  }
}
