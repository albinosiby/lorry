const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type ServiceType = "fuel" | "truck_stop" | "weighbridge" | "workshop" | "tyre" | "hospital";

const supportedTypes: Record<Exclude<ServiceType, "weighbridge">, string> = {
  fuel: "gas_station",
  truck_stop: "truck_stop",
  workshop: "car_repair",
  tyre: "tire_shop",
  hospital: "hospital",
};

const fieldMask = [
  "places.id",
  "places.displayName",
  "places.formattedAddress",
  "places.location",
  "places.rating",
  "places.regularOpeningHours.openNow",
].join(",");

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function distanceKm(fromLat: number, fromLng: number, toLat: number, toLng: number) {
  const radians = (value: number) => value * Math.PI / 180;
  const dLat = radians(toLat - fromLat);
  const dLng = radians(toLng - fromLng);
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(radians(fromLat)) * Math.cos(radians(toLat)) * Math.sin(dLng / 2) ** 2;
  return 6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function toService(place: Record<string, unknown>, type: ServiceType, latitude: number, longitude: number) {
  const location = place.location as { latitude?: number; longitude?: number } | undefined;
  const pointLat = location?.latitude;
  const pointLng = location?.longitude;
  if (typeof pointLat !== "number" || typeof pointLng !== "number") return null;
  const displayName = place.displayName as { text?: string } | undefined;
  const opening = place.regularOpeningHours as { openNow?: boolean } | undefined;
  return {
    id: String(place.id ?? ""),
    place_id: String(place.id ?? ""),
    service_type: type,
    name: displayName?.text ?? "Nearby service",
    address: String(place.formattedAddress ?? ""),
    latitude: pointLat,
    longitude: pointLng,
    distance_km: Number(distanceKm(latitude, longitude, pointLat, pointLng).toFixed(2)),
    rating: typeof place.rating === "number" ? place.rating : null,
    is_open_now: typeof opening?.openNow === "boolean" ? opening.openNow : null,
  };
}

async function googleSearch({
  key,
  latitude,
  longitude,
  radiusKm,
  type,
  query,
}: {
  key: string;
  latitude: number;
  longitude: number;
  radiusKm: number;
  type: ServiceType;
  query?: string;
}) {
  const radiusMeters = radiusKm * 1000;
  const textSearch = type === "weighbridge" || Boolean(query);
  const url = textSearch
    ? "https://places.googleapis.com/v1/places:searchText"
    : "https://places.googleapis.com/v1/places:searchNearby";
  const body = textSearch
    ? {
        textQuery: query?.trim() || "weighbridge",
        locationBias: { circle: { center: { latitude, longitude }, radius: radiusMeters } },
        maxResultCount: 20,
      }
    : {
        includedTypes: [supportedTypes[type as Exclude<ServiceType, "weighbridge">]],
        locationRestriction: { circle: { center: { latitude, longitude }, radius: radiusMeters } },
        maxResultCount: 20,
      };
  const response = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Goog-Api-Key": key,
      "X-Goog-FieldMask": fieldMask,
    },
    body: JSON.stringify(body),
  });
  if (!response.ok) {
    const detail = await response.text();
    console.error("Google Places request failed", response.status, detail.slice(0, 300));
    throw new Error(response.status === 403 ? "Google Places access was denied." : "Nearby service search is temporarily unavailable.");
  }
  const payload = await response.json() as { places?: Record<string, unknown>[] };
  return (payload.places ?? [])
    .map((place) => toService(place, type, latitude, longitude))
    .filter((place): place is NonNullable<typeof place> => place !== null)
    .sort((left, right) => left.distance_km - right.distance_km);
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ error: "Method not allowed." }, 405);

  const providerKey = Deno.env.get("GOOGLE_PLACES_API_KEY");
  if (!providerKey) {
    return json({ error: "Nearby services is not configured. Add GOOGLE_PLACES_API_KEY to Edge Function secrets." }, 503);
  }

  try {
    const input = await request.json() as Record<string, unknown>;
    const latitude = Number(input.latitude);
    const longitude = Number(input.longitude);
    const radiusKm = Number(input.radius_km ?? 10);
    const type = (input.type || "fuel") as ServiceType;
    const query = typeof input.query === "string" ? input.query.slice(0, 100) : undefined;
    if (!Number.isFinite(latitude) || latitude < -90 || latitude > 90 || !Number.isFinite(longitude) || longitude < -180 || longitude > 180) {
      return json({ error: "A valid current location is required." }, 400);
    }
    if (!Number.isInteger(radiusKm) || radiusKm < 1 || radiusKm > 50) {
      return json({ error: "Choose a search radius between 1 and 50 km." }, 400);
    }
    if (!(type in supportedTypes) && type !== "weighbridge") {
      return json({ error: "Unsupported service type." }, 400);
    }
    return json({ services: await googleSearch({ key: providerKey, latitude, longitude, radiusKm, type, query }) });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Nearby service search is temporarily unavailable.";
    return json({ error: message }, 502);
  }
});
