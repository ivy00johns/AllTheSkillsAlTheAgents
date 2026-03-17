# Example: Project-Specific Image Configuration

This is an example of how a project can configure Nano Banana for its specific needs. Copy and adapt this pattern into your project's docs.

## Authentic Wardrobe (Reference Example)

### Image Paths
- Product images: `public/images/products/[slug].jpg`
- Lifestyle variants: `public/images/products/[slug]-lifestyle.jpg`
- Hero banners: `public/images/banners/[name].jpg`
- Detail shots: `public/images/details/[name].jpg`
- About page: `public/images/about/[name].jpg`

### Prompt Style Guide
**Tone**: Luxury historical fashion editorial — aspirational, historically authentic, never costume-party.

**Required elements**:
- Specific fabric descriptions (heavy 7oz twill, rough-woven wool, velvet pile)
- Period-accurate details (not generic "medieval")
- Lighting direction (side lighting, warm torchlight, golden hour)
- Setting that grounds the image (stone courtyard, aged oak table, misty forest)
- Aspect ratio and intended use as the final bold line

**Anti-costume modifier** (append to prompts):
> "The styling should feel historically authentic and aspirational — as if this were a fashion editorial for a luxury historical clothing brand, not a Halloween costume advertisement."

### Tracking
The prompts document at `docs/authentic-wardrobe-nano-banana-prompts.md` tracks:
- ⬜ = not yet generated
- 🔄 = generated, awaiting review
- ✅ = approved and integrated
