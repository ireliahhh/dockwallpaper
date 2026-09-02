/**
 * 主界面：Dock壁纸 —— 沉浸光感风格
 *  - 全屏沉浸光感背景
 *  - 手机桌面实时预览（壁纸 + 桌面图标 + 光感 Dock）
 *  - 悬浮光感控制面板：两种效果切换（鸿蒙光感 / 液态玻璃）+ 参数滑杆
 *  - 从图库选择照片作为壁纸背景
 *  - 一键保存壁纸到相册 / 设为系统壁纸
 *
 * 说明：鸿蒙 7.0 (API 26) 的官方沉浸光感 systemMaterial 待 CI 升级后接入，
 * 当前版本以渲染引擎实现同质感光效，代码已按升级预留。
 */
import { common, abilityAccessCtrl, Permissions } from '@kit.AbilityKit';
import { display, promptAction } from '@kit.ArkUI';
import { image } from '@kit.ImageKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DockConfig, defaultConfig, cloneConfig, DockStyle } from '../model/DockConfig';
import { BackgroundData, renderDesktopPreview, renderWallpaper } from '../utils/DockRenderer';
import { saveWallpaperToAlbum, setAsWallpaper } from '../utils/WallpaperService';

const TAG: string = 'DockWallpaper';
/** 手机模拟屏宽高比（9:19） */
const PHONE_RATIO: number = 9 / 19;

@Entry
@Component
struct Index {
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private previewCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  @State config: DockConfig = defaultConfig();
  @State bg: BackgroundData = { pixelMap: undefined, imgW: 0, imgH: 0, isScreenshot: false };
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

        // 手机桌面实时预览
        this.buildPhonePreview()

