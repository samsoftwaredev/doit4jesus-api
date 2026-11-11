'use client';

import Box from '@mui/material/Box';
import Button from '@mui/material/Button';
import Chip from '@mui/material/Chip';
import Divider from '@mui/material/Divider';
import Menu from '@mui/material/Menu';
import MenuItem from '@mui/material/MenuItem';
import Stack from '@mui/material/Stack';
import TextField from '@mui/material/TextField';
import ToggleButton from '@mui/material/ToggleButton';
import ToggleButtonGroup from '@mui/material/ToggleButtonGroup';
import Typography from '@mui/material/Typography';
import { useMemo, useState } from 'react';

import {
  type ScheduleEntry,
  type ScheduleServiceType,
  type ScheduleWeekday,
  addScheduleEntries,
  clearService,
  copyWeekday,
  formatEntryTime,
  groupByWeekday,
  parseTimeList,
  removeScheduleEntry,
  scheduleWeekdays,
  weekdayPresets,
} from '@/lib/churches/schedule-entry';

type SectionConfig = {
  serviceType: ScheduleServiceType;
  title: string;
  /** Lowercase wording for sentences, keeping proper nouns capitalised. */
  noun: string;
  required: boolean;
  defaultWeekdays: ScheduleWeekday[];
  placeholder: string;
};

const sections: SectionConfig[] = [
  {
    serviceType: 'mass',
    title: 'Mass',
    noun: 'Mass',
    required: true,
    defaultWeekdays: ['sunday'],
    placeholder: 'e.g. 7, 9, 11:30am, 5pm',
  },
  {
    serviceType: 'confession',
    title: 'Confession',
    noun: 'confession',
    required: false,
    defaultWeekdays: ['saturday'],
    placeholder: 'e.g. 3:30-4:30 or 4-4:45pm',
  },
  {
    serviceType: 'adoration',
    title: 'Eucharistic adoration',
    noun: 'Eucharistic adoration',
    required: false,
    defaultWeekdays: ['friday'],
    placeholder: 'e.g. 9am-5pm or 6pm',
  },
];

const dayLabel = (weekday: ScheduleWeekday) =>
  weekday.charAt(0).toUpperCase() + weekday.slice(1);

