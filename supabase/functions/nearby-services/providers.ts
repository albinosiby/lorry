export const categories = ['fuel','truck_stop','weighbridge','workshop','tyre','hospital','food','hotel','service_center'] as const;
export type Category = typeof categories[number];
export type Place = { id: string; service_type: Category; name: string; address: string; latitude: number; longitude: number; distance_km: number; phone: string; provider: string; rating?: number; is_open_now?: boolean; opening_hours?: string; truck_friendly?: boolean; attributions?: { displayName?: string; uri?: string }[] };
export type Search = { latitude: number; longitude: number; radiusKm: number; type?: Category; query: string };

export function distanceKm(a: number,b: number,c: number,d: number) {
  const r=Math.PI/180, x=Math.sin((c-a)*r/2)**2+Math.cos(a*r)*Math.cos(c*r)*Math.sin((d-b)*r/2)**2;
  return 6371*2*Math.atan2(Math.sqrt(x),Math.sqrt(1-x));
}

const googleTypes: Partial<Record<Category,string>>={fuel:'gas_station',truck_stop:'truck_stop',workshop:'car_repair',tyre:'tire_shop',hospital:'hospital',food:'restaurant',hotel:'lodging',service_center:'car_repair'};
const selectors: Record<Category,string[]>={
  fuel:['[amenity=fuel]'],
  truck_stop:['[highway=rest_area]','[highway=services]','[amenity=parking][hgv~"^(yes|designated)$"]'],
  weighbridge:['[amenity=weighbridge]'],workshop:['[shop=car_repair]'],
  tyre:['[shop=tyres]'],hospital:['[amenity=hospital]','[amenity=clinic]'],
  food:['[amenity=restaurant]','[amenity=fast_food]','[amenity=cafe]'],
  hotel:['[tourism=hotel]','[tourism=motel]','[tourism=guest_house]'],
  service_center:['[shop=car_repair][brand]','[shop=car_repair][operator]'],
};
export function inferCategory(query: string): Category | undefined {
  const q=query.toLowerCase();
  if (/weigh|weighing|dharam|വെയ്ബ്രിഡ്ജ്/.test(q)) return 'weighbridge';
  if (/tyre|tire|puncture/.test(q)) return 'tyre';
  if (/fuel|pump|petrol|diesel/.test(q)) return 'fuel';
  if (/parking|lay.?by|truck stop|rest area/.test(q)) return 'truck_stop';
  if (/hospital|clinic|medical/.test(q)) return 'hospital';
  if (/restaurant|food|dhaba|cafe|meal/.test(q)) return 'food';
  if (/hotel|motel|lodge|stay/.test(q)) return 'hotel';
  if (/authorized|authorised|service cent/.test(q)) return 'service_center';
  if (/workshop|mechanic|repair|garage/.test(q)) return 'workshop';
}
function matchesName(place: Place, query: string) {
  if (!query || inferCategory(query)) return true;
  return `${place.name} ${place.address}`.toLowerCase().includes(query.toLowerCase());
}

