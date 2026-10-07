import {createClient} from '@supabase/supabase-js';
const url=import.meta.env.VITE_SUPABASE_URL,key=import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY;
export const configured=Boolean(url&&key);
// A capability is generated only when entering a room; the public editor needs none.
const deviceKey='entre-lineas-device-v1';
function readToken(){try{return localStorage.getItem(deviceKey)||''}catch{return ''}}
export const db=createClient(url||'https://unconfigured.supabase.co',key||'unconfigured',{
 auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false},
 global:{fetch:async(input,init)=>{const headers=new Headers(init?.headers);const token=readToken();if(token)headers.set('x-guest-token',token);return fetch(input,{...init,headers})}}
});
export async function ensureGuest(name:string){
 if(!configured)throw Error('Las salas no están configuradas todavía. Puedes usar el traductor.');
 if(!readToken()){const token=Array.from(crypto.getRandomValues(new Uint8Array(32)),x=>x.toString(16).padStart(2,'0')).join('');try{localStorage.setItem(deviceKey,token)}catch{throw Error('Permite el almacenamiento de este sitio para conservar tu acceso a las salas.')}}
 return checked(db.rpc('start_guest',{display_name:name}));
}
export async function currentGuest(){if(!readToken())return null;return checked(db.from('profiles').select('*').maybeSingle())}
export async function joinRoom(code:string,name:string){const result=await checked(db.rpc('join_room',{code,participant_name:name}));if(result.error)throw Error(result.error);return result}
export const starter='Algoritmo MiSolucion\n    // Escribe aquí tu solución\n    Escribir "Hola, mundo"\nFinAlgoritmo';
export function message(error:unknown){const value=error instanceof Error?error.message:typeof error==='object'&&error&&'message' in error?String(error.message):String(error);if(/rate limit/i.test(value))return 'Se alcanzó el límite de intentos. Espera unos minutos antes de volver a probar.';if(/row-level|permission denied/i.test(value))return 'No tienes permiso para esta acción o el acceso a la sala ya no es válido.';if(/Failed to fetch/.test(value))return 'No se pudo conectar. Revisa tu conexión y vuelve a intentar.';return value}
export const date=(s:string|null)=>s?new Intl.DateTimeFormat('es',{dateStyle:'medium',timeStyle:'short'}).format(new Date(s)):'Sin fecha límite';
export async function checked<T>(request:PromiseLike<{data:T;error:unknown}>):Promise<T>{const {data,error}=await request;if(error)throw error;return data}
