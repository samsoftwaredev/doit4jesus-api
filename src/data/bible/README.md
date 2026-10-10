# English Bible data

This directory contains a normalized copy of the public-domain **Douay-Rheims
Bible**, imported from
[`xxruyle/Bible-DouayRheims`](https://github.com/xxruyle/Bible-DouayRheims) at
commit `24516e019db3f33e344277ca6080c0065c09f391`.

The upstream JSON repository is MIT-licensed (copyright © 2022 Theodicy1);
its required license notice is preserved in
[`DOUAY-RHEIMS-LICENSE`](./DOUAY-RHEIMS-LICENSE).
The importer preserves the verse text and normalizes traditional Vulgate book
names to the application's canonical book identifiers. It is intentionally
pinned to the upstream `EntireBible-DR.json` SHA-256 checksum.

The USCCB lectionary uses modern chapter and verse conventions. When a cited
passage is unavailable in this translation's source data or versification, the
API returns its citation without text and sets
`metadata.scriptureTextUnavailable` to `true`; it never substitutes a nearby
passage.

Regenerate the checked-in files from the pinned upstream input with:

```sh
npm run import:douay-rheims-bible -- --input=/path/to/EntireBible-DR.json
```
