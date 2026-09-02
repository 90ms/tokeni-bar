# Import local pet packs

[한국어](COMPANION_PACKS.ko.md) | **English**

Tokeni can import local ZIP archives using the Codex Pets V1/V2 contract as
external appearances. An external appearance changes only the primary pet's
art and behavior animation. It does not change species, Growth XP, level,
rarity, egg odds, or collection progress.

## Import and apply an appearance

1. Save a Codex-compatible pet ZIP that you are allowed to use on the Mac.
2. In the Tokeni window, choose **Pets → Pet Packs → Import Pack…**.
3. Optionally enter the author, source URL, license, and notice.
4. Choose **Validate & Install**.
5. Choose **Use Appearance** on the installed pack card.

The appearance is reflected by the primary pet, menu-bar summary, and desktop
pet, and persists across launches. Previewing another archived pet continues to
show that pet's original artwork. Choose **Use original** to restore the bundled
appearance without changing growth data.

Removing a pack deletes only its local artwork and metadata. Removing the active
pack restores the original appearance while preserving the pet and growth history.

## Supported ZIP structure

The ZIP root must contain exactly these two files:

```text
pet.json
spritesheet.webp   # or spritesheet.png
```

Subdirectories, encrypted files, symbolic links, executables, and extra files
are rejected. ZIP64 is not supported. The compressed archive is limited to
64 MiB, total expanded content to 256 MiB, and suspicious compression ratios
are rejected.

A minimal `pet.json` looks like this:

```json
{
  "id": "my-pet",
  "displayName": "My Pet",
  "description": "Optional short description",
  "spritesheetPath": "spritesheet.webp",
  "spriteVersionNumber": 2
}
```

- `id` starts with an ASCII letter or number and uses only ASCII letters,
  numbers, `.`, `_`, and `-`.
- `spritesheetPath` exactly matches `spritesheet.webp` or `spritesheet.png` at
  the archive root.
- An omitted version or `1` selects V1; `2` selects V2.
- V1 is `1536×1872` (8 columns × 9 rows); V2 is `1536×2288`
  (8 columns × 11 rows).
- Each frame is `192×208`; Tokeni preserves this aspect ratio.

## Behavior mapping

| Tokeni behavior | Codex row |
| --- | --- |
| Idle | Idle |
| Working | Review |
| Waiting | Waiting |
| Warning | Failed |
| Celebrate and signature | Waving |
| Sleep | First Idle frame |

V1 and V2 share the first nine behavior rows. Tokeni does not currently use
V2's additional look-direction rows for primary-pet behavior.

## Rights and privacy

- Availability for download does not grant redistribution or derivative-work rights.
- Tokeni shows packs without license data as `Unspecified · local use`.
- Confirm rights before using public figures, brands, or protected characters.
- Packs stay in this Mac's Application Support directory; Tokeni does not upload
  them to an external gallery.
- Pack metadata never stores provider names, token totals, prompts, responses,
  or credentials.

The compatibility contract follows the
[public Codex Pets repository](https://github.com/astandrik/codex-pets).
Tokeni's local compatibility feature is independent of that service.
