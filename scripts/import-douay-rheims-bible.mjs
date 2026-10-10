#!/usr/bin/env node
import { createHash } from 'node:crypto';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { basename, resolve } from 'node:path';

const OUTPUT_DIRECTORY = resolve('src/data/bible');
const EXPECTED_SHA256 =
  '41cc44f2668a6e7c03898fd857775e9f914f2619929a3080bf224a3e7dd3374b';

// The Douay-Rheims source uses traditional Vulgate book names. Keep the
// app's canonical identifiers so lectionary citations and lazy imports stay
// stable while the displayed English book names remain familiar to clients.
const books = [
  ['Genesis', 'Genesis'],
  ['Exodus', 'Exodus'],
  ['Leviticus', 'Leviticus'],
  ['Numbers', 'Numbers'],
  ['Deuteronomy', 'Deuteronomy'],
  ['Josue', 'Joshua'],
  ['Judges', 'Judges'],
  ['Ruth', 'Ruth'],
  ['1 Kings', '1Samuel'],
  ['2 Kings', '2Samuel'],
  ['3 Kings', '1Kings'],
  ['4 Kings', '2Kings'],
  ['1 Paralipomenon', '1Chronicles'],
  ['2 Paralipomenon', '2Chronicles'],
  ['1 Esdras', 'Ezra'],
  ['2 Esdras', 'Nehemiah'],
  ['Tobias', 'Tobit'],
  ['Judith', 'Judith'],
  ['Esther', 'Esther'],
  ['1 Machabees', '1Maccabees'],
  ['2 Machabees', '2Maccabees'],
  ['Job', 'Job'],
  ['Psalms', 'Psalms'],
  ['Proverbs', 'Proverbs'],
  ['Ecclesiastes', 'Ecclesiastes'],
  ['Canticles', 'SongofSongs'],
  ['Wisdom', 'Wisdom'],
  ['Ecclesiasticus', 'Sirach'],
  ['Isaias', 'Isaiah'],
  ['Jeremias', 'Jeremiah'],
  ['Lamentations', 'Lamentations'],
  ['Baruch', 'Baruch'],
  ['Ezechiel', 'Ezekiel'],
  ['Daniel', 'Daniel'],
  ['Osee', 'Hosea'],
  ['Joel', 'Joel'],
  ['Amos', 'Amos'],
  ['Abdias', 'Obadiah'],
  ['Jonas', 'Jonah'],
  ['Micheas', 'Micah'],
  ['Nahum', 'Nahum'],
  ['Habacuc', 'Habakkuk'],
  ['Sophonias', 'Zephaniah'],
  ['Aggeus', 'Haggai'],
  ['Zacharias', 'Zechariah'],
  ['Malachias', 'Malachi'],
  ['Matthew', 'Matthew'],
  ['Mark', 'Mark'],
  ['Luke', 'Luke'],
  ['John', 'John'],
  ['Acts', 'Acts'],
  ['Romans', 'Romans'],
  ['1 Corinthians', '1Corinthians'],
  ['2 Corinthians', '2Corinthians'],
  ['Galatians', 'Galatians'],
  ['Ephesians', 'Ephesians'],
  ['Philippians', 'Philippians'],
  ['Colossians', 'Colossians'],
  ['1 Thessalonians', '1Thessalonians'],
  ['2 Thessalonians', '2Thessalonians'],
  ['1 Timothy', '1Timothy'],
  ['2 Timothy', '2Timothy'],
  ['Titus', 'Titus'],
  ['Philemon', 'Philemon'],
  ['Hebrews', 'Hebrews'],
  ['James', 'James'],
  ['1 Peter', '1Peter'],
  ['2 Peter', '2Peter'],
  ['1 John', '1John'],
  ['2 John', '2John'],
  ['3 John', '3John'],
  ['Jude', 'Jude'],
  ['Apocalypse', 'Revelation'],
];

function argument(name) {
  return process.argv
    .find((value) => value.startsWith(`--${name}=`))
    ?.slice(name.length + 3);
}

function json(value) {
  return `${JSON.stringify(value, null, 2)}\n`;
}

function convertBook(sourceBook, canonicalName) {
  if (!sourceBook || typeof sourceBook !== 'object') {
    throw new Error(`Missing chapters for ${canonicalName}.`);
  }

  return {
    book: canonicalName,
    chapters: Object.entries(sourceBook).map(([chapter, verses]) => ({
      chapter: Number.parseInt(chapter, 10),
      verses: Object.entries(verses).map(([verse, text]) => ({
        verse: Number.parseInt(verse, 10),
        text,
      })),
    })),
  };
}

async function main() {
  const inputArgument = argument('input');
  if (!inputArgument) {
    throw new Error(
      'Pass the Douay-Rheims EntireBible-DR.json path as --input=/absolute/or/relative/path.',
    );
  }

  const inputPath = resolve(inputArgument);
  const input = await readFile(inputPath);
  const checksum = createHash('sha256').update(input).digest('hex');
  if (checksum !== EXPECTED_SHA256) {
    throw new Error(
      `${basename(inputPath)} does not match the pinned Douay-Rheims snapshot. ` +
        `Expected ${EXPECTED_SHA256}, received ${checksum}.`,
    );
  }

  const source = JSON.parse(input.toString('utf8'));
  const converted = books.map(([sourceName, canonicalName]) => {
    const sourceBook = source[sourceName];
    if (!sourceBook) throw new Error(`Missing source book ${sourceName}.`);
    return { canonicalName, value: convertBook(sourceBook, canonicalName) };
  });

  if (
    Object.keys(source).length !== books.length ||
    converted.length !== books.length
  ) {
    throw new Error('The source must contain exactly the expected 73 books.');
  }

  await mkdir(resolve(OUTPUT_DIRECTORY, 'books'), { recursive: true });
  await Promise.all(
    converted.map(({ canonicalName, value }) =>
      writeFile(
        resolve(OUTPUT_DIRECTORY, 'books', `${canonicalName}.json`),
        json(value),
      ),
    ),
  );

  await Promise.all([
    writeFile(
      resolve(OUTPUT_DIRECTORY, 'bible-all-books.json'),
      json(converted.map(({ value }) => value.book)),
    ),
    writeFile(
      resolve(OUTPUT_DIRECTORY, 'bible-douay-rheims-book-chapters.json'),
      json(
        converted.map(({ value }) => ({
          Book: value.book,
          Chapters: value.chapters.length,
        })),
      ),
    ),
    writeFile(
      resolve(OUTPUT_DIRECTORY, 'douay-rheims.json'),
      json(converted.map(({ value }) => value)),
    ),
  ]);

  console.log(`Imported ${converted.length} Douay-Rheims Bible books.`);
}

await main();
