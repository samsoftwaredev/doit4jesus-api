import { normalizeCatholicBookName } from './catholicBookName';

describe('normalizeCatholicBookName', () => {
  it('normalizes modern names to local Bible dataset names', () => {
    const result = normalizeCatholicBookName('Isaiah');
    expect(result?.bookId).toBe(29);
    expect(result?.canonicalBookName).toBe('Isaiah');
  });

  it('normalizes books with numbering aliases', () => {
    const first = normalizeCatholicBookName('1 Samuel');
    expect(first?.bookId).toBe(9);
    expect(first?.canonicalBookName).toBe('1Samuel');

    const second = normalizeCatholicBookName('II Corinthians');
    expect(second?.bookId).toBe(54);
    expect(second?.canonicalBookName).toBe('2Corinthians');
  });

  it('normalizes canonical names and parenthetical aliases', () => {
    const canonical = normalizeCatholicBookName(
      'The Apocalypse of St John (Revelation)',
    );
    expect(canonical?.bookId).toBe(73);

    const parenthetical = normalizeCatholicBookName('Revelation');
    expect(parenthetical?.bookId).toBe(73);
    expect(parenthetical?.canonicalBookName).toBe('Revelation');
  });

  it('returns null for unknown books', () => {
    expect(normalizeCatholicBookName('Unknown Book')).toBeNull();
  });
});
