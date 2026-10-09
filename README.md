# TuneCraft · 多功能弦乐器调音工具（Android / iOS）

吉他调音已完整实现
#### 计划
- 贝司
- 尤克里里
- …

## 运行

```bash
flutter pub get
flutter run            # 真机（需麦克风权限）
flutter test           # 单元 + 组件测试
flutter analyze        # 静态分析
```

## 界面

- 顶部：乐器下拉菜单 + 自动/手动按钮
- 中部：横向线形指针仪表（-50~+50¢，指针左右移动，中间 0 为基准；绿=音准/橙=接近/红=偏离）+ 状态提示
- 下部：琴头图形（木纹头体、金属弦轴、弦钮、品丝），点弦钮手动选弦

## 结构

- `lib/core/tuning/` 音分换算与分级（±5¢准/±15¢接近/其余偏离）
- `lib/core/pitch/` YIN 基频检测（纯 Dart，双端一致）+ 接口（可换 McLeod/FFT）
- `lib/core/audio/` 麦克风采集（record pcm16bits）
- `lib/domain/instruments/` 乐器抽象 + 吉他标准调弦 + 注册表（扩展点）
- `lib/domain/headstock_layout.dart` 琴头布局（3+3 / 单侧6弦，预留贝司 4 弦）
- `lib/state/tuner_controller.dart` 自动/手动选弦、中值滤波、指针平滑、防抖
- `lib/ui/` 琴头琴颈抽象图形（CustomPainter）+ 横向线形仪表 + 主屏

## 交互

- 进屏自动拾音；自动模式就近匹配弦（300ms 防抖），手动模式点琴头弦钮锁定
- 弦序（上->下，顶端->琴颈）：3+3 左列 D/A/E、右列 G/B/E；单侧 1..6
- 方向提示：偏低拧紧 ↑ / 偏高放松 ↓

## 权限

- Android：`RECORD_AUDIO`（已在 `AndroidManifest.xml` 声明）
- iOS：`NSMicrophoneUsageDescription`（已在 `Info.plist` 声明）
