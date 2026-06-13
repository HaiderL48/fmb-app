# FMB Style Guide

## Overview
This document provides a comprehensive reference for all styling used in the FMB (Food Package Subscription) application. The design system uses Tailwind CSS v4 with custom CSS variables defined in `src/styles/theme.css`.

---

## Color Palette

### Primary Colors (FMB Brand Colors)

| Color Name | CSS Variable | Hex Value | Usage |
|------------|--------------|-----------|-------|
| **Primary Teal** | `--fmb-primary` | `#2D6A7E` | Main background color, primary buttons, accent elements |
| **Primary Teal Dark** | `--fmb-primary-dark` | `#1E5A6D` | Hover states, darker gradients |
| **Accent Gold** | `--fmb-accent` | `#FFC107` | Text on primary background, highlights, badges |
| **Accent Gold Dark** | `--fmb-accent-dark` | `#FFB300` | Hover states for gold elements |

**Usage Examples:**
```css
/* Primary button */
bg-[#2D6A7E] hover:bg-[#1E5A6D] text-[#FFC107]

/* Gradient background */
bg-gradient-to-br from-[#2D6A7E] to-[#1E5A6D]

/* Text color on dark background */
text-[#FFC107]
```

### System Colors (Tailwind Theme)

| Color Name | CSS Variable | Light Mode | Usage |
|------------|--------------|------------|-------|
| **Background** | `--background` | `#ffffff` | Page backgrounds |
| **Foreground** | `--foreground` | `oklch(0.145 0 0)` | Primary text color |
| **Card** | `--card` | `#ffffff` | Card backgrounds |
| **Card Foreground** | `--card-foreground` | `oklch(0.145 0 0)` | Card text color |
| **Primary** | `--primary` | `#030213` | System primary (dark) |
| **Primary Foreground** | `--primary-foreground` | `oklch(1 0 0)` | Text on primary background |
| **Secondary** | `--secondary` | `oklch(0.95 0.0058 264.53)` | Secondary UI elements |
| **Secondary Foreground** | `--secondary-foreground` | `#030213` | Text on secondary |
| **Muted** | `--muted` | `#ececf0` | Muted backgrounds |
| **Muted Foreground** | `--muted-foreground` | `#717182` | Muted text |
| **Accent** | `--accent` | `#e9ebef` | Accent backgrounds |
| **Accent Foreground** | `--accent-foreground` | `#030213` | Accent text |
| **Destructive** | `--destructive` | `#d4183d` | Error/delete actions |
| **Destructive Foreground** | `--destructive-foreground` | `#ffffff` | Text on destructive |

### Semantic Colors

| Color | Tailwind Classes | Usage |
|-------|-----------------|-------|
| **Success Green** | `bg-green-50`, `text-green-800`, `border-green-200` | Success messages, active status |
| **Info Blue** | `bg-blue-50`, `text-blue-800`, `border-blue-200` | Information boxes |
| **Warning Amber** | `bg-amber-50`, `text-amber-900`, `border-amber-200` | Warnings, pending status |
| **Gray Neutral** | `bg-gray-50`, `bg-gray-100`, `text-gray-500`, `text-gray-600`, `text-gray-700` | Neutral backgrounds, secondary text |

---

## Borders

### Border Colors

| Purpose | CSS Variable | Value | Tailwind Class |
|---------|--------------|-------|----------------|
| **Default Border** | `--border` | `rgba(0, 0, 0, 0.1)` | `border`, `border-border` |
| **Input Border** | `--input` | `transparent` | `border-input` |
| **Sidebar Border** | `--sidebar-border` | `oklch(0.922 0 0)` | `border-sidebar-border` |

### Border Radius

| Size | CSS Variable | Computed Value | Usage |
|------|--------------|----------------|-------|
| **Small** | `--radius-sm` | `calc(0.625rem - 4px)` ≈ `6px` | Small elements |
| **Medium** | `--radius-md` | `calc(0.625rem - 2px)` ≈ `8px` | Medium elements |
| **Large** | `--radius-lg` | `0.625rem` = `10px` | Cards, main containers |
| **Extra Large** | `--radius-xl` | `calc(0.625rem + 4px)` ≈ `14px` | Large containers |

**Tailwind Classes:**
```css
/* Rounded corners */
rounded-md      /* Medium radius */
rounded-lg      /* Large radius */
rounded-xl      /* Extra large radius */
rounded-full    /* Fully rounded (circles) */
```

### Border Widths

```css
border         /* 1px border all sides */
border-0       /* No border */
border-2       /* 2px border */
border-t       /* Top border only */
border-b       /* Bottom border only */
```

---

## Shadows

### Box Shadows

