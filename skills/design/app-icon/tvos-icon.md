# tvOS app icon and Top Shelf image

tvOS does not take the Icon Composer file. Its icon is a stack of 2 to 5
image layers in the tvOS target's asset catalog. When the icon is
focused, it lifts, sways with the remote, and the layers move apart
(parallax). The same catalog holds the Top Shelf image. [HIG App icons,
Top Shelf; Xcode, Configuring your app icon]

Structure and sizes below were checked by compiling this exact catalog
with `actool` from Xcode 27 (`--platform appletvos --target-device tv`):
the right sizes compile clean, and wrong ones produce the warnings and
errors listed under Checks.

## Contents

- The catalog
- Layers from the same art
- Compile and check
- Look at it

## The catalog

In the tvOS target's `Assets.xcassets/`:

```text
App Icon & Top Shelf Image.brandassets/
  Contents.json
  App Icon.imagestack/                  400 x 240 pt, 1x and 2x
    Contents.json
    Front.imagestacklayer/Contents.json
    Front.imagestacklayer/Content.imageset/{Contents.json, front.png, front@2x.png}
    Middle.imagestacklayer/...          same shape as Front
    Back.imagestacklayer/...            same shape as Front
  App Icon - App Store.imagestack/      1280 x 768 pt, 1x only
    (the same three layers, one PNG each)
  Top Shelf Image.imageset/             1920 x 720 pt, 1x and 2x
  Top Shelf Image Wide.imageset/        2320 x 720 pt, 1x and 2x
```

`App Icon & Top Shelf Image.brandassets/Contents.json`:

```json
{
  "assets" : [
    { "filename" : "App Icon - App Store.imagestack", "idiom" : "tv", "role" : "primary-app-icon", "size" : "1280x768" },
    { "filename" : "App Icon.imagestack", "idiom" : "tv", "role" : "primary-app-icon", "size" : "400x240" },
    { "filename" : "Top Shelf Image Wide.imageset", "idiom" : "tv", "role" : "top-shelf-image-wide", "size" : "2320x720" },
    { "filename" : "Top Shelf Image.imageset", "idiom" : "tv", "role" : "top-shelf-image", "size" : "1920x720" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

Each `.imagestack/Contents.json` lists its layers, front first:

```json
{
  "layers" : [
    { "filename" : "Front.imagestacklayer" },
    { "filename" : "Middle.imagestacklayer" },
    { "filename" : "Back.imagestacklayer" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

Each `.imagestacklayer/Contents.json` is `{ "info" : { "author" : "xcode", "version" : 1 } }`.
Each layer's `Content.imageset/Contents.json` names its PNGs:

```json
{
  "images" : [
    { "filename" : "front.png", "idiom" : "tv", "scale" : "1x" },
    { "filename" : "front@2x.png", "idiom" : "tv", "scale" : "2x" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

The App Store stack's image sets list only the `1x` entry. The Top Shelf
image sets list a `1x` and a `2x` entry like the layer above.

Pixel sizes:

| Image | 1x | 2x |
| --- | --- | --- |
| App Icon layer | 400 x 240 | 800 x 480 |
| App Icon - App Store layer | 1280 x 768 | none |
| Top Shelf Image | 1920 x 720 | 3840 x 1440 |
| Top Shelf Image Wide | 2320 x 720 | 4640 x 1440 |

The target's build setting names the brand assets, not the stack:
`ASSETCATALOG_COMPILER_APPICON_NAME = "App Icon & Top Shelf Image"` (in
XcodeGen, under the tvOS target's `settings`). Xcode's own tvOS template
uses that name.

Rules for the layers: [HIG App icons, tvOS]

- 2 to 5 layers. Three (front, middle, back) is Xcode's default.
- The back layer is opaque and exactly fills the stack. Upper layers are
  transparent around their shapes.
- Keep a safe zone: when focused, the system crops the edges, and crops
  front layers more than back ones. Keep the glyph well inside the
  rectangle.
- Text, if any, sits on the top layer so parallax does not crop it.
- No rounded corners, shadow, or sheen in the art: the system adds them.

Top Shelf: the static image shows when the app is in the Dock (the top
row of the Home screen), focused, and gives no dynamic Top Shelf content.
The HIG gives only the wide size (2320 x 720 pt); fill both image sets so
the catalog compiles without warnings. Never make it look
tappable: it is not focusable. [HIG Top Shelf]

## Layers from the same art

The tvOS icon uses the same SVG shapes as `Icon/AppIcon.icon`, centered on
a wider canvas. `scripts/render_layer.swift`, next to this skill, draws
them:

```bash
r="${CLAUDE_SKILL_DIR}/scripts/render_layer.swift"
stack="<tvOS target>/Assets.xcassets/App Icon & Top Shelf Image.brandassets/App Icon.imagestack"
for spec in "1 " "2 @2x"; do
  scale=${spec%% *}; s=${spec#* }; w=$((400 * scale)); h=$((240 * scale))
  swift "$r" layer Icon/AppIcon.icon/Assets/front.svg "$stack/Front.imagestacklayer/Content.imageset/front$s.png" $w $h --fit 0.9
  swift "$r" layer Icon/AppIcon.icon/Assets/back.svg  "$stack/Middle.imagestacklayer/Content.imageset/middle$s.png" $w $h --fit 0.9
  swift "$r" fill "$stack/Back.imagestacklayer/Content.imageset/back$s.png" $w $h 336BF5
done
```

Use the `.icon` file's `fill` color for the back layer (as `RRGGBB`). Do
the same at 1280 x 768 for the App Store stack. For Top Shelf, draw a
wide image of the app's content or brand at the sizes above.

Check: every PNG the catalog names exists at the pixel size in the table.

## Compile and check

Xcode compiles the catalog with the target. To check it alone:

```bash
mkdir -p .work/icon/tvos
xcrun actool "<tvOS target>/Assets.xcassets" --compile .work/icon/tvos \
  --platform appletvos --target-device tv --minimum-deployment-target 26.0 \
  --app-icon "App Icon & Top Shelf Image" \
  --output-partial-info-plist .work/icon/tvos/partial.plist \
  --output-format human-readable-text --warnings --notices 2>&1 | grep -E 'error:|warning:'
plutil -p .work/icon/tvos/partial.plist
```

`actool` exits 0 even when it prints errors, so read the output. Seen
when sizes were wrong:

- `The last image stack layer with content, "Back", must exactly fill the image stack.`
- `Top Shelf Image/b.png is 3850x1440 but should be 3840x1440.`

A clean catalog prints no `error:` or `warning:` lines, and the partial
plist has `CFBundlePrimaryIcon` = `App Icon` and a `TVTopShelfImage`
entry with `TVTopShelfPrimaryImage` and `TVTopShelfPrimaryImageWide`.

Check: no `error:` or `warning:` lines, and the partial plist has those
keys.

## Look at it

`ictool` does not render tvOS. Two views instead:

1. A flat preview of the layers, for the glyph and the colors:

   ```bash
   swift "$r" preview .work/icon/tvos-preview.png \
     "$stack/Back.imagestacklayer/Content.imageset/back@2x.png" \
     "$stack/Middle.imagestacklayer/Content.imageset/middle@2x.png" \
     "$stack/Front.imagestacklayer/Content.imageset/front@2x.png"
   ```

2. The real icon on the tvOS project simulator's Home screen (SKILL.md,
   step 7). Parallax needs the remote; Apple's Parallax Previewer (Apple
   Design Resources) shows it on the Mac.

Check: Claude has read the preview and the Home screen screenshot, and
the glyph sits inside the safe zone with room on every side.
