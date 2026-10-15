import { inferCategory, osmSearch } from './providers.ts';
function assert(value:unknown,message:string){if(!value)throw new Error(message);}
Deno.test('search words select the correct service category',()=>{
  assert(inferCategory('nearby fuel pump')==='fuel','fuel mismatch');
  assert(inferCategory('weigh bridge')==='weighbridge','weighbridge mismatch');
  assert(inferCategory('dhaba')==='food','food mismatch');
  assert(inferCategory('hotel')==='hotel','hotel mismatch');
});
Deno.test('all services includes food and hotels, preserves contact and distance order',async()=>{
  const elements=[
    {type:'node',id:1,lat:10.01,lon:76,tags:{amenity:'fuel',name:'Fuel',phone:'+91 123',opening_hours:'24/7'}},
    {type:'way',id:2,center:{lat:10,lon:76},tags:{amenity:'restaurant',name:'Dhaba'}},
    {type:'node',id:3,lat:10.02,lon:76,tags:{tourism:'hotel',name:'Hotel'}},
    {type:'node',id:4,lat:11,lon:76,tags:{amenity:'fuel',name:'Outside radius'}},
    {type:'node',id:5,lat:10,lon:76,tags:{amenity:'parking',name:'Cars only'}},
  ];
  const fakeFetch=(async()=>Response.json({elements})) as typeof fetch;
  const results=await osmSearch({latitude:10,longitude:76,radiusKm:5,query:''},fakeFetch);
  assert(results.length===3,'bad category or radius filtering');
  assert(results[0].service_type==='food','not distance sorted');
  assert(results.find(p=>p.service_type==='fuel')?.phone==='+91 123','phone lost');
  assert(results.some(p=>p.service_type==='hotel'),'hotel missing');
});