| Name | Tailwind Class | Usage |
|------|----------------|-------|
| **Small** | `shadow-sm` | Subtle elevation |
| **Medium** | `shadow-md` | Cards, elevated elements |
| **Large** | `shadow-lg` | Important cards |
| **Extra Large** | `shadow-xl` | Modals, popovers |
| **2X Large** | `shadow-2xl` | Login card, dialogs |
| **None** | `shadow-none` | Flat elements |

**Usage Examples:**
```css
/* Card with medium shadow */
<Card className="shadow-md">

/* Login card with large shadow */
<Card className="w-full max-w-md shadow-2xl">

/* Gradient card with shadow */
<Card className="bg-gradient-to-br from-[#2D6A7E] to-[#1E5A6D] shadow-lg">
```

---

## Focus & Active States

### Focus Ring

| Property | CSS Variable | Value |
|----------|--------------|-------|
| **Ring Color** | `--ring` | `oklch(0.708 0 0)` |
| **Ring Width** | - | `3px` |
| **Ring Opacity** | - | `50%` |

**Tailwind Classes:**
```css
/* Focus visible states */
focus-visible:border-ring
focus-visible:ring-ring/50
focus-visible:ring-[3px]

/* Outline (default) */
outline-none
outline-ring/50
```

### Active States (Buttons)

```css
/* Primary button active */
bg-[#2D6A7E] hover:bg-[#1E5A6D]

/* Menu day selector active */
bg-[#2D6A7E] text-[#FFC107] shadow-md

/* Default button hover */
hover:bg-primary/90

/* Ghost button hover */
hover:bg-accent hover:text-accent-foreground
```

### Invalid States

```css
/* Input invalid */
aria-invalid:ring-destructive/20
aria-invalid:border-destructive
dark:aria-invalid:ring-destructive/40
```

---

## Typography

### Font Sizes

| Element | CSS Variable | Size | Line Height |
|---------|--------------|------|-------------|
| **Base** | `--text-base` | `16px` | `1.5` |
| **Large** | `--text-lg` | `18px` | `1.5` |
| **Extra Large** | `--text-xl` | `20px` | `1.5` |
| **2X Large** | `--text-2xl` | `24px` | `1.5` |

### Font Weights

| Name | CSS Variable | Value |
|------|--------------|-------|
| **Normal** | `--font-weight-normal` | `400` |
| **Medium** | `--font-weight-medium` | `500` |

### Default Typography Styles

```css
/* Headings */
h1: font-size: var(--text-2xl), font-weight: medium, line-height: 1.5
h2: font-size: var(--text-xl), font-weight: medium, line-height: 1.5
h3: font-size: var(--text-lg), font-weight: medium, line-height: 1.5
h4: font-size: var(--text-base), font-weight: medium, line-height: 1.5

/* Form elements */
label: font-size: base, font-weight: medium, line-height: 1.5
button: font-size: base, font-weight: medium, line-height: 1.5
input: font-size: base, font-weight: normal, line-height: 1.5
```

### Tailwind Typography Classes

```css
/* Font sizes */
text-xs     /* Extra small */
text-sm     /* Small */
text-base   /* Base (16px) */
text-lg     /* Large */
text-xl     /* Extra large */
text-2xl    /* 2X large */

/* Font weights */
font-normal     /* 400 */
font-medium     /* 500 */
font-semibold   /* 600 */
font-bold       /* 700 */

/* Text colors */
text-gray-500
text-gray-600
text-gray-700
text-gray-900
text-[#FFC107]
text-[#2D6A7E]
```

---

## Component Styles

### Button Variants

| Variant | Classes | Usage |
|---------|---------|-------|
| **Default** | `bg-primary text-primary-foreground hover:bg-primary/90` | Primary actions |
| **FMB Primary** | `bg-[#2D6A7E] hover:bg-[#1E5A6D] text-[#FFC107]` | Brand-specific buttons |
| **Destructive** | `bg-destructive text-white hover:bg-destructive/90` | Delete/cancel actions |
| **Outline** | `border bg-background hover:bg-accent` | Secondary actions |
| **Secondary** | `bg-secondary text-secondary-foreground hover:bg-secondary/80` | Less prominent actions |
| **Ghost** | `hover:bg-accent hover:text-accent-foreground` | Minimal actions |
| **Link** | `text-primary underline-offset-4 hover:underline` | Link-style buttons |

### Button Sizes

| Size | Classes | Height | Usage |
|------|---------|--------|-------|
| **Small** | `h-8 px-3` | `32px` | Compact buttons |
| **Default** | `h-9 px-4` | `36px` | Standard buttons |
| **Large** | `h-10 px-6` | `40px` | Prominent buttons |
| **Custom** | `h-12` | `48px` | Extra large (FMB login/submit) |
| **Icon** | `size-9` | `36px × 36px` | Icon-only buttons |

### Card Styles

