---
name: Apiary Logistics Framework
colors:
  surface: '#fbf9f8'
  surface-dim: '#dbd9d9'
  surface-bright: '#fbf9f8'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f5f3f3'
  surface-container: '#efeded'
  surface-container-high: '#eae8e7'
  surface-container-highest: '#e4e2e2'
  on-surface: '#1b1c1c'
  on-surface-variant: '#424846'
  inverse-surface: '#303030'
  inverse-on-surface: '#f2f0f0'
  outline: '#727876'
  outline-variant: '#c2c8c4'
  surface-tint: '#4b635c'
  primary: '#08201a'
  on-primary: '#ffffff'
  primary-container: '#1e352f'
  on-primary-container: '#859e96'
  inverse-primary: '#b2ccc3'
  secondary: '#7d5700'
  on-secondary: '#ffffff'
  secondary-container: '#fdbe49'
  on-secondary-container: '#704e00'
  tertiary: '#1b1c1b'
  on-tertiary: '#ffffff'
  tertiary-container: '#30312f'
  on-tertiary-container: '#999996'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#cee8df'
  primary-fixed-dim: '#b2ccc3'
  on-primary-fixed: '#071f1a'
  on-primary-fixed-variant: '#344b45'
  secondary-fixed: '#ffdeab'
  secondary-fixed-dim: '#fabc46'
  on-secondary-fixed: '#271900'
  on-secondary-fixed-variant: '#5f4100'
  tertiary-fixed: '#e3e2e0'
  tertiary-fixed-dim: '#c7c6c4'
  on-tertiary-fixed: '#1a1c1a'
  on-tertiary-fixed-variant: '#464745'
  background: '#fbf9f8'
  on-background: '#1b1c1c'
  surface-variant: '#e4e2e2'
typography:
  display-lg:
    fontFamily: Manrope
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Manrope
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  title-sm:
    fontFamily: Manrope
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-caps:
    fontFamily: Work Sans
    fontSize: 12px
    fontWeight: '700'
    lineHeight: 16px
    letterSpacing: 0.05em
  data-mono:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: 0.02em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 8px
  xs: 4px
  sm: 12px
  md: 24px
  lg: 32px
  xl: 48px
  container-margin: 20px
  gutter: 16px
---

## Brand & Style

The design system is rooted in "Professional Premium" minimalism, blending the organic heritage of beekeeping with the precision of modern logistics. It targets logistics managers and drivers who require clarity under varying environmental conditions—from high-noon glare to late-night transit.

The aesthetic follows a **Corporate / Modern** style with **Tactile** accents. It utilizes significant whitespace to reduce cognitive load while employing "Gold/Honey" accents to guide the user's eye toward critical actions and status updates. The emotional response is one of stability, luxury, and meticulous organization.

**Design Principles:**
- **Clarity over Clutter:** Every element must serve a functional purpose in the logistics chain.
- **Organic Precision:** Use of hexagonal geometry (subtle) to nod to beekeeping, paired with rigid grid alignment.
- **Night-Optimized:** Surfaces are designed to remain legible and low-strain in dark cabins.

## Colors

The palette is anchored by **Dark Forest Green**, evoking the natural environment of the apiary while providing a deep, authoritative base for high-contrast text. **Gold/Honey** is reserved strictly for interactive elements, progress indicators, and "Active" logistics statuses.

The background uses **Off-white/Cream** to provide a softer, more premium feel than pure white, reducing eye strain during extended use. For night-time optimization, the design system implements a "Dimmed Primary" mode where surfaces shift to deep green-greys, but for the standard interface, high-contrast text (Primary on Cream) ensures legibility in all lighting.

## Typography

Typography is tiered to handle complex logistics data. **Manrope** provides a modern, balanced feel for headers, while **Inter** ensures that dense shipping lists and weight data remain perfectly legible. 

**Work Sans** is utilized for "Label-caps" styles to categorize data points (e.g., "TRUCK CAPACITY" or "ROUTE ID"), providing a technical, grounded feel. Numerical data should always use slightly increased letter spacing to prevent digit confusion during quick glances.

## Layout & Spacing

The system employs a **Fluid Grid** based on an 8px square rhythm. On mobile devices, a 4-column grid is used with 20px outside margins. 

Layouts are vertically stacked to prioritize the "next action" in the logistics workflow. Content cards utilize "Internal Padding" of 24px (md) to ensure data density doesn't feel overwhelming. Negative space is used aggressively between distinct sections (Route vs. Load) to maintain a premium, uncluttered appearance.

## Elevation & Depth

This design system avoids heavy drop shadows in favor of **Tonal Layers** and **Low-Contrast Outlines**. 

- **Level 0 (Background):** Off-white/Cream (#faf9f6).
- **Level 1 (Cards):** Pure White (#ffffff) with a 1px border in a very faint primary tint (5% opacity).
- **Level 2 (Active/Modals):** Subtle ambient shadows with a Dark Forest Green tint (10% opacity, 20px blur) to create a soft lift without looking "gamey."
- **Interactive Depth:** Buttons use a slight inset shadow on press to provide tactile feedback, mimicking a physical depression.

## Shapes

The shape language is "Sophisticated Soft." Elements utilize a 0.5rem (8px) base radius to appear approachable yet professional. 

**Specific Applications:**
- **Cards:** 1rem (16px) for major containers like Status Cards and Map Overlays.
- **Action Buttons:** 0.5rem (8px) for a structured, reliable feel.
- **Status Chips:** Full Pill (rounded-full) to distinguish them from interactive buttons.
- **Logistics Icons:** Use of the hexagon for framing iconography related to "Hives" or "Storage Units."

## Components

### Buttons
- **Primary:** Dark Forest Green background with Cream text. 
- **Action/CTA:** Gold/Honey background with Primary Green text for maximum contrast on critical steps like "Start Route."
- **Ghost:** Border-only Primary Green with 1px width.

### Detailed Status Cards
Logistics cards should feature a split-layout: 
- **Top section:** Bold ID and Status Chip. 
- **Middle section:** Data grid (e.g., Net weight, Hive count) using the `label-caps` typography for keys. 
- **Bottom section:** Progress bar in Gold/Honey representing load capacity or distance remaining.

### Maps
Map styles should be customized to "Silver" or "Dark" modes to match the Primary color. Route lines should be Gold/Honey with a subtle outer glow for night-time visibility. Waypoints are represented by Primary Green hexagonal pins.

### Logistics Iconography
Icons must be "Line-Style" with a 2px stroke. Custom icons include:
- **Hive:** Hexagonal silhouette with three internal lines.
- **Smoker:** Representing maintenance/inspection.
- **Truck:** Flat-bed profile specific to apiary transport.
- **Temperature/Humidity:** Combined gauge icon for sensitive honey transport.

### Input Fields
Filled style using a very light Cream-Grey tint, with a 2px bottom-border that turns Gold/Honey on focus.