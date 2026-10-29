# visionOS app icon

visionOS does not take the Icon Composer file. Its icon is a solid image
stack of three square layers in the visionOS target's asset catalog: a
background and one or two layers on top. The system cuts it to a circle,
adds shadows between the layers, and uses the upper layers' transparency
to emboss them; the icon swells a little when people look at it.
[HIG App icons; Xcode, Configuring your app icon]

The structure below is the one Xcode's own visionOS template ships
(`AppIcon.solidimagestack`, asset generation type `solidimagestack`), and
it was checked by compiling it with `actool` from Xcode 27
(`--platform xros --target-device vision`): 1024 x 1024 px layers compile
clean, smaller ones fail.

## The catalog

In the visionOS target's `Assets.xcassets/`:

```text
AppIcon.solidimagestack/
  Contents.json
  Front.solidimagestacklayer/Contents.json
  Front.solidimagestacklayer/Content.imageset/{Contents.json, front.png}
  Middle.solidimagestacklayer/...      same shape as Front
  Back.solidimagestacklayer/...        same shape as Front
```

`AppIcon.solidimagestack/Contents.json`, front first:

```json
{
  "info" : { "author" : "xcode", "version" : 1 },
  "layers" : [
    { "filename" : "Front.solidimagestacklayer" },
    { "filename" : "Middle.solidimagestacklayer" },
    { "filename" : "Back.solidimagestacklayer" }
  ]
}
```

Each `.solidimagestacklayer/Contents.json` is `{ "info" : { "author" : "xcode", "version" : 1 } }`.
Each layer's `Content.imageset/Contents.json`:

```json
{
  "images" : [ { "filename" : "front.png", "idiom" : "vision", "scale" : "2x" } ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

Every layer is one PNG, 1024 x 1024 px at 2x (512 x 512 pt). The target
keeps `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`.

Rules for the layers: [HIG App icons, visionOS]

- Three layers at most. The back layer is opaque and exactly fills the
  square; the front and middle layers are transparent around their
  shapes.
- Keep the glyph centered: the circle cuts the corners.
- No shape on the background meant to look like a hole: the system
  shadow and highlight make it stand out instead.
- No circle, shadow, or sheen in the art: the system adds them.

## Layers from the same art

The same SVG shapes as `Icon/AppIcon.icon`, on the same square canvas.
`scripts/render_layer.swift`, next to this skill, draws them:

```bash
r="${CLAUDE_SKILL_DIR}/scripts/render_layer.swift"
stack="<visionOS target>/Assets.xcassets/AppIcon.solidimagestack"
swift "$r" layer Icon/AppIcon.icon/Assets/front.svg "$stack/Front.solidimagestacklayer/Content.imageset/front.png" 1024 1024
swift "$r" layer Icon/AppIcon.icon/Assets/back.svg  "$stack/Middle.solidimagestacklayer/Content.imageset/middle.png" 1024 1024
swift "$r" fill "$stack/Back.solidimagestacklayer/Content.imageset/back.png" 1024 1024 336BF5
```

Use the `.icon` file's `fill` color for the back layer (as `RRGGBB`).

Check: the three PNGs exist and are 1024 x 1024 px
(`sips -g pixelWidth -g pixelHeight <file>`).

## Compile and check

```bash
mkdir -p .work/icon/visionos
xcrun actool "<visionOS target>/Assets.xcassets" --compile .work/icon/visionos \
  --platform xros --target-device vision --minimum-deployment-target 26.0 \
  --app-icon AppIcon --output-partial-info-plist .work/icon/visionos/partial.plist \
  --output-format human-readable-text --warnings --notices 2>&1 | grep -E 'error:|warning:'
```

`actool` exits 0 even when it prints errors, so read the output. Seen
with 1000 px layers:

- `The last visionOS App Icon Layer with content, "Back", must exactly fill the image stack.`
- `The visionOS App Icon "AppIcon" can not be used because it does not have the required size {512, 512}.`

Check: no `error:` or `warning:` lines.

## Look at it

`ictool` does not render visionOS. Read a flat preview of the layers
(`swift "$r" preview .work/icon/visionos-preview.png <back> <middle> <front>`)
for the glyph and colors, then the real icon on the visionOS project
simulator's Home View (SKILL.md, step 7).

Check: Claude has read the preview and the Home View screenshot, and the
glyph sits well inside the circle.