```css
/* Base card */
bg-card text-card-foreground rounded-xl border

/* Card with shadow */
<Card className="shadow-md">

/* Gradient card */
<Card className="bg-gradient-to-br from-[#2D6A7E] to-[#1E5A6D] text-white border-0 shadow-lg">

/* Quick stat card */
<Card className="shadow-md">
  <CardContent className="pt-5 pb-5">
```

### Badge Variants

| Variant | Classes | Usage |
|---------|---------|-------|
| **Default** | `bg-primary text-primary-foreground` | Primary status |
| **Secondary** | `bg-secondary text-secondary-foreground` | Secondary status |
| **Destructive** | `bg-destructive text-white` | Error/warning status |
| **Outline** | `border text-foreground` | Neutral status |
| **Success** | `bg-green-100 text-green-800` | Success/active status |
| **Warning** | `bg-amber-100 text-amber-800` | Warning/pending status |

### Input Styles

```css
/* Base input */
border-input bg-input-background rounded-md px-3 py-1 h-9

/* With icon */
<Input className="pl-10 h-12" />

/* Focus state */
focus-visible:border-ring focus-visible:ring-ring/50 focus-visible:ring-[3px]

/* Invalid state */
aria-invalid:ring-destructive/20 aria-invalid:border-destructive
```

---

## Spacing

### Padding

```css
/* Component padding */
px-3   /* 12px horizontal */
px-4   /* 16px horizontal */
px-6   /* 24px horizontal (card standard) */
py-1   /* 4px vertical */
py-2   /* 8px vertical */
pt-5   /* 20px top */
pb-6   /* 24px bottom */

/* Card padding */
CardHeader: px-6 pt-6
CardContent: px-6 [&:last-child]:pb-6
CardFooter: px-6 pb-6
```

### Gaps

```css
/* Spacing between elements */
gap-1      /* 4px */
gap-2      /* 8px */
gap-3      /* 12px */
gap-4      /* 16px */
gap-6      /* 24px */

/* Grid gaps */
grid gap-3  /* For quick stats grid */
```

### Margin

```css
/* Margin utilities */
m-2      /* 8px all sides */
mt-2     /* 8px top */
mb-2     /* 8px bottom */
-mx-1    /* -4px horizontal (negative) */
```

---

## Gradients

### Background Gradients

```css
/* Primary gradient (login, welcome card) */
bg-gradient-to-br from-[#2D6A7E] via-[#256B7D] to-[#2D6A7E]

/* Card gradient (teal) */
bg-gradient-to-br from-[#2D6A7E] to-[#1E5A6D]

/* Menu display gradient */
bg-gradient-to-br from-gray-50 to-gray-100
```

---

## Icon Styles

### Icon Sizes

```css
/* Standard icon sizes */
w-4 h-4    /* 16px - small inline icons */
w-5 h-5    /* 20px - standard icons */
w-6 h-6    /* 24px - large icons */
w-10 h-10  /* 40px - icon containers */

/* Icon in button */
<LogIn className="w-5 h-5 mr-2" />
```

### Icon Colors

```css
/* Icon colors */
text-gray-400      /* Placeholder/disabled icons */
text-[#2D6A7E]     /* Primary icons */
text-[#FFC107]     /* Accent icons */
text-white         /* Icons on dark background */
```

### Icon Containers

```css
/* Circle icon background */
w-10 h-10 bg-[#2D6A7E]/10 rounded-full flex items-center justify-center

/* Icon with teal background */
<div className="w-10 h-10 bg-[#2D6A7E]/10 rounded-full flex items-center justify-center">
  <Package className="w-5 h-5 text-[#2D6A7E]" />
</div>

/* Icon with gold background */
<div className="w-10 h-10 bg-[#FFC107]/10 rounded-full flex items-center justify-center">
  <CreditCard className="w-5 h-5 text-[#FFC107]" />
</div>
```

---

## Transition & Animation

### Transition Classes

```css
/* Standard transitions */
transition-all           /* All properties */
transition-[color,box-shadow]   /* Specific properties */

/* Duration */
duration-200            /* 200ms */
duration-300            /* 300ms */
```

### Transform

```css
/* Icon positioning */
transform -translate-y-1/2   /* Center vertically */
```

---

## Layout Patterns

### Page Layout

```css
/* Main container */
<div className="min-h-screen bg-gradient-to-br from-[#2D6A7E] to-[#1E5A6D]">

/* Content spacing */
<div className="space-y-4">
```

### Grid Layouts

```css
/* Two-column grid (quick stats) */
<div className="grid grid-cols-2 gap-3">

/* Three-column grid */
<div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
```

### Flexbox Patterns

```css
/* Center content */
flex items-center justify-center

/* Space between */
flex items-center justify-between

/* Vertical stack */
flex flex-col gap-2
```

