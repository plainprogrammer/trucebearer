# Unit and supply-center icons

The master drawings for the pieces on the board: an army, a fleet and a supply center. The web app inlines these files and colors them; a later map starts from them.

The drawings are original work, drawn by hand as plain paths. They are not traced from, or adapted from, any edition of the game, any icon set or any other project.

## License

These files are licensed under CC BY-SA 4.0. See `assets/LICENSE` and the map in the root `NOTICE`.

## The files

| File | What it is | Drawn for |
|---|---|---|
| `army.svg` | A shield with two stacked chevrons | 24 pixels and up |
| `army-small.svg` | The same shield with thicker chevrons and a wider shield | Under 24 pixels |
| `fleet.svg` | A side-on warship facing right, with a superstructure, a mast, a forward gun and five portholes | 24 pixels and up |
| `fleet-small.svg` | The same ship with a thicker mast and gun and two larger portholes | Under 24 pixels |
| `supply-center.svg` | A two-ring roundel: a disk, a ring around it and a dot in the middle | Every size |
| `preview.png` | A contact sheet of every icon, described below | Review only; not used by the app |

Every file has a 32-unit `viewBox` (`0 0 32 32`), no `width` or `height` (the app sets the size), and no `<style>`, text, fonts, embedded images or editor metadata. Coordinates have at most one decimal place. The files carry no `<title>`: the app adds the accessible label.

## Parts the app relies on

The app finds each part by name. Keep the names and the one-path-per-part structure when you edit a drawing.

| File | Part | How to find it | Default fill |
|---|---|---|---|
| `army*.svg`, `fleet*.svg` | The silhouette: one path | `#silhouette` | `currentColor` |
| `army*.svg`, `fleet*.svg` | The white marks (chevrons, portholes): one path each, inside a group | `#marks` (the group) and `.mark` (each path) | White, set on the group |
| `supply-center.svg` | The disk | `#disk` | White |
| `supply-center.svg` | The edge: a ring drawn with the even-odd rule | `#edge` | `currentColor` |
| `supply-center.svg` | The center | `#center` | `currentColor` |

How the app uses them:

- **Units.** It sets `color` to the power's color, which colors the silhouette. The marks stay white. Nothing is drawn in the bottom-right corner (see below), so the app can lay a power-initial tag there.
- **Unowned supply center.** The defaults are the unowned look: a white disk with the edge and the center in `currentColor`. The app sets `color` to the text color (Iron, `#22262b`).
- **Owned supply center.** The app sets the fill of `#disk` and `#edge` to the owner's color and the fill of `#center` to white.

## The tag corner

In the unit drawings, nothing is drawn in the bottom-right 12 by 12 units (x above 20 and y above 20). The silhouette and every mark stay out of it. The app puts a power-initial tag there. The fleet sits entirely above a flat waterline at y = 20. The army shield is centered on the line x = 11.5, so it narrows away from the corner.

## The contact sheet

`preview.png` shows each unit icon at 20, 32 and 48 pixels, in olive (`#586f2a`, drawn here as Austria with the initial A) and oxblood (`#822635`, drawn here as England with the initial E). The 20-pixel row uses the `-small` drawings. Each power's panel also shows its supply center, and a strip at the bottom shows the unowned supply center. The tag in the sheet is an approximation made for review: a white tile with a colored border and a monospace initial. The real tag comes from the app.
