import { createClient } from 'npm:@supabase/supabase-js@2.99.2';
import { categories, googleSearch, googleSearchExpanded, osmSearch, type Category, type Place } from './providers.ts';
const cors={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type','Access-Control-Allow-Methods':'POST, OPTIONS'};
const json=(body:unknown,status=200)=>Response.json(body,{status,headers:cors});
// Only OSM results are cached here. Google content is fetched live.
const cache=new Map<string,{until:number;places:Place[]}>();
Deno.serve(async request=>{
  if(request.method==='OPTIONS')return new Response('ok',{headers:cors});
  if(request.method!=='POST')return json({error:'Method not allowed'},405);
  const token=request.headers.get('Authorization')?.replace(/^Bearer\s+/i,'');
  if(!token)return json({error:'Please sign in to find nearby services.'},401);
  const client=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_ANON_KEY')!,{auth:{persistSession:false}});
  const {data:{user},error}=await client.auth.getUser(token);
  if(error||!user)return json({error:'Please sign in again.'},401);
  try{
    const input=await request.json();
    const latitude=input.latitude,longitude=input.longitude,radiusKm=input.radius_km??10;
    if(typeof latitude!=='number'||!Number.isFinite(latitude)||Math.abs(latitude)>90||typeof longitude!=='number'||!Number.isFinite(longitude)||Math.abs(longitude)>180)return json({error:'A valid current location is required.'},400);
    if(!Number.isInteger(radiusKm)||radiusKm<1||radiusKm>50)return json({error:'Choose a radius between 1 and 50 km.'},400);
    const type=input.type as Category|undefined;
    const expand=input.expand===true;
    if(type&&!categories.includes(type))return json({error:'Unknown service category.'},400);
    const search={latitude,longitude,radiusKm,type,query:typeof input.query==='string'?input.query.trim().slice(0,100):''};
    const key=Deno.env.get('GOOGLE_PLACES_API_KEY');
    if(key){
      try{
        const services=expand&&!type&&!search.query
          ?await googleSearchExpanded(search,key)
          :await googleSearch(search,key);
        if(services.length)return json({services,provider:'google'});
      }catch(err) {console.warn('Google Places failed; using OpenStreetMap:', err);}
    }
    const cacheKey=JSON.stringify(search);
    const cached=cache.get(cacheKey);
    if(cached&&cached.until>Date.now())return json({services:cached.places,provider:'osm'});
    const services=await osmSearch(search,fetch,expand?1000:300);
    if(cache.size>100)cache.clear();
    cache.set(cacheKey,{until:Date.now()+180000,places:services});
    return json({services,provider:'osm'});
  }catch{return json({error:'Nearby services could not be loaded. Please try again or expand your search.'},502);}
});
