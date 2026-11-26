# Localization

Godot loads the five gettext catalogs listed in `project.godot`. Add the same message ID to each `.po` file and reference it through `tr()` in scenes and scripts. Keep format placeholders and their order intact. The pause menu, roster, encyclopedia, and HUD use the language selected from the main menu.

The CJK font is a subset for the Simplified Chinese catalog. When adding Chinese glyphs, regenerate it from Noto Sans SC using the updated `zh_CN.po` as input to FontTools `subset`. Include Latin and Greek ranges and preserve layout features. The Arabic fallback includes the Arabic Unicode blocks and preserves shaping features. The font sources are [Noto Sans SC](https://github.com/google/fonts/tree/main/ofl/notosanssc) and [Noto Sans Arabic](https://github.com/google/fonts/tree/main/ofl/notosansarabic). Their licenses are in `fonts`.

The language picker uses MIT-licensed [flag-icons](https://github.com/lipis/flag-icons) SVGs. See `flags/LICENSE.txt`.
