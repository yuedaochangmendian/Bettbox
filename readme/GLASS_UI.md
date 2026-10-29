# Liquid Glass 界面改造说明

本分支把 Bettbox 的 Flutter 界面整体迁移到 [liquid_glass_widgets](https://github.com/sdegenaar/liquid_glass_widgets)（iOS 26/27 Liquid Glass 设计语言）。业务逻辑、内核、代理链路、配置模型一行未改，改动集中在渲染层。

## 为什么不是逐页重写

`lib/` 下有 268 个 Dart 文件、约 5.3 MB 代码。逐页重写既不可能稳定，也会把上游后续更新全部变成冲突。

Bettbox 的界面本来就是收敛的：几乎所有视觉都由 `lib/widgets/` 下的一组基元产生——`CommonCard`（91 处调用）、`CommonScaffold`（32 处）、`showCommonDialog`（79 处）、`GoogleBottomNavBar`、`AppBar`、底部弹层、Toast。改这些基元，等于同时改了全部页面。

所以做法是：**换掉设计系统层，页面代码不动。**

## 三层结构

```
lib/ui/glass/
  sky_backdrop.dart   壁纸层：程序化「极光」背景
  glass_kit.dart      材质层：光学预设 + 玻璃面板/玻璃条 + 配色变换
```

**1. 壁纸层（SkyBackdrop）**

玻璃只有在背后有东西可折射时才像玻璃。原来每个页面都刷一层不透明的 `surfaceContainer`，任何玻璃放上去都会被压成一块灰板。

`SkyBackdrop` 用 4 个径向渐变叠一层底色，颜色由当前 `ColorScheme` 派生（深色模式加深、浅色模式向白色洗淡），缓慢漂移。没有位图、没有运行时滤镜。

**2. 材质层（SkyGlass）**

只有三档光学参数，因为再多就无法保持一致：

| 预设 | 用途 | 特征 |
| --- | --- | --- |
| `SkyGlass.chrome` | 顶部栏、底部 Dock、弹窗、Toast | 最厚、最强折射，`GlassQuality.premium` |
| `SkyGlass.panel` | 内容卡片、分组容器 | 柔和、单通道着色器，`standard` |
| `SkyGlass.pill` | 胶囊按钮、小控件 | 最薄、`standard` |

同一层里还有 `glassSurfaces`：把 `ColorScheme` 的 surface 系列整体转成半透明。这是「全站透明」的开关——所有组件都通过 `context.colorScheme.surfaceContainer*` 取背景色，改这一处即可，不必碰调用点。

**3. 挂载点**

`Application` 的 `MaterialApp.builder` 里包一层 `GlassPage(background: SkyBackdrop())`：

- 整个 App 只有**一次**背景捕获，几十块玻璃共享，不是每块各拍一次；
- `GlassPage` 会自动把所有 `Scaffold` 强制成透明，让壁纸透上来；
- 它提供的 `AdaptiveLiquidGlassLayer` 是玻璃组件必需的渲染作用域，缺了会直接抛异常。

## 具体改动

| 文件 | 改动 |
| --- | --- |
| `lib/main.dart` | `LiquidGlassWidgets.initialize()` 预热着色器；`wrap()` 注入主题、无障碍降级、`brightnessResolver` |
| `lib/application.dart` | `GlassPage` + `SkyBackdrop` 挂载；`scaffoldBackgroundColor` 透明；`Card`/`SnackBar` 玻璃化主题 |
| `lib/ui/glass/sky_backdrop.dart` | 新增：程序化壁纸 |
| `lib/ui/glass/glass_kit.dart` | 新增：光学预设、`SkyGlassPanel`、`SkyGlassChrome`、`SkyGlassCircle`、配色变换 |
| `lib/widgets/card.dart` | `CommonCard` 表面换成玻璃面板，按钮只保留 ink 与焦点环（否则会在玻璃上再糊一层不透明底色） |
| `lib/widgets/scaffold.dart` | 顶部栏套玻璃条；`Scaffold` 默认透明 |
| `lib/widgets/dialog.dart` | `AlertDialog` → 自绘 `Dialog` + 玻璃面板（`AlertDialog` 无法在自身形状内做背景模糊），内边距、标题字号、`OverflowBar` 行为全部对齐原版 |
| `lib/widgets/sheet.dart` | 底部弹层换成上圆角玻璃条 |
| `lib/widgets/google_bottom_nav_bar.dart` | 底部导航换成悬浮玻璃胶囊，保留原有拖拽/回弹/焦点逻辑 |
| `lib/manager/message_manager.dart` | 应用内 Toast 换成玻璃条 |
| `lib/views/dashboard/dashboard.dart` | 首页启动胶囊：待机=清透玻璃，运行中=主色玻璃 |

## 踩到的两条规则

1. **玻璃是托盘，不是包装器。** 玻璃只用于导航与控制层。内容卡片用 `standard` 档并共享背景捕获；密集列表项不逐项加玻璃。
2. **不把折射玻璃放进折射玻璃。** `GlassContainer` 会给子树打 `avoidsRefraction`，嵌套只会降质并裁掉回弹动画。所以卡片里放的是普通文本/控件，玻璃控件放在卡片外。

## 性能取舍

- 壁纸用 `ValueNotifier` 直接驱动 `CustomPainter` 重绘，260 ms 一帧（约 4 fps），不重建组件树。原来用 `AnimationController` 会以 60 fps 重绘 4 个全屏径向渐变，纯属浪费。
- 所有玻璃共享一个渲染层；`wrap(adaptiveQuality: true)` 会在启动后约 3 秒基准测试设备的栅格预算，弱机自动降到 `minimal`（退化为普通 `BackdropFilter`），避免低端机掉帧。
- OLED `pureBlack` 用户保持纯黑不透明面板，不被半透明化。

## 构建

```bash
dart setup.dart android --arch arm64      # 编译 mihomo 内核到 libclash/
flutter build apk --release --target-platform android-arm64
```

注意：

- `dart setup.dart` 需要 `ANDROID_NDK` 指向 NDK 28.2.13676358。
- 本机未安装 Visual Studio Build Tools，`plugins/code_forge`（Rust/`cargokit`）无法编译；该插件缺失不影响启动与其他功能，只影响 JS 覆写脚本编辑器。装有 MSVC 的机器上直接 `flutter build apk` 即可正常产出。
- 仓库不含 `android/gradlew`（上游 `.gitignore` 忽略），首次构建前需 `gradle wrapper --gradle-version 9.3.1`。
