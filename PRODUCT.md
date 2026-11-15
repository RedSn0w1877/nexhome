# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Users
The owner (and anyone they show it to) running a simulated smart home from an iPhone: glancing at
the house, flipping lights and climate, checking cameras and the alarm.

## Product Purpose
NexHome is a smart-home controller: a Home overview, Rooms, Cameras and Security tabs, and a
full-screen control sheet for every device type. It was ported from an Android concept app.

## Capabilities and Constraints
- Native SwiftUI, iOS 27 only, iPhone, built unsigned in GitHub Actions (`xcode-27` runner).
- The layout must stay the same as the current build, layout for layout and button for button
  (confirmed by the owner, 2026-11-15). The rebuild replaces how it is drawn, not what is on screen.
- All of it stays: the 4 tabs (Home, Rooms, Cameras, Security), all 16 device control types,
  scenes, the wallpaper picker (gradient themes or a photo), the simulated live house.
- New: a Setup screen to add devices manually and customise the home.
- The house is simulated (seeded generator, ambient simulation loops); there is no real backend.

## Brand Commitments
- Name: NexHome. Dark appearance. A coloured wallpaper sits behind everything.
- Glass must be Apple's system Liquid Glass (`glassEffect`, glass button styles, native tab bar,
  toolbars and sheets), never hand-painted imitations of glass (owner, 2026-11-15).

## Evidence on Hand
No real customers, testimonials or metrics; all device data is simulated and must not be presented
as real.

## Product Principles
- Native first: where iOS has the control, use it; where it doesn't, build it from system glass.
- Same app, better material: every existing screen and control keeps its place and purpose.
- Content over chrome: glass is for controls and navigation floating over content.
