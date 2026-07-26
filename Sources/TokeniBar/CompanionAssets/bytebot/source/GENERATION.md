# ByteBot rarity sprite generation

The rarity sheets are original Tokeni Bar assets created with the built-in OpenAI
image generation tool and finished with local chroma-key removal.

The existing original `baby.png` and `adult.png` sheets were used only as ByteBot
identity, pose, and frame-layout references. The generation prompts required:

- an unchanged 8-column by 6-row animation layout;
- crisp 32 px pixel art shown at 2× scale;
- a flat `#FF00FF` removable background;
- no text, watermark, gradients, blur, added frames, or removed frames;
- Rare cobalt/violet side fins;
- Epic indigo/gold armor and compact energy wings;
- Legendary navy/cyan/gold crown and orbital halo;
- a new taller Junior silhouette between Hatchling and Adult.

The flat background was converted to alpha with the image generation skill's
`remove_chroma_key.py` helper. Runtime frame extraction derives cell dimensions
from each sheet so the original and generated sheets can retain their native
pixel dimensions without resampling.
