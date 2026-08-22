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

const EXPLICIT_ALIASES: Record<string, string> = {
  josue: 'Joshua',
  tobias: 'Tobit',
  psalm: 'Psalms',
  'song of songs': 'SongofSongs',
  'song of solomon': 'SongofSongs',
  ecclesiasticus: 'Sirach',
  isaias: 'Isaiah',
  jeremias: 'Jeremiah',
  ezechiel: 'Ezekiel',
  osee: 'Hosea',
  abdias: 'Obadiah',
  jonas: 'Jonah',
  micheas: 'Micah',
  habacuc: 'Habakkuk',
  sophonias: 'Zephaniah',
  aggeus: 'Haggai',
  zacharias: 'Zechariah',
  malachias: 'Malachi',
  apocalypse: 'Revelation',
  'the apocalypse of st john': 'Revelation',
  'the apocalypse of st john (revelation)': 'Revelation',
  '1 samuel': '1Samuel',
  '2 samuel': '2Samuel',
  '1 kings': '1Kings',
  '2 kings': '2Kings',
  '1 chronicles': '1Chronicles',
  '2 chronicles': '2Chronicles',
  '1 maccabees': '1Maccabees',
  '2 maccabees': '2Maccabees',
  '1 machabees': '1Maccabees',
  '2 machabees': '2Maccabees',
  '1 corinthians': '1Corinthians',
  '2 corinthians': '2Corinthians',
  '1 thessalonians': '1Thessalonians',
  '2 thessalonians': '2Thessalonians',
  '1 timothy': '1Timothy',
  '2 timothy': '2Timothy',
  '1 peter': '1Peter',
  '2 peter': '2Peter',
  '1 john': '1John',
  '2 john': '2John',
  '3 john': '3John',
  '1st book of kings (1 samuel)': '1Samuel',
  '2nd epistle of st paul to the corinthians': '2Corinthians',
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

const BOOK_NAME_TO_ID = new Map<string, number>(
  catholicBibleBooks.map((book) => [book.book, book.id]),
);

const addAlias = (alias: string, bookId: number) => {
  const key = toLookupKey(alias);
  if (!key) return;
  ALIAS_TO_BOOK_ID.set(key, bookId);
};

for (const [alias, bookName] of Object.entries(EXPLICIT_ALIASES)) {
  const bookId = BOOK_NAME_TO_ID.get(bookName);
  if (bookId) addAlias(alias, bookId);
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
