import bibleBooks from '@/data/bible/bible-nabre-book-chapters.json';
import type { CanonicalReference } from '@/liturgy/models';

type BibleBook = { Book: string; Chapters: number };

const aliases: Record<string, string> = {
  acts: 'Acts',
  bar: 'Baruch',
  col: 'Colossians',
  cor: '1Corinthians',
  dan: 'Daniel',
  dn: 'Daniel',
  dt: 'Deuteronomy',
  eph: 'Ephesians',
  ex: 'Exodus',
  ez: 'Ezekiel',
  gal: 'Galatians',
  gn: 'Genesis',
  gen: 'Genesis',
  heb: 'Hebrews',
  is: 'Isaiah',
  jer: 'Jeremiah',
  jgs: 'Judges',
  jn: 'John',
  jl: 'Joel',
  lk: 'Luke',
  mk: 'Mark',
  mt: 'Matthew',
  nm: 'Numbers',
  phil: 'Philippians',
  pt: '1Peter',
  ps: 'Psalms',
  rom: 'Romans',
  rv: 'Revelation',
  sir: 'Sirach',
  sm: '1Samuel',
  thes: '1Thessalonians',
  tm: '1Timothy',
  ti: 'Titus',
};

function normalize(value: string) {
  return value.toLowerCase().replace(/[^a-z0-9]/g, '');
}

export function canonicalBookForCitation(citation: string) {
  const match = citation.match(/^([1-3])?\s*([A-Za-z]+)/);
  if (!match) return null;

  const number = match[1] ?? '';
  const shortName = normalize(match[2]);
  const base = aliases[shortName];
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
