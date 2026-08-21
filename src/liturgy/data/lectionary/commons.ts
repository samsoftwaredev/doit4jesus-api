import type { LectionaryEntry, LiturgicalCommon } from '@/liturgy/models';

/**
 * Common readings are independent options, not an implicit replacement for a
 * weekday. The list is deliberately small until each Common is curated from
 * the licensed lectionary source.
 */
export const commonReadings: Partial<Record<LiturgicalCommon, LectionaryEntry[]>> = {
  DOCTORS: [
    {
      selectionRule: 'COMMON',
      readingSets: [
        {
          id: 'common-doctors-default',
          label: 'DEFAULT',
          selectionRule: 'COMMON',
          readings: [
            { type: 'FIRST_READING', citation: 'Sir 15:1-6' },
            { type: 'RESPONSORIAL_PSALM', citation: 'Ps 119:9, 10, 11, 12, 13, 14' },
            { type: 'GOSPEL', citation: 'Mt 23:8-12' },
          ],
        },
      ],
    },
  ],
};
