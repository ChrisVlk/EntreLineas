import {message} from './lib';
import {useEffect,useRef,useState,type ReactNode} from 'react';
import {X,Code2,LoaderCircle} from 'lucide-react';
export function Brand(){return <div className="brand"><span><Code2 size={23}/></span><b>entre líneas</b><small>AULA</small></div>}
export function Loading(){return <div className="loading" role="status"><LoaderCircle className="spin"/> Cargando tu espacio…</div>}
export function Notice({children,error=false}:{children:ReactNode;error?:boolean}){return <div className={'notice '+(error?'error':'')} role={error?'alert':'status'}>{children}</div>}
export function Modal({title,children,onClose,wide=false}:{title:string;children:ReactNode;onClose:()=>void;wide?:boolean}){const ref=useRef<HTMLDialogElement>(null);useEffect(()=>{const el=ref.current;el?.showModal();return()=>el?.close()},[]);return <dialog ref={ref} className={wide?'wide':''} onCancel={e=>{e.preventDefault();onClose()}}><div className="modal-heading"><h2>{title}</h2><button className="icon" onClick={onClose} aria-label="Cerrar"><X/></button></div>{children}</dialog>}
export function Submit({busy,children}:{busy:boolean;children:ReactNode}){return <button className="primary" type="submit" disabled={busy}>{busy?<><LoaderCircle className="spin" size={17}/> Guardando…</>:children}</button>}
export function Empty({title,children}:{title:string;children:ReactNode}){return <div className="empty"><Code2 size={32}/><h3>{title}</h3><div>{children}</div></div>}
export function useAction(){const [busy,setBusy]=useState(false),[error,setError]=useState('');return {busy,error,setError,run:async(fn:()=>Promise<void>)=>{if(busy)return;setBusy(true);setError('');try{await fn()}catch(e){setError(message(e))}finally{setBusy(false)}}}}
