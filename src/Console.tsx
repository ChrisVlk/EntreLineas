import {useEffect,useRef,useState} from 'react';
import {Play,Square,Trash2,Terminal} from 'lucide-react';
import type {Language} from './types';

export function Console({source,language}:{source:string;language:Language}){
 const worker=useRef<Worker|null>(null),timer=useRef<ReturnType<typeof setTimeout>|null>(null),log=useRef<HTMLPreElement>(null),input=useRef<HTMLInputElement>(null);
 const [text,setText]=useState(''),[status,setStatus]=useState<'idle'|'running'|'waiting'|'done'|'stopped'|'error'>('idle'),[prompt,setPrompt]=useState(''),[value,setValue]=useState('');
 const [snapshot,setSnapshot]=useState<{source:string;language:Language}|null>(null);
 function cleanup(){worker.current?.terminate();worker.current=null;if(timer.current)clearTimeout(timer.current);timer.current=null;}
 useEffect(()=>()=>cleanup(),[]);
 useEffect(()=>{if(log.current)log.current.scrollTop=log.current.scrollHeight;},[text]);
 useEffect(()=>{if(status==='waiting')input.current?.focus();},[status]);
 function watchdog(){if(timer.current)clearTimeout(timer.current);timer.current=setTimeout(()=>{cleanup();setStatus('error');setText(t=>t+'\nEjecución detenida: se superó el límite de 5 segundos de cálculo.\n');},5000);}
 function run(){cleanup();setText('');setPrompt('');setValue('');setSnapshot({source,language});setStatus('running');try{const w=new Worker(new URL('./runtime.worker.js',import.meta.url),{type:'module'});worker.current=w;
  w.onmessage=e=>{if(worker.current!==w)return;const m=e.data;if(m.type==='output')setText(t=>(t+m.text).slice(-110000));else if(m.type==='input'){if(timer.current)clearTimeout(timer.current);setPrompt(m.name);setStatus('waiting');}else{cleanup();setStatus(m.type==='done'?'done':'error');if(m.type==='error')setText(t=>t+'\n'+m.text+'\n');}};
  w.onerror=()=>{cleanup();setStatus('error');setText(t=>t+'\nNo se pudo iniciar la consola. Recarga la página e intenta de nuevo.\n');};watchdog();w.postMessage({type:'start',source,language});
 }catch{cleanup();setStatus('error');setText('Este navegador no pudo iniciar la ejecución.');}}
 const busy=status==='running'||status==='waiting';
 return <section className="execution-console" aria-label="Consola de ejecución"><div className="console-toolbar"><h3><Terminal size={18}/> Consola</h3><span role="status">{{idle:'Lista para ejecutar',running:'Ejecutando…',waiting:'Esperando un dato',done:'Programa finalizado',stopped:'Ejecución detenida',error:'Error de ejecución'}[status]}</span><button className="primary" disabled={busy||!source.trim()} onClick={run}><Play size={15}/> Ejecutar</button><button className="secondary" disabled={!busy} onClick={()=>{cleanup();setStatus('stopped');setText(t=>t+'\nEjecución detenida.\n');}}><Square size={15}/> Detener</button><button className="icon" aria-label="Limpiar consola" disabled={busy} onClick={()=>{setText('');setStatus('idle');setSnapshot(null);}}><Trash2 size={17}/></button></div><details className="inline-help console-help"><summary>Alcance de la consola</summary><p>Ejecuta el código de origen con un intérprete educativo. Admite las instrucciones básicas de la guía, no todas las funciones de cada lenguaje.</p></details>{snapshot&&(snapshot.source!==source||snapshot.language!==language)&&<p className="console-stale">El código cambió. Esta salida corresponde a la ejecución anterior.</p>}<pre ref={log} className="console-output" tabIndex={0} aria-label="Salida del programa">{text||'Pulsa Ejecutar para comenzar.'}</pre>{status==='waiting'&&<form className="console-input" onSubmit={e=>{e.preventDefault();setText(t=>(t+'> '+value+'\n').slice(-110000));setStatus('running');watchdog();worker.current?.postMessage({type:'input',value});setValue('');}}><label>Valor para {prompt}<input ref={input} value={value} onChange={e=>setValue(e.target.value)} maxLength={4096} autoComplete="off" spellCheck={false}/></label><button className="primary" type="submit">Enviar dato</button></form>}</section>;
}
