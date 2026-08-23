import bibleBooks from '@/data/bible/bible-nabre-book-chapters.json';
import type { CanonicalReference } from '@/liturgy/models';

type BibleBook = { Book: string; Chapters: number };

const canonicalBookNames = new Map(
  (bibleBooks as BibleBook[]).map((book) => [
    book.Book.toLowerCase().replace(/[^a-z0-9]/g, ''),
    book.Book,
  ]),
);

const aliases: Record<string, string> = {
  am: 'Amos',
  acts: 'Acts',
  bar: 'Baruch',
  chr: '1Chronicles',
  col: 'Colossians',
  cor: '1Corinthians',
  dan: 'Daniel',
  dn: 'Daniel',
  dt: 'Deuteronomy',
  eccl: 'Ecclesiastes',
  eph: 'Ephesians',
  est: 'Esther',
  ex: 'Exodus',
  ez: 'Ezekiel',
  ezekiel: 'Ezekiel',
  gal: 'Galatians',
  gn: 'Genesis',
  gen: 'Genesis',
  heb: 'Hebrews',
  hb: 'Hebrews',
  hos: 'Hosea',
  is: 'Isaiah',
  jas: 'James',
  jer: 'Jeremiah',
  jgs: 'Judges',
  jn: 'John',
  jl: 'Joel',
  job: 'Job',
  jon: 'Jonah',
  jos: 'Joshua',
  kgs: '1Kings',
  lam: 'Lamentations',
  lk: 'Luke',
  lv: 'Leviticus',
  mal: 'Malachi',
  mc: '1Maccabees',
  mk: 'Mark',
  mt: 'Matthew',
  matthew: 'Matthew',
  nm: 'Numbers',
  ob: 'Obadiah',
  phil: 'Philippians',
  phlm: 'Philemon',
  pt: '1Peter',
  prv: 'Proverbs',
  ps: 'Psalms',
  psalm: 'Psalms',
  psalms: 'Psalms',
  rom: 'Romans',
  ru: 'Ruth',
  rv: 'Revelation',
  sg: 'SongofSongs',
  sir: 'Sirach',
  sm: '1Samuel',
  tb: 'Tobit',
  thes: '1Thessalonians',
  tm: '1Timothy',
  ti: 'Titus',
  wis: 'Wisdom',
  zec: 'Zechariah',
  zep: 'Zephaniah',
};

function normalize(value: string) {
  return value.toLowerCase().replace(/[^a-z0-9]/g, '');
}

export function canonicalBookForCitation(citation: string) {
  const match = citation
    .trim()
    .match(/^((?:[1-3]\s*)?[A-Za-z]+(?:\s+[A-Za-z]+)*)\s+(?=\d)/);
  if (!match) return null;

  const shortName = normalize(match[1]);
  const directName = canonicalBookNames.get(shortName);
  if (directName) return directName;

  const numbered = shortName.match(/^([1-3])(.*)$/);
  const number = numbered?.[1] ?? '';
  const aliasName = numbered?.[2] ?? shortName;
  const base = aliases[aliasName];
  if (!base) return null;

  if (
    number &&
    [
      'Corinthians',
      'Samuel',
      'Thessalonians',
      'Timothy',
      'Peter',
      'John',
      'Kings',
      'Chronicles',
      'Maccabees',
    ].some((name) => base.endsWith(name))
  ) {
    return `${number}${base.replace(/^1/, '')}`;
  }
  return base;
}

/**
 * Local NABRE catalogue used to validate lectionary references. It deliberately
 * reads only the tiny book/chapter index; verse text stays in `src/data/bible`
 * until a future text endpoint uses a licensed provider.
 */
export class NabreScriptureRepository {
  private readonly books = new Map(
    (bibleBooks as BibleBook[]).map((book) => [book.Book, book.Chapters]),
  );

  hasBook(book: string) {
    return this.books.has(book);
  }

  supportsCitation(citation: string) {
    const book = canonicalBookForCitation(citation);
    return book !== null && this.hasBook(book);
  }

  supportsCanonicalReference(reference: CanonicalReference) {
    const chapters = this.books.get(reference.book);
    if (!chapters) return false;
    const end = reference.chapterEnd ?? reference.chapterStart;
    return (
      reference.chapterStart >= 1 &&
      end >= reference.chapterStart &&
      end <= chapters
    );
  }
}
