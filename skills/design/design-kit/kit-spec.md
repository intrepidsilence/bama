# design/KIT.md template

Copy this into `design/KIT.md` and fill every section. Numbers come from
the reference (`bama:design-from-app`) or from the user's choices. Write
the reason next to any value that looks odd, so nobody "fixes" it later.
Give a column per target platform wherever a value differs; drop the
columns for platforms the app does not target.

```markdown
# <App> design kit

## Feel
Three words: <calm, precise, warm>. Like <reference app, if any>.
Targets: <macos, ios, ipados, tvos, watchos, visionos>.

## Tokens

### Palette
| Name | Light | Dark |
| --- | --- | --- |
| gray50 | #F9FBFC | #1E1F22 |
| blue600 | #287ABC | #4C95D3 |

### Meaning
| Token | Palette | Used for |
| --- | --- | --- |
| Ink.text | gray900 / snow | body text |
| Ink.accent | blue600 | selected text, primary buttons, links |
| Ink.selection | blue100 | selected row fill |

### Metric
| Token | mac | phone | pad | tv | watch | vision | Why |
| --- | --- | --- | --- | --- | --- | --- | --- |
| sidebarWidth | 219 | n/a | 320 | 400 | n/a | 320 | mac measured |
| rowHeight | 26.5 | 44 | 44 | 66 | 44 | 60 | mac measured (0.77 zoom); others HIG default control size |
| focusScale | 1 | 1 | 1 | 1.08 | 1 | 1 | tvOS focus growth |
| focusRoom | 0 | 0 | 0 | 24 | 0 | 0 | space kept around tvOS focusables |

### Motion
| Token | Curve | Used for |
| --- | --- | --- |
| hover | ease out 0.12 s | hover fills |

## Type
| Role | Font | Text style | mac size | Weight | Used for |
| --- | --- | --- | --- | --- | --- |
| title | system | .title | 20.5 | bold | page titles |
| body | system | .body | 10.75 | regular | task titles |

Other targets use the text style's own size unless a row says otherwise.

## Icons
Source: <SF Symbols light / drawn shapes / open set and its license>.
Size per target <mac 13, phone 20, tv 32>, stroke <1.25 at 13>, filled
when selected: <yes/no>.

## Window and navigation
macOS: title bar <hidden>. Traffic lights at <22, 21.5>, <18.25> apart.
Default size <1000 x 742>. Sidebar: <custom rows / List>.
iOS, iPadOS, tvOS, watchOS, visionOS: system bars and ornaments, kit parts
inside them. <Tab bar / split view / stack> per target.

## Parts

### Sidebar row
Anatomy: icon (Metric.icon), gap 4.5, label (label role), optional count.
Size: height Metric.rowHeight, pill inset 9.5, radius 5 (mac).
| State | Targets | Fill | Text | Icon |
| --- | --- | --- | --- | --- |
| rest | all | none | text | icon gray |
| hover | mac, pad pointer | hover gray | text | icon gray |
| gaze | vision | system hover effect | text | icon gray |
| selected | all | selection | accent | accent, filled |
| focused | mac, pad keyboard | ring accent 2 | text | icon gray |
| focused | tv | selection, scale 1.08, shadow | text | icon gray |
| disabled | all | none, 40% | text | icon gray |

### <next part>
...
```