        // 悬浮光感控制面板
        this.buildPanel()
      }
      .width('100%')
      .height('100%')
      .padding({ top: 48, bottom: 18, left: 14, right: 14 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#070A16')
  }

  // ===================== 背景 =====================

  @Builder
  buildBackdrop() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({ angle: 180, colors: [['#0A0D1C', 0], ['#151A3A', 0.5], ['#221545', 1]] })

      // 顶部光晕
      Column()
        .width(360)
        .height(360)
        .borderRadius(180)
        .backgroundColor('rgba(110,150,255,0.20)')
        .blur(90)
        .position({ x: -120, y: -90 })

      // 右下光晕
      Column()
        .width(320)
        .height(320)
        .borderRadius(160)
        .backgroundColor('rgba(190,110,255,0.15)')
        .blur(100)
        .position({ x: 230, y: 560 })
    }
    .width('100%')
    .height('100%')
  }

  // ===================== 头部 =====================

  @Builder
  buildHeader() {
    Row() {
      Column() {
        Text('Dock壁纸')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
        Text('鸿蒙专属 Dock 壁纸生成')
          .fontSize(12)
          .fontColor('rgba(255,255,255,0.5)')
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)

      Blank()

      Text('沉浸光感')
        .fontSize(10)
        .fontColor('#FFFFFF')
        .padding({ left: 10, right: 10, top: 5, bottom: 5 })
        .backgroundColor('rgba(255,255,255,0.12)')
        .borderRadius(12)
        .border({ width: 1, color: 'rgba(255,255,255,0.2)' })
    }
    .width('100%')
  }

  // ===================== 手机预览 =====================

  @Builder
  buildPhonePreview() {
    Stack() {
      // 手机模拟屏
      Canvas(this.previewCtx)
        .width('100%')
        .height('100%')
        .onReady(() => this.onPreviewReady())

      // 未选图时的引导
      if (this.bg.pixelMap === undefined) {
        Column() {
          Text('轻触下方「选择图片」')
            .fontSize(12)
            .fontColor('rgba(255,255,255,0.55)')
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .backgroundColor('rgba(0,0,0,0.30)')
            .borderRadius(14)
        }
        .width('100%')
        .position({ y: '60%' })
      }
    }
    .layoutWeight(1)
    .width('100%')
    .borderRadius(30)
    .clip(true)
    .border({ width: 1, color: 'rgba(255,255,255,0.16)' })
    .shadow({ radius: 40, color: 'rgba(0,0,0,0.55)', offsetY: 12 })
    .margin({ top: 14, bottom: 14 })
    .onAreaChange((oldValue: Area, newValue: Area) => {
      const w = Number(newValue.width);
      const h = Number(newValue.height);
      if (w > 0 && h > 0 && (w !== this.previewW || h !== this.previewH)) {
        this.previewW = w;
        this.previewH = h;
        this.scheduleRender();
      }
    })
  }

  // ===================== 控制面板 =====================

  @Builder
  buildPanel() {
    Column() {
      // 效果切换（仅两种）
      Row({ space: 8 }) {
        this.modeChip('harmony', '鸿蒙光感')
        this.modeChip('liquid', '液态玻璃')
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 14 })

      // 参数滑杆（数值与滑杆位置实时联动）
      Scroll() {
        Column({ space: 4 }) {
          this.sliderRow('高度', 0.10, 0.22, 0.01,
            (v: number) => `${Math.round(v * 100)}%`,
            (v: number) => this.updateDockField('heightRatio', v),
            (): number => this.config.heightRatio)
          this.sliderRow('位置', 0.02, 0.08, 0.005,
            (v: number) => `${Math.round(v * 100)}%`,
            (v: number) => this.updateDockField('bottomRatio', v),
            (): number => this.config.bottomRatio)
          this.sliderRow('圆角', 0.2, 0.55, 0.01,
            (v: number) => `${Math.round(v * 100)}%`,
            (v: number) => this.updateDockField('cornerRatio', v),
            (): number => this.config.cornerRatio)
          this.sliderRow('透明', 0.1, 0.8, 0.01,
            (v: number) => `${Math.round(v * 100)}%`,
            (v: number) => this.updateDockField('opacity', v),
            (): number => this.config.opacity)
          this.sliderRow('模糊', 5, 80, 1,
            (v: number) => `${Math.round(v)}`,
            (v: number) => this.updateDockField('blur', v),
            (): number => this.config.blur)
        }
        .width('100%')
        .padding({ left: 18, right: 18, top: 6, bottom: 4 })
      }
      .width('100%')
      .height(148)
      .scrollBar(BarState.Auto)

      // 操作按钮（两行，避免文字被截断成省略号）
      Column({ space: 10 }) {
        Row({ space: 10 }) {
          this.actionButton('选择图片', false, () => this.pickFromAlbum())
          this.actionButton('桌面截图', false, () => this.pickScreenshot())
        }
        Row({ space: 10 }) {
          this.actionButton('保存壁纸', false, () => this.onSaveToAlbum())
          this.actionButton('设为壁纸', true, () => this.onSetWallpaper())
        }
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 10, bottom: 16 })
    }
    .width('100%')
    .borderRadius(30)
    .backgroundColor('rgba(255,255,255,0.07)')
    .backdropBlur(40)
    .border({ width: 1, color: 'rgba(255,255,255,0.12)' })
    .shadow({ radius: 34, color: 'rgba(0,0,0,0.55)', offsetY: 12 })
  }

  @Builder
  modeChip(style: DockStyle, label: string) {
    Text(label)
      .fontSize(14)
      .fontWeight(this.config.style === style ? FontWeight.Medium : FontWeight.Normal)
      .fontColor(this.config.style === style ? '#10121E' : 'rgba(255,255,255,0.85)')
      .padding({ left: 18, right: 18, top: 8, bottom: 8 })
      .backgroundColor(this.config.style === style ? '#FFFFFF' : 'rgba(255,255,255,0.08)')
      .borderRadius(20)
      .onClick(() => {
        this.switchStyle(style);
      })
  }

  @Builder
  sliderRow(
    title: string,
    min: number,
    max: number,
    step: number,
    display: (v: number) => string,
    onApply: (v: number) => void,
    getValue: () => number
  ) {
    Row() {
      Text(title)
        .fontSize(12)
        .fontColor('rgba(255,255,255,0.75)')
        .width(40)
        .textAlign(TextAlign.Start)
      Slider({ value: getValue(), min: min, max: max, step: step, style: SliderStyle.OutSet })
        .layoutWeight(1)
        .selectedColor('#FFFFFF')
        .trackColor('rgba(255,255,255,0.16)')
        .blockColor('#FFFFFF')
        .onChange((value: number, mode: SliderChangeMode) => {
          onApply(value);
        })
      Text(display(getValue()))
        .fontSize(11)
        .fontColor('rgba(255,255,255,0.6)')
        .width(40)
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .height(32)
  }

  @Builder
  actionButton(label: string, filled: boolean, onClick: () => void) {
    Button(label, { type: ButtonType.Capsule })
      .layoutWeight(1)
      .height(42)
      .fontSize(13)
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

  /** 实时渲染手机桌面预览（壁纸 + 图标 + Dock） */
  private async doRender(): Promise<void> {
    if (!this.ready || this.previewW <= 0 || this.previewH <= 0) {
      return;
    }
    const token: number = ++this.renderToken;
    const pw = this.previewW;
    const ph = this.previewH;
    try {
      // 按预览比例等比适配（居中）；截图模式跟随截图比例，整张截图完整显示不变形
      const ratio: number = this.bg.isScreenshot && this.bg.imgW > 0 ? (this.bg.imgH / this.bg.imgW) : PHONE_RATIO;
      let rw = pw;
      let rh = pw / ratio;
      if (rh > ph) {
        rh = ph;
        rw = ph * ratio;
      }
      const pm: image.PixelMap = await renderDesktopPreview(
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

  private switchStyle(style: DockStyle): void {
    const c: DockConfig = cloneConfig(this.config);
    c.style = style;
    this.config = c;
    this.scheduleRender();
  }

  private updateDockField(field: string, value: number): void {
    const c: DockConfig = cloneConfig(this.config);
    if (field === 'heightRatio') {
      c.heightRatio = value;
    } else if (field === 'bottomRatio') {
      c.bottomRatio = value;
    } else if (field === 'cornerRatio') {
      c.cornerRatio = value;
    } else if (field === 'opacity') {
      c.opacity = value;
    } else if (field === 'blur') {
      c.blur = value;
    } else if (field === 'highlight') {
      c.highlight = value;
    } else if (field === 'glow') {
      c.glow = value;
    }
    this.config = c;
    this.scheduleRender();
  }

  /** 从图库选择照片（fd 方式读取，兼容各类图片格式） */
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
      // 用 fd 打开，比直接传 uri 更稳（兼容 HEIC / 云图 / 其他应用图片）
      const file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      let source: image.ImageSource | undefined = undefined;
      try {
        source = image.createImageSource(file.fd);
        const decodingOptions: image.DecodingOptions = { desiredSize: { width: 3000, height: 3000 } };
        const pm: image.PixelMap = await source.createPixelMap(decodingOptions);
        const info = await pm.getImageInfo();
        this.bg = {
          pixelMap: pm,
          imgW: info.size.width,
          imgH: info.size.height,
          isScreenshot: false
        };
        this.scheduleRender();
      } finally {
        if (source !== undefined) {
          source.release();
        }
        fs.closeSync(file);
      }
    } catch (err) {
      hilog.error(0x0000, TAG, 'pick failed %{public}s', JSON.stringify(err));
      promptAction.showToast({ message: '选择图片失败，请重试' });
    }
  }

  /** 从相册选择桌面截图：预览保留真实图标/壁纸，只叠加光感 Dock */
  private async pickScreenshot(): Promise<void> {
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
      const file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      let source: image.ImageSource | undefined = undefined;
      try {
        source = image.createImageSource(file.fd);
        const decodingOptions: image.DecodingOptions = { desiredSize: { width: 3000, height: 3000 } };
        const pm: image.PixelMap = await source.createPixelMap(decodingOptions);
        const info = await pm.getImageInfo();
        this.bg = {
          pixelMap: pm,
          imgW: info.size.width,
          imgH: info.size.height,
          isScreenshot: true
        };
        this.scheduleRender();
      } finally {
        if (source !== undefined) {
          source.release();
        }
        fs.closeSync(file);
      }
    } catch (err) {
      hilog.error(0x0000, TAG, 'pick screenshot failed %{public}s', JSON.stringify(err));
      promptAction.showToast({ message: '选择截图失败，请重试' });
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

  /** 生成高清壁纸（仅背景 + Dock，不含图标） */
  private async renderFullWallpaper(): Promise<image.PixelMap> {
    const d = display.getDefaultDisplaySync();
    const w: number = d.width;
    const h: number = d.height;
    return renderWallpaper(w, h, this.config, this.bg);
  }

  private async onSaveToAlbum(): Promise<void> {
    if (this.saveBusy) {
      return;
    }
    if (this.bg.isScreenshot) {
      promptAction.showToast({ message: '当前为桌面截图预览，请先点「选择图片」选取新壁纸再保存' });
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
      promptAction.showToast({ message: '壁纸已保存到相册' });
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
    if (this.bg.isScreenshot) {
      promptAction.showToast({ message: '当前为桌面截图预览，请先点「选择图片」选取新壁纸再设置' });
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
