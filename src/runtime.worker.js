import {execute} from './runtime.js';
let execution;
function advance(value){let buffer='';try{let next=execution.next(value);while(!next.done&&next.value.type==='output'){buffer+=next.value.text;if(buffer.length>=4096){postMessage({type:'output',text:buffer});buffer='';}next=execution.next();}if(buffer)postMessage({type:'output',text:buffer});postMessage(next.done?{type:'done'}:next.value);}catch(error){if(buffer)postMessage({type:'output',text:buffer});postMessage({type:'error',text:error.message||'No se pudo ejecutar el programa.'});}}
onmessage=event=>{if(event.data.type==='start'){execution=execute(event.data.source,event.data.language);advance();}else if(event.data.type==='input'&&execution)advance(event.data.value);};
