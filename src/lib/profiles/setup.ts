export const REQUIRED_PROFILE_FIELDS = [
  'displayName',
  'gender',
  'country',
  'city',
] as const;

export type RequiredProfileField = (typeof REQUIRED_PROFILE_FIELDS)[number];
export type ProfileSetupStep = 'name' | 'gender' | 'country' | 'city';

type ProfileSetupValues = {
  displayName: string | null;
  gender: 'male' | 'female' | null;
  countryCode: string | null;
  cityId: string | null;
  countryExists?: boolean;
  cityCountryCode?: string | null;
  completedAt: string | null;
};

const stepByField: Record<RequiredProfileField, ProfileSetupStep> = {
  displayName: 'name',
  gender: 'gender',
  country: 'country',
  city: 'city',
};

export function getProfileSetup(values: ProfileSetupValues) {
  const missingFields: RequiredProfileField[] = [];

  if (!values.displayName?.trim()) missingFields.push('displayName');
  if (values.gender !== 'male' && values.gender !== 'female') {
    missingFields.push('gender');
  }
  if (!values.countryCode?.trim() || values.countryExists === false) {
    missingFields.push('country');
  }
  if (
    !values.cityId ||
    values.cityCountryCode === null ||
    (values.cityCountryCode !== undefined &&
      values.cityCountryCode !== values.countryCode)
  ) {
    missingFields.push('city');
  }

  return {
    complete: missingFields.length === 0,
    missingFields,
    nextStep: missingFields[0] ? stepByField[missingFields[0]] : null,
    completedAt: values.completedAt,
  };
}
