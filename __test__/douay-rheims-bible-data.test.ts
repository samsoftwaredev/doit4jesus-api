import { readFileSync, readdirSync } from 'node:fs';
import { resolve } from 'node:path';

type BibleVerse = { verse: number; text: string };
type BibleChapter = { chapter: number; verses: BibleVerse[] };
type BibleBook = { book: string; chapters: BibleChapter[] };

const dataDirectory = resolve('src/data/bible');

function readJson<T>(path: string): T {
  return JSON.parse(readFileSync(path, 'utf8')) as T;
}

describe('Douay-Rheims Bible data', () => {
  const bookNames = readJson<string[]>(
    resolve(dataDirectory, 'bible-all-books.json'),
  );
  const chapterIndex = readJson<Array<{ Book: string; Chapters: number }>>(
    resolve(dataDirectory, 'bible-douay-rheims-book-chapters.json'),
  );
  const bible = readJson<BibleBook[]>(
    resolve(dataDirectory, 'douay-rheims.json'),
  );

  it('contains the complete 73-book Catholic canon in every representation', () => {
    const splitFiles = readdirSync(resolve(dataDirectory, 'books')).filter(
      (file) => file.endsWith('.json'),
    );

    expect(bookNames).toHaveLength(73);
    expect(chapterIndex).toHaveLength(73);
    expect(bible).toHaveLength(73);
    expect(splitFiles).toHaveLength(73);
    expect(bookNames).toEqual(bible.map((book) => book.book));
    expect(chapterIndex).toEqual(
      bible.map((book) => ({
        Book: book.book,
        Chapters: book.chapters.length,
      })),
    );
  });

  it('keeps every split book synchronized with the monolithic Bible', () => {
    const canonicalFiles = readdirSync(resolve(dataDirectory, 'books')).sort();
    const splitBooks = canonicalFiles.map((file) =>
      readJson<BibleBook>(resolve(dataDirectory, 'books', file)),
    );
    const splitByName = new Map(splitBooks.map((book) => [book.book, book]));

    for (const book of bible) {
      expect(splitByName.get(book.book)).toEqual(book);
    }
  });

  it('contains ordered, unique, nonempty chapters and verses', () => {
    for (const book of bible) {
      const chapterNumbers = book.chapters.map((chapter) => chapter.chapter);
      expect(new Set(chapterNumbers).size).toBe(chapterNumbers.length);
      expect(chapterNumbers).toEqual([...chapterNumbers].sort((a, b) => a - b));
      expect(chapterNumbers).toEqual(
        chapterNumbers.map((_, index) => index + 1),
      );
      for (const chapter of book.chapters) {
        const verseNumbers = chapter.verses.map((verse) => verse.verse);
        expect(new Set(verseNumbers).size).toBe(verseNumbers.length);
        expect(verseNumbers).toEqual([...verseNumbers].sort((a, b) => a - b));
        for (const verse of chapter.verses) {
          expect(verse.text.trim()).not.toHaveLength(0);
        }
      }
    }
  });
});
