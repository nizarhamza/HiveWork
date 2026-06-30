# Phase 6 — Internationalization & RTL (EN / FR / AR)

> Goal: trilingual and right-to-left-correct.

## Setup
- [ ] Add `intl` + `flutter_localizations`
- [ ] ARB files for `en`, `fr`, `ar`
- [ ] Locale switcher + persistence

## RTL correctness
- [ ] Replace `EdgeInsets.only(left/right)` with `EdgeInsetsDirectional`
- [ ] Audit icons / arrows for directionality
- [ ] Test the full app in Arabic RTL

## Formatting
- [ ] Locale-aware dates
- [ ] Locale-aware numbers + currency

## Content
- [ ] Externalize all UI / nav / module strings
- [ ] Translate strings (en / fr / ar)

**Definition of done:** the app flips cleanly to Arabic RTL and to French, with correct date/number/currency formatting.
