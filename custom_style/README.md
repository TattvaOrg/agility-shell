# Agility Shell Custom Styles (`custom_style/`)

This directory is where all user styling customizations live. Any changes made to the files here take precedence over system defaults in `style/` and are automatically live-reloaded by Agility Shell upon saving.

---

### Files in this Directory

| File | Purpose | Example |
| :--- | :--- | :--- |
| `font.css` | Typography and font imports | Google Fonts (`@import url(...)`) or local fonts |
| `color.css` | Custom color palette overrides | Palette tokens (`--primary`, `--background`, `--surface`, etc.) |
| `border.css` | Corner roundness and radius | Radius scales (`--radius-s`, `--radius-m`, `--radius-l`, `--radius-xl`) |
| `custom.css` *(optional)* | Arbitrary custom CSS rules | Freeform widget overrides (e.g. `.bar { background-color: ...; }`) |

---

### Defaults vs Customizations

- **`style/`**: Contains clean system defaults installed with Agility Shell (never edit directly).
- **`custom_style/`**: Your personal configuration folder. Uncomment and edit any example to customize your desktop.
