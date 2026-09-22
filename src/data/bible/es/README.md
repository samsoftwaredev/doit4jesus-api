# Spanish Bible data

This directory contains a normalized copy of the Spanish **Biblia de
Jerusalén** data from
[`yatiac/BibliAPI`](https://github.com/yatiac/BibliAPI/tree/master), pinned to
commit `027466a47d66c9c55be50e096e1fc862a68c1a9a`.

The upstream project generated `db/biblia.json` by scraping the Biblia
Católica website. The imported verse text is preserved verbatim; book names,
ordering, and the JSON container shape are normalized for this application.
The upstream repository does not include an explicit license file. Confirm
redistribution rights before distributing these generated files outside the
authorized application.

Regenerate the checked-in files from the pinned upstream input with:

```sh
pnpm import:spanish-bible -- --input=/path/to/BibliAPI/db/biblia.json
```

The importer verifies the source file's SHA-256 checksum before writing any
output.
