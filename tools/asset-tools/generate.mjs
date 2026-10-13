
import { Resvg } from '@resvg/resvg-js';
import { readFile, writeFile, mkdir } from 'node:fs/promises';
const root=new URL('../../',import.meta.url);
const source=await readFile(new URL('assets/brand/lorry-link.svg',root),'utf8');
async function png(path,size){const target=new URL(path,root);await mkdir(new URL('./',target),{recursive:true});const render=new Resvg(source,{fitTo:{mode:'width',value:size}});await writeFile(target,render.render().asPng());}
for(const [density,size] of Object.entries({mdpi:48,hdpi:72,xhdpi:96,xxhdpi:144,xxxhdpi:192}))await png(`android/app/src/main/res/mipmap-${density}/ic_launcher.png`,size);
for(const [file,size] of Object.entries({'favicon.png':32,'icons/Icon-192.png':192,'icons/Icon-512.png':512,'icons/Icon-maskable-192.png':192,'icons/Icon-maskable-512.png':512}))await png(`web/${file}`,size);
const catalog=JSON.parse(await readFile(new URL('ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json',root),'utf8'));
for(const image of catalog.images){if(image.filename){const size=Number(image.size.split('x')[0])*Number(image.scale.replace('x',''));await png(`ios/Runner/Assets.xcassets/AppIcon.appiconset/${image.filename}`,size);}}
console.log('Generated Android, iOS and web icons from assets/brand/lorry-link.svg');
