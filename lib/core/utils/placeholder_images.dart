/// Shared fallback image URLs used across presentation widgets when a
/// bespoke asset isn't available yet. Keeps a single source of truth so
/// the two Unsplash photo IDs below don't need to be memorised and
/// copy-pasted into every new screen.
///
/// The photo IDs were chosen in Phase 18 to represent a lean→muscular
/// "before/after" gradient and are safe, commercially-licensed Unsplash
/// photographs. Swap these for CDN-hosted bespoke art when it ships.

library;

/// Muscular aesthetic male torso — the default "after" / aspirational image.
const String defaultMuscularPhotoUrl =
    'https://images.unsplash.com/photo-1581009146145-b5ef050c2e1e?auto=format&fit=crop&w=600&q=80';

/// Lean-build gradient photograph — the default "before" / tone image.
const String defaultLeanPhotoUrl =
    'https://images.unsplash.com/photo-1541534741688-6078c6bfb5c5?auto=format&fit=crop&w=600&q=80';
