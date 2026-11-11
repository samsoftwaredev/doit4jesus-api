import { weekdayCodes } from '@/lib/schemas/church';

type ChurchFields = {
  dioceseId?: string | null;
  name?: string;
  addressLine1?: string;
  addressLine2?: string | null;
  city?: string;
  regionName?: string | null;
  postalCode?: string | null;
  countryCode?: string;
  timezone?: string;
  latitude?: number;
  longitude?: number;
};

type ServiceTimeFields = {
  serviceType: string;
  weekday: (typeof weekdayCodes)[number];
  startTime: string;
  endTime?: string | null;
};

/** Maps API church fields to the snake_case JSON the admin church RPCs read. */
export function churchToRpcPayload(church: ChurchFields) {
  return {
    diocese_id: church.dioceseId,
    name: church.name,
    address_line_1: church.addressLine1,
    address_line_2: church.addressLine2,
    city: church.city,
    region_name: church.regionName,
    postal_code: church.postalCode,
    country_code: church.countryCode,
    timezone: church.timezone,
    latitude: church.latitude,
    longitude: church.longitude,
  };
}

/** Maps API service times to the RPC shape (weekday as 0-6, Sunday first). */
export function serviceTimesToRpcPayload(serviceTimes: ServiceTimeFields[]) {
  return serviceTimes.map((serviceTime) => ({
    service_type: serviceTime.serviceType,
    weekday: weekdayCodes.indexOf(serviceTime.weekday),
    starts_at: serviceTime.startTime,
    ends_at: serviceTime.endTime ?? null,
  }));
}