export async function osmSearch(search: Search, fetcher: typeof fetch=fetch): Promise<Place[]> {
  const type=search.type ?? inferCategory(search.query);
  const selected=type ? [type] : [...categories];
  const filters=[...new Set(selected.flatMap(t=>selectors[t]))];
  const radius=search.radiusKm*1000;
  const query=`[out:json][timeout:18];(${filters.map(s=>`nwr(around:${radius},${search.latitude},${search.longitude})${s};`).join('')});out center tags 300;`;
  const endpoints=[Deno.env.get('OVERPASS_API_URL') || 'https://overpass-api.de/api/interpreter','https://overpass.private.coffee/api/interpreter'];
  let payload: { elements?: Record<string,unknown>[] } | undefined;
  for (const endpoint of endpoints) {
    try {
      const response=await fetcher(endpoint,{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded','User-Agent':'LorryLink/1.0 (+https://puupnlblrehwrhpaolxs.supabase.co)'},body:new URLSearchParams({data:query}),signal:AbortSignal.timeout(22000)});
      if (!response.ok) continue;
      payload=await response.json();
      if (payload?.elements) break;
    } catch { /* Try the secondary endpoint once. */ }
  }
  if (!payload?.elements) throw new Error('Nearby services could not be loaded. Please try again.');
  return payload.elements.flatMap(element=>{
    const tags=(element.tags ?? {}) as Record<string,string>;
    const center=(element.center ?? element) as {lat?:number;lon?:number};
    if (center.lat==null || center.lon==null) return [];
    let found: Category | undefined;
    if(tags.amenity==='fuel')found='fuel';
    else if(tags.amenity==='weighbridge')found='weighbridge';
    else if(tags.shop==='tyres')found='tyre';
    else if(tags.shop==='car_repair')found=type==='service_center'?'service_center':'workshop';
    else if(['hospital','clinic'].includes(tags.amenity))found='hospital';
    else if(['restaurant','fast_food','cafe'].includes(tags.amenity))found='food';
    else if(['hotel','motel','guest_house'].includes(tags.tourism))found='hotel';
    else if(['rest_area','services'].includes(tags.highway)||(tags.amenity==='parking'&&['yes','designated'].includes(tags.hgv)))found='truck_stop';
    if(!found)return [];
    const place:Place={id:`osm:${element.type}:${element.id}`,service_type:found,name:tags.name||tags['name:en']||tags.brand||tags.operator||found.replaceAll('_',' '),address:['addr:housenumber','addr:street','addr:suburb','addr:city'].map(k=>tags[k]).filter(Boolean).join(', '),latitude:center.lat,longitude:center.lon,distance_km:distanceKm(search.latitude,search.longitude,center.lat,center.lon),phone:tags['contact:phone']||tags.phone||'',provider:'osm',opening_hours:tags.opening_hours,truck_friendly:['yes','designated'].includes(tags.hgv)};
    if(tags.opening_hours==='24/7')place.is_open_now=true;
    return place.distance_km<=search.radiusKm&&matchesName(place,search.query)?[place]:[];
  }).sort((a,b)=>a.distance_km-b.distance_km).slice(0,60);
}

export async function googleSearch(search:Search,key:string): Promise<Place[]> {
  const type=search.type ?? inferCategory(search.query);
  const textSearch=!!search.query||type==='weighbridge'||type==='service_center';
  const circle={center:{latitude:search.latitude,longitude:search.longitude},radius:search.radiusKm*1000};
  const body=textSearch?{textQuery:[search.query,type==='weighbridge'?'weighbridge':type==='service_center'?'vehicle service center':type?googleTypes[type]:''].filter(Boolean).join(' '),locationBias:{circle},pageSize:20}:
    {includedTypes:type?[googleTypes[type]]:[...new Set(Object.values(googleTypes))],locationRestriction:{circle},maxResultCount:20,rankPreference:'DISTANCE'};
  const response=await fetch(`https://places.googleapis.com/v1/places:${textSearch?'searchText':'searchNearby'}`,{method:'POST',headers:{'Content-Type':'application/json','X-Goog-Api-Key':key,'X-Goog-FieldMask':'places.id,places.displayName,places.formattedAddress,places.location,places.types,places.rating,places.currentOpeningHours.openNow,places.internationalPhoneNumber,places.attributions'},body:JSON.stringify(body),signal:AbortSignal.timeout(12000)});
  if(!response.ok)throw new Error('Google Places unavailable');
  const result=await response.json();
  return (result.places??[]).flatMap((p:Record<string,unknown>)=>{
    const point=p.location as {latitude:number;longitude:number};
    if(!point)return [];
    const types=p.types as string[]??[];
    const category=type??categories.find(c=>googleTypes[c]&&types.includes(googleTypes[c]!));
    if(!category)return [];
    const place:Place={id:String(p.id),service_type:category,name:(p.displayName as {text:string})?.text??'Nearby service',address:String(p.formattedAddress??''),latitude:point.latitude,longitude:point.longitude,distance_km:distanceKm(search.latitude,search.longitude,point.latitude,point.longitude),provider:'google',phone:String(p.internationalPhoneNumber??''),rating:p.rating as number|undefined,is_open_now:(p.currentOpeningHours as {openNow?:boolean})?.openNow,attributions:p.attributions as Place['attributions']};
    return place.distance_km<=search.radiusKm?[place]:[];
  }).sort((a:Place,b:Place)=>a.distance_km-b.distance_km);
}
