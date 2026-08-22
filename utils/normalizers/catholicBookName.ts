import CATHOLIC_BIBLE_BOOKS_LIST from '@/data/bible/bible-all-books.json';

export type CatholicBookNormalizationResult = {
  input: string;
  normalizedInput: string;
  bookId: number;
  canonicalBookName: string;
};

const catholicBibleBooks = CATHOLIC_BIBLE_BOOKS_LIST.map((book, index) => ({
  id: index + 1,
  book: book,
}));

const BOOK_ID_TO_NAME = new Map<number, string>(
  catholicBibleBooks.map((b) => [b.id, b.book]),
);

const EXPLICIT_ALIASES: Record<string, number> = {
  genesis: 1,
  exodus: 2,
  leviticus: 3,
  numbers: 4,
  deuteronomy: 5,
  joshua: 6,
  josue: 6,
  judges: 7,
  ruth: 8,
  '1 samuel': 9,
  '2 samuel': 10,
  '1 kings': 11,
  '2 kings': 12,
  '1 chronicles': 13,
  '2 chronicles': 14,
  ezra: 15,
  nehemiah: 16,
  tobit: 17,
  tobias: 17,
  judith: 18,
  esther: 19,
  job: 20,
  psalm: 21,
  psalms: 21,
  proverbs: 22,
  ecclesiastes: 23,
  'song of songs': 24,
  'song of solomon': 24,
  wisdom: 25,
  sirach: 26,
  ecclesiasticus: 26,
  isaiah: 27,
  isaias: 27,
  jeremiah: 28,
  jeremias: 28,
  lamentations: 29,
  baruch: 30,
  ezekiel: 31,
  ezechiel: 31,
  daniel: 32,
  hosea: 33,
  osee: 33,
  joel: 34,
  amos: 35,
  obadiah: 36,
  abdias: 36,
  jonah: 37,
  jonas: 37,
  micah: 38,
  micheas: 38,
  nahum: 39,
  habakkuk: 40,
  habacuc: 40,
  zephaniah: 41,
  sophonias: 41,
  haggai: 42,
  aggeus: 42,
  zechariah: 43,
  zacharias: 43,
  malachi: 44,
  malachias: 44,
  '1 maccabees': 45,
  '2 maccabees': 46,
  '1 machabees': 45,
  '2 machabees': 46,
  matthew: 47,
  mark: 48,
  luke: 49,
  john: 50,
  acts: 51,
  romans: 52,
  '1 corinthians': 53,
  '2 corinthians': 54,
  galatians: 55,
  ephesians: 56,
  philippians: 57,
  colossians: 58,
  '1 thessalonians': 59,
  '2 thessalonians': 60,
  '1 timothy': 61,
  '2 timothy': 62,
  titus: 63,
  philemon: 64,
  hebrews: 65,
  james: 66,
  '1 peter': 67,
  '2 peter': 68,
  '1 john': 69,
  '2 john': 70,
  '3 john': 71,
  jude: 72,
  revelation: 73,
  apocalypse: 73,
};

const toLookupKey = (value: string): string =>
  value
    .toLowerCase()
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[.,'’]/g, ' ')
    .replace(/\bfirst\b/g, '1')
    .replace(/\bsecond\b/g, '2')
    .replace(/\bthird\b/g, '3')
    .replace(/\bfourth\b/g, '4')
    .replace(/\b1st\b/g, '1')
    .replace(/\b2nd\b/g, '2')
    .replace(/\b3rd\b/g, '3')
    .replace(/\b4th\b/g, '4')
    .replace(/\bi\b/g, '1')
    .replace(/\bii\b/g, '2')
    .replace(/\biii\b/g, '3')
    .replace(/\biv\b/g, '4')
    .replace(/\s+/g, ' ')
    .trim();

const ALIAS_TO_BOOK_ID = new Map<string, number>();

const addAlias = (alias: string, bookId: number) => {
  const key = toLookupKey(alias);
  if (!key) return;
  ALIAS_TO_BOOK_ID.set(key, bookId);
};

for (const [alias, id] of Object.entries(EXPLICIT_ALIASES)) {
  addAlias(alias, id);
}

for (const book of catholicBibleBooks) {
  addAlias(book.book, book.id);

  const parentheticalRegex = /\(([^)]+)\)/g;
  let parentheticalMatch: RegExpExecArray | null;
  while ((parentheticalMatch = parentheticalRegex.exec(book.book)) !== null) {
    addAlias(parentheticalMatch[1].trim(), book.id);
  }

  const withoutParentheses = book.book.replace(/\([^)]*\)/g, '').trim();
  addAlias(withoutParentheses, book.id);
}

export const normalizeCatholicBookName = (
  input: string,
): CatholicBookNormalizationResult | null => {
  const normalizedInput = toLookupKey(input);
  if (!normalizedInput) return null;

  const bookId = ALIAS_TO_BOOK_ID.get(normalizedInput);
  if (!bookId) return null;

  const canonicalBookName = BOOK_ID_TO_NAME.get(bookId);
  if (!canonicalBookName) return null;

  return {
    input,
    normalizedInput,
    bookId,
    canonicalBookName,
  };
};