---

## Responsive Design

### Mobile-First Breakpoints

```css
/* Tailwind default breakpoints */
sm:   640px
md:   768px
lg:   1024px
xl:   1280px
2xl:  1536px
```

### Common Responsive Patterns

```css
/* Text size */
text-base md:text-sm

/* Grid columns */
grid-cols-1 md:grid-cols-2 lg:grid-cols-3

/* Padding */
p-4 md:p-6 lg:p-8
```

---

## Status Indicators

### Status Colors

| Status | Background | Text | Border |
|--------|------------|------|--------|
| **Active** | `bg-green-100` | `text-green-800` | `border-green-200` |
| **Pending** | `bg-amber-100` | `text-amber-800` | `border-amber-200` |
| **Expired** | `bg-red-100` | `text-red-800` | `border-red-200` |
| **Completed** | `bg-blue-100` | `text-blue-800` | `border-blue-200` |

### Progress Bar

```css
/* Progress component */
<Progress value={75} className="h-2" />

/* Color customization via CSS variable */
/* Uses primary color by default */
```

---

## Common Component Patterns

### Login/Form Card

```css
<Card className="w-full max-w-md shadow-2xl">
  <CardHeader className="text-center space-y-4 pb-8">
    <CardTitle className="text-2xl font-bold">
    <CardDescription className="text-base mt-2">
  </CardHeader>
  <CardContent>
    <form className="space-y-5">
```

### Icon Input Field

```css
<div className="relative">
  <User className="absolute left-3 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gray-400" />
  <Input className="pl-10 h-12" />
</div>
```

### Stat Card

```css
<Card className="shadow-md">
  <CardContent className="pt-5 pb-5">
    <div className="flex items-center gap-3">
      <div className="w-10 h-10 bg-[#2D6A7E]/10 rounded-full flex items-center justify-center">
        <Package className="w-5 h-5 text-[#2D6A7E]" />
      </div>
      <div>
        <p className="text-xs text-gray-500">Label</p>
        <p className="font-bold text-sm">Value</p>
      </div>
    </div>
  </CardContent>
</Card>
```

### Active Tab/Button

```css
/* Selected state */
className={`px-4 py-2.5 rounded-lg transition-all ${
  isActive
    ? 'bg-[#2D6A7E] text-[#FFC107] shadow-md'
    : 'bg-gray-100 text-gray-700'
}`}
```

### Info/Warning Box

```css
/* Info box */
<div className="p-3 bg-blue-50 border border-blue-200 rounded-lg">
  <p className="text-sm text-blue-800">

/* Warning box */
<div className="bg-amber-50 border border-amber-200 rounded-lg p-3">
  <p className="text-sm text-amber-900">
```

---

## Accessibility

### Focus States

All interactive elements include focus-visible states:
```css
focus-visible:border-ring
focus-visible:ring-ring/50
focus-visible:ring-[3px]
```

### Aria States

Invalid states are styled automatically:
```css
aria-invalid:ring-destructive/20
aria-invalid:border-destructive
```

### Disabled States

```css
disabled:pointer-events-none
disabled:cursor-not-allowed
disabled:opacity-50
```

---

## Dark Mode Support

The theme includes dark mode variables in `theme.css`:

```css
.dark {
  --background: oklch(0.145 0 0);
  --foreground: oklch(0.985 0 0);
  /* ... additional dark mode colors ... */
}
```

**Note:** Dark mode is available but not actively used in current FMB implementation, which uses the FMB brand colors (#2D6A7E, #FFC107) consistently.

---

## Usage Guidelines

### Do's
✅ Use FMB brand colors (`#2D6A7E`, `#FFC107`) for primary UI elements  
✅ Apply consistent shadows (`shadow-md`, `shadow-lg`) to cards  
✅ Use semantic colors for status (green=success, amber=warning, red=error)  
✅ Maintain consistent spacing (`gap-3`, `gap-4`, `space-y-4`)  
✅ Include focus states on all interactive elements  
✅ Use gradient backgrounds for hero/welcome sections  

### Don'ts
❌ Don't mix FMB brand colors with default system primary colors inconsistently  
❌ Don't use custom shadow values; stick to Tailwind utilities  
❌ Don't create arbitrary color values; use defined variables  
❌ Don't override focus styles without proper accessibility consideration  
❌ Don't use fixed pixel values; prefer Tailwind spacing scale  

---

## File References

- **Theme Configuration:** `/src/styles/theme.css`
- **Button Component:** `/src/app/components/ui/button.tsx`
- **Card Component:** `/src/app/components/ui/card.tsx`
- **Input Component:** `/src/app/components/ui/input.tsx`
- **Badge Component:** `/src/app/components/ui/badge.tsx`

---

**Last Updated:** April 20, 2026  
**Version:** 1.0
