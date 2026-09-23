# Username moderation data

The username validator combines the two checked-in datasets with the English
and Spanish lists from the List of Dirty, Naughty, Obscene, and Otherwise Bad
Words project. Runtime requests do not call an external service.

## Sources and attribution

- `src/data/profanity_en.csv` — SHA-256
  `45214f1e4522a1c36cee7efa94440fce4188871db105abeb93d9dfe8c66feb6a`
- `src/data/profanity_es.csv` — SHA-256
  `26a111a805ff6d1a3ce47fdba37f7148cb0cb324ef8e5a554abc898df86613fd`
- [List of Dirty, Naughty, Obscene, and Otherwise Bad Words](https://github.com/LDNOOBW/List-of-Dirty-Naughty-Obscene-and-Otherwise-Bad-Words),
  English and Spanish files at commit
  `5faf2ba42d7b1c0977169ec3611df25a3c08eb13`, licensed under
  [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).

The generated `src/data/username-prohibited-terms.json` records these source
identifiers and checksums. Rebuild it with:

```bash
npm run build:username-profanity
```

## Matching policy

Usernames are normalized for case, accents, separators, and common leetspeak.
All source entries are checked as exact usernames or underscore-delimited
tokens. A small curated set of high-confidence roots is also checked inside a
concatenated username. This avoids broad substring false positives such as
rejecting an innocent name merely because it contains a short ambiguous
fragment.

Profanity lists are subjective and vary by culture and context. Changes should
therefore be reviewed for both false negatives and false positives. API
responses expose only `PROHIBITED_TERM`, never the matched source entry.