function ServiceSection({
  config,
  entries,
  onChange,
  disabled,
}: {
  config: SectionConfig;
  entries: ScheduleEntry[];
  onChange: (entries: ScheduleEntry[]) => void;
  disabled: boolean;
}) {
  const { serviceType, title, noun, required } = config;
  const [weekdays, setWeekdays] = useState<ScheduleWeekday[]>(
    config.defaultWeekdays,
  );
  const [text, setText] = useState('');
  const [copySource, setCopySource] = useState<{
    anchor: HTMLElement;
    weekday: ScheduleWeekday;
  } | null>(null);

  const parsed = useMemo(() => parseTimeList(text), [text]);
  const groups = groupByWeekday(entries, serviceType);
  const count = groups.reduce(
    (total, group) => total + group.entries.length,
    0,
  );
  const canAdd =
    !disabled &&
    weekdays.length > 0 &&
    parsed.times.length > 0 &&
    parsed.invalid.length === 0;

  function add() {
    if (!canAdd) return;
    onChange(
      addScheduleEntries(entries, {
        serviceType,
        weekdays,
        times: parsed.times,
      }),
    );
    setText('');
  }

  function copyTo(targets: ScheduleWeekday[]) {
    if (copySource)
      onChange(copyWeekday(entries, serviceType, copySource.weekday, targets));
    setCopySource(null);
  }

  return (
    <Box
      component="section"
      aria-label={`${title} times`}
      sx={{
        border: 1,
        borderColor: 'divider',
        borderRadius: 1,
        p: 2,
      }}
    >
      <Stack direction="row" alignItems="center" spacing={1} mb={1.5}>
        <Typography variant="subtitle1" fontWeight={700}>
          {title}
        </Typography>
        <Chip
          size="small"
          color={required ? 'primary' : 'default'}
          variant={required ? 'filled' : 'outlined'}
          label={required ? 'Required' : 'Optional'}
        />
        <Typography variant="caption" color="text.secondary">
          {count} time{count === 1 ? '' : 's'}
        </Typography>
        <Box flexGrow={1} />
        {count > 0 && !disabled && (
          <Button
            size="small"
            color="inherit"
            onClick={() => onChange(clearService(entries, serviceType))}
          >
            Clear all
          </Button>
        )}
      </Stack>

      {!disabled && (
        <Stack spacing={1.5}>
          <Stack
            direction="row"
            spacing={1}
            flexWrap="wrap"
            useFlexGap
            alignItems="center"
          >
            <ToggleButtonGroup
              size="small"
              aria-label={`${title} days`}
              value={weekdays}
              onChange={(_event, next: ScheduleWeekday[]) => setWeekdays(next)}
            >
              {scheduleWeekdays.map((weekday) => (
                <ToggleButton
                  key={weekday}
                  value={weekday}
                  aria-label={dayLabel(weekday)}
                  sx={{ px: 1.25 }}
                >
                  {dayLabel(weekday).slice(0, 3)}
                </ToggleButton>
              ))}
            </ToggleButtonGroup>
            {weekdayPresets.map((preset) => (
              <Button
                key={preset.label}
                size="small"
                onClick={() => setWeekdays(preset.weekdays)}
              >
                {preset.label}
              </Button>
            ))}
          </Stack>
          <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1}>
            <TextField
              fullWidth
              size="small"
              label={`${title} times`}
              placeholder={config.placeholder}
              value={text}
              onChange={(event) => setText(event.target.value)}
              onKeyDown={(event) => {
                if (event.key === 'Enter') {
                  event.preventDefault();
                  add();
                }
              }}
              error={parsed.invalid.length > 0}
              helperText={
                parsed.invalid.length > 0
                  ? `Couldn't read: ${parsed.invalid.join(', ')}`
                  : 'Separate times with commas or spaces. Use a range like 4-4:45pm for an end time.'
              }
            />
            <Button
              variant="contained"
              disabled={!canAdd}
              onClick={add}
              sx={{ alignSelf: { sm: 'flex-start' }, minWidth: 96 }}
            >
              Add
            </Button>
          </Stack>
          {parsed.times.length > 0 && parsed.invalid.length === 0 && (
            <Stack
              direction="row"
              spacing={0.5}
              flexWrap="wrap"
              useFlexGap
              alignItems="center"
              aria-label="Times to add"
            >
              <Typography variant="caption" color="text.secondary">
                Will add
                {weekdays.length > 0
                  ? ` on ${weekdays.map((weekday) => dayLabel(weekday).slice(0, 3)).join(', ')}`
                  : ''}
                :
              </Typography>
              {parsed.times.map((time) => (
                <Chip
                  key={time.startTime}
                  size="small"
                  variant="outlined"
                  label={formatEntryTime(time)}
                />
              ))}
              {weekdays.length === 0 && (
                <Typography variant="caption" color="warning.main">
                  Pick at least one day.
                </Typography>
              )}
            </Stack>
          )}
        </Stack>
      )}

      {groups.length > 0 && <Divider sx={{ my: 1.5 }} />}
      <Stack spacing={1}>
        {groups.map((group) => (
          <Stack
            key={group.weekday}
            direction="row"
            spacing={1}
            alignItems="center"
            flexWrap="wrap"
            useFlexGap
          >
            <Typography variant="body2" fontWeight={600} sx={{ width: 96 }}>
              {dayLabel(group.weekday)}
            </Typography>
            {group.entries.map((entry) => (
              <Chip
                key={entry.startTime}
                label={formatEntryTime(entry)}
                onDelete={
                  disabled
                    ? undefined
                    : () => onChange(removeScheduleEntry(entries, entry))
                }
                size="small"
              />
            ))}
            {!disabled && (
              <Button
                size="small"
                onClick={(event) =>
                  setCopySource({
                    anchor: event.currentTarget,
                    weekday: group.weekday,
                  })
                }
              >
                Copy to…
              </Button>
            )}
          </Stack>
        ))}
        {groups.length === 0 && (
          <Typography
            variant="body2"
            color={required ? 'warning.main' : 'text.secondary'}
          >
            {required
              ? 'Add at least one Mass time.'
              : `No ${noun} times. Leave empty if this church doesn’t offer it.`}
          </Typography>
        )}
      </Stack>

      <Menu
        open={copySource !== null}
        anchorEl={copySource?.anchor}
        onClose={() => setCopySource(null)}
      >
        {weekdayPresets
          .filter((preset) => preset.label !== 'Sunday')
          .map((preset) => (
            <MenuItem
              key={preset.label}
              onClick={() => copyTo(preset.weekdays)}
            >
              {preset.label}
            </MenuItem>
          ))}
        <Divider />
        {scheduleWeekdays
          .filter((weekday) => weekday !== copySource?.weekday)
          .map((weekday) => (
            <MenuItem key={weekday} onClick={() => copyTo([weekday])}>
              {dayLabel(weekday)}
            </MenuItem>
          ))}
      </Menu>
    </Box>
  );
}

/**
 * Bulk-friendly editor for a church's recurring schedule: pick days, type many
 * times at once, and see everything grouped by day. Mass is required;
 * confession and adoration are optional.
 */
export default function ServiceScheduleEditor({
  value,
  onChange,
  disabled = false,
}: {
  value: ScheduleEntry[];
  onChange: (entries: ScheduleEntry[]) => void;
  disabled?: boolean;
}) {
  return (
    <Stack spacing={2}>
      {sections.map((config) => (
        <ServiceSection
          key={config.serviceType}
          config={config}
          entries={value}
          onChange={onChange}
          disabled={disabled}
        />
      ))}
    </Stack>
  );
}
