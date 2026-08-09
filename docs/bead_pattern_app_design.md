# 拼豆图生成应用设计文档

## 1. 项目概述

## 1.1 项目名称

Bead Pattern Generator

## 1.2 项目目标

开发一个跨平台拼豆图生成应用：

输入： - 普通图片（JPG/PNG） - 用户选择的拼豆品牌色库 - 拼豆尺寸

输出： - 拼豆网格图 - JPG 图片 - 颜色统计列表

目标平台： - Android - Windows - Linux - macOS

------------------------------------------------------------------------

# 2. 产品功能

## 2.1 图片导入

支持： - JPG - PNG

功能： - 图片选择 - 图片裁剪 - 图片旋转 - 图片比例调整

------------------------------------------------------------------------

## 2.2 拼豆参数设置

用户配置：

  参数         说明
  ------------ --------------------------
  宽度         拼豆数量
  高度         拼豆数量
  品牌         Perler/Hama/Artkal
  最大颜色数   限制使用颜色数量
  是否抖动     是否开启 Floyd-Steinberg
  显示网格     输出是否包含网格

------------------------------------------------------------------------

# 3. 总体架构

    Flutter Application
            |
    Application Layer
            |
    Bead Engine Package
            |
    +---------------+---------------+
    |               |               |
    Image       Color Engine   Pattern Renderer
    Processor
            |
       Palette Database
            |
        JPG Export

------------------------------------------------------------------------

# 4. 技术选型

## Flutter

原因： - Android/Desktop 一套代码 - UI开发效率高 - 生态成熟

## Dart

负责： - UI - 业务逻辑 - 图像处理 - 算法

## 图像处理

第一版使用 Flutter image package。

------------------------------------------------------------------------

# 5. 软件结构

    bead_app/

    lib/
    ├── core/
    ├── features/
    ├── services/
    ├── engine/
    └── main.dart

    assets/
    └── palettes/
        ├── perler.json
        ├── hama.json
        └── artkal.json

------------------------------------------------------------------------

# 6. 核心模型

## Pattern

``` dart
class Pattern {
  final int width;
  final int height;
  final List<Bead> beads;
}
```

## Bead

``` dart
class Bead {
  final int x;
  final int y;
  final String colorCode;
  final Color color;
}
```

------------------------------------------------------------------------

# 7. 色库设计

JSON：

``` json
{
 "brand":"Artkal",
 "colors":[
   {
     "code":"A001",
     "name":"White",
     "rgb":[255,255,255]
   }
 ]
}
```

------------------------------------------------------------------------

# 8. 图像算法流程

    输入图片
       |
    图片解码
       |
    Resize
       |
    Pixel Sampling
       |
    RGB -> LAB
       |
    颜色匹配
       |
    Pattern生成
       |
    JPG输出

------------------------------------------------------------------------

# 9. 渲染设计

使用 Flutter CustomPainter：

    Pattern
       |
    PatternPainter
       |
    Canvas.drawRect()

避免创建大量 Widget。

------------------------------------------------------------------------

# 10. JPG输出

流程：

    Pattern
     |
    Canvas
     |
    PictureRecorder
     |
    Image
     |
    JPEG Encoder
     |
    output.jpg

------------------------------------------------------------------------

# 11. 开发计划

## V1

-   图片导入
-   设置尺寸
-   选择色库
-   自动转换
-   JPG输出

## V2

-   颜色统计
-   手动修改颜色
-   项目保存
-   多品牌支持

## V3

-   AI像素画
-   人像优化
-   云端分享

------------------------------------------------------------------------

# 12. 最终架构

    Flutter
     |
    Riverpod
     |
    Bead Engine
     |
    +----------------+
    | Image Process  |
    | Color Matching |
    | Pattern Render |
    +----------------+
     |
    CustomPainter
     |
    JPEG Export

第一版本无需 C++、OpenCV、AI，即可完成完整拼豆图生成应用。
